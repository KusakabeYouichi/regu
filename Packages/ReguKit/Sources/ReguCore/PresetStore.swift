import Foundation
import Observation

// ビルトイン 3 つ＋ユーザープリセットの一覧と、選択中のプリセット、ビルトインの別名を UserDefaults に保存する
@Observable
@MainActor
public final class PresetStore {
    enum Key {
        static let userPresets = "regu.userPresets"
        static let selectedPresetID = "regu.selectedPresetID"
        static let builtInAliases = "regu.builtInAliases"
    }

    public private(set) var userPresets: [Preset]
    public private(set) var selectedPresetID: UUID
    // ビルトインの別名。Preset の外に持ち、変換設定と指紋には入れない
    private var builtInAliases: [UUID: String]

    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
        let loaded = Self.loadUserPresets(from: defaults)
        userPresets = loaded
        let savedID = defaults.string(forKey: Key.selectedPresetID).flatMap(UUID.init(uuidString:))
        let knownIDs = Set((Preset.builtIns + loaded).map(\.id))
        if let savedID, knownIDs.contains(savedID) {
            selectedPresetID = savedID
        } else {
            selectedPresetID = Preset.regularisation.id
        }
        builtInAliases = Self.loadBuiltInAliases(from: defaults)
    }

    public var presets: [Preset] {
        Preset.builtIns + userPresets
    }

    public var selectedPreset: Preset {
        preset(id: selectedPresetID) ?? .regularisation
    }

    public func preset(id: UUID) -> Preset? {
        presets.first { $0.id == id }
    }

    public func select(_ id: UUID) {
        guard preset(id: id) != nil else {
            return
        }
        selectedPresetID = id
        defaults.set(id.uuidString, forKey: Key.selectedPresetID)
    }

    public func alias(for id: UUID) -> String? {
        builtInAliases[id]
    }

    // ビルトイン以外には付けない。前後の空白を除き、空か本当の名前と同じなら別名を消す
    public func setAlias(_ alias: String, for id: UUID) {
        guard let builtIn = Preset.builtIns.first(where: { $0.id == id }) else {
            return
        }
        let normalized = Self.normalizedAlias(alias, for: builtIn)
        // 変わっていなければ保存も変更通知もしない(確定・フォーカス喪失・画面を閉じるで何度も呼ばれる)
        guard normalized != builtInAliases[id] else {
            return
        }
        builtInAliases[id] = normalized
        saveBuiltInAliases()
    }

    // 前後の空白を除く。空か本当の名前と同じなら別名なし(保存時と読み込み時で同じ規則)
    private static func normalizedAlias(_ alias: String, for builtIn: Preset) -> String? {
        let trimmed = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == builtIn.name ? nil : trimmed
    }

    // 選択リスト(チップとメニュー)用。別名があれば別名
    public func displayName(for preset: Preset) -> String {
        guard preset.isBuiltIn, let alias = alias(for: preset.id) else {
            return preset.name
        }
        return alias
    }

    // 設定の一覧用。別名があれば本当の名前の後ろに「 - 別名」
    public func listName(for preset: Preset) -> String {
        guard preset.isBuiltIn, let alias = alias(for: preset.id) else {
            return preset.name
        }
        return "\(preset.name) - \(alias)"
    }

    @discardableResult
    public func add(name: String, settings: ConversionSettings = ConversionSettings()) -> Preset {
        let preset = Preset(name: name, settings: settings)
        userPresets.append(preset)
        saveUserPresets()
        return preset
    }

    // ビルトインのプリセットからも複製できる。名前は「元 copie」、埋まっていれば「元 copie 2」「元 copie 3」…
    @discardableResult
    public func duplicate(_ id: UUID) -> Preset? {
        guard let source = preset(id: id) else {
            return nil
        }
        // 「xxx copie」「xxx copie 2」を複製しても「xxx copie copie」にせず、xxx の次の番号にする
        let stripped = source.name.replacing(/\ copie( [0-9]+)?$/, with: "")
        let base = stripped.isEmpty ? source.name : stripped
        return add(name: unusedName(startingWith: "\(base) copie"), settings: source.settings)
    }

    // name が空いていればそのまま、埋まっていれば「name 2」「name 3」…の最初の空き。
    // hasOtherPreset と同じく、ビルトインの別名も埋まっているとみなす(付けた直後に重なりを知らせないため)
    public func unusedName(startingWith name: String) -> String {
        let usedNames = Set(presets.flatMap { [$0.name, displayName(for: $0)] })
        var candidate = name
        var number = 2
        while usedNames.contains(candidate) {
            candidate = "\(name) \(number)"
            number += 1
        }
        return candidate
    }

    // 名前の重なりを知らせるため。ビルトインは別名を付けていれば別名でも比べる(チップのメニューに出る名前)
    public func hasOtherPreset(named name: String, excluding id: UUID) -> Bool {
        presets.contains { preset in
            preset.id != id && (preset.name == name || displayName(for: preset) == name)
        }
    }

    // ビルトインのプリセットは変更できない(以下 3 つとも userPresets だけを対象にする)
    public func rename(_ id: UUID, to name: String) {
        guard let index = userPresets.firstIndex(where: { $0.id == id }) else {
            return
        }
        userPresets[index].name = name
        saveUserPresets()
    }

    public func updateSettings(_ id: UUID, to settings: ConversionSettings) {
        guard let index = userPresets.firstIndex(where: { $0.id == id }) else {
            return
        }
        userPresets[index].settings = settings
        saveUserPresets()
    }

    // 追加した直後のユーザープリセットが、名前も設定(全 preserve)も追加したときのままなら消す。
    // 途中で変えても戻してあれば消す(判定は呼んだときの状態だけで行う)。消したら true
    @discardableResult
    public func discardIfUntouched(_ id: UUID, defaultName: String) -> Bool {
        guard let preset = userPresets.first(where: { $0.id == id }),
                preset.name == defaultName,
                preset.settings == ConversionSettings() else {
            return false
        }
        delete(id)
        return true
    }

    // 選択中のものを消したら régularisation に戻す
    public func delete(_ id: UUID) {
        guard let index = userPresets.firstIndex(where: { $0.id == id }) else {
            return
        }
        userPresets.remove(at: index)
        saveUserPresets()
        if selectedPresetID == id {
            select(Preset.regularisation.id)
        }
    }

    private func saveUserPresets() {
        guard let data = try? JSONEncoder().encode(userPresets) else {
            return
        }
        defaults.set(data, forKey: Key.userPresets)
    }

    private func saveBuiltInAliases() {
        let stored = Dictionary(uniqueKeysWithValues: builtInAliases.map { ($0.key.uuidString, $0.value) })
        defaults.set(stored, forKey: Key.builtInAliases)
    }

    // 型が違う・未知の ID の別名は捨て、残りは setAlias と同じ規則で整える
    private static func loadBuiltInAliases(from defaults: UserDefaults) -> [UUID: String] {
        guard let stored = defaults.dictionary(forKey: Key.builtInAliases) else {
            return [:]
        }
        var aliases: [UUID: String] = [:]
        for (key, value) in stored {
            guard let id = UUID(uuidString: key),
                    let builtIn = Preset.builtIns.first(where: { $0.id == id }),
                    let alias = value as? String,
                    let normalized = normalizedAlias(alias, for: builtIn) else {
                continue
            }
            aliases[id] = normalized
        }
        return aliases
    }

    // 要素ごとに読み、読めなかった要素だけを捨てる
    private static func loadUserPresets(from defaults: UserDefaults) -> [Preset] {
        guard let data = defaults.data(forKey: Key.userPresets),
                let decoded = try? JSONDecoder().decode([LossyPreset].self, from: data) else {
            return []
        }
        return decoded.compactMap(\.preset)
    }

    private struct LossyPreset: Decodable {
        let preset: Preset?

        init(from decoder: any Decoder) throws {
            preset = try? Preset(from: decoder)
        }
    }
}
