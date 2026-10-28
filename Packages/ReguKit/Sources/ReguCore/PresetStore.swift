import Foundation
import Observation

// 既定 3 つ＋ユーザープリセットの一覧と、選択中のプリセットを UserDefaults に保存する
@Observable
@MainActor
public final class PresetStore {
    enum Key {
        static let userPresets = "regu.userPresets"
        static let selectedPresetID = "regu.selectedPresetID"
    }

    public private(set) var userPresets: [Preset]
    public private(set) var selectedPresetID: UUID

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

    @discardableResult
    public func add(name: String, settings: ConversionSettings = ConversionSettings()) -> Preset {
        let preset = Preset(name: name, settings: settings)
        userPresets.append(preset)
        saveUserPresets()
        return preset
    }

    // 既定プリセットからも複製できる
    @discardableResult
    public func duplicate(_ id: UUID, name: String) -> Preset? {
        guard let source = preset(id: id) else {
            return nil
        }
        return add(name: name, settings: source.settings)
    }

    // 既定プリセットは変更できない（以下 3 つとも userPresets だけを対象にする）
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
