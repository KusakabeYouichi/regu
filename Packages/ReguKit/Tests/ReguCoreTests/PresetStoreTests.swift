import Foundation
import Testing
@testable import ReguCore

// c01-tests.md の S
@Suite("PresetStore")
@MainActor
struct PresetStoreTests {
    private let testDefaults = TestDefaults()

    private var defaults: UserDefaults {
        testDefaults.defaults
    }

    @Test("S1 新規の保存先では既定 3 つだけが並び、régularisation が選ばれている")
    func freshDefaults() {
        let store = PresetStore(defaults: defaults)
        #expect(store.presets.map(\.name) == ["régularisation", "Adresse héritée", "ruby héritée"])
        #expect(store.selectedPreset.name == "régularisation")
    }

    @Test("S2 追加したユーザープリセットは名前と全設定値ごと読み直せる")
    func userPresetSurvivesReload() {
        let settings = ConversionSettings(
            alphabet: .toFullwidth,
            accent: .toNFD,
            space: .twoSpacesToIdeographic,
            katakana: .toHalfwidth,
            hiragana: .swap,
            symbol: .fromCP932Lower,
            guillemets: .doubleToSingle,
            unit: .siToLigature,
            htmlEntity: .encode,
            urlEntity: .decode
        )
        let added = PresetStore(defaults: defaults).add(name: "銀行振込", settings: settings)

        let reloaded = PresetStore(defaults: defaults)
        #expect(reloaded.userPresets.count == 1)
        #expect(reloaded.userPresets.first?.id == added.id)
        #expect(reloaded.userPresets.first?.name == "銀行振込")
        #expect(reloaded.userPresets.first?.settings == settings)
        #expect(reloaded.userPresets.first?.isBuiltIn == false)
    }

    @Test("S3 選んだプリセットは読み直しても選ばれている")
    func selectionSurvivesReload() {
        PresetStore(defaults: defaults).select(Preset.adresseHeritee.id)

        #expect(PresetStore(defaults: defaults).selectedPreset.name == "Adresse héritée")
    }

    @Test("S4 選択中のユーザープリセットを消すと régularisation に戻り、読み直しても同じ")
    func deletingSelectedPresetFallsBackToRegularisation() {
        let store = PresetStore(defaults: defaults)
        let added = store.add(name: "一時", settings: ConversionSettings(hiragana: .swap))
        store.select(added.id)

        store.delete(added.id)

        #expect(store.selectedPreset.name == "régularisation")
        #expect(PresetStore(defaults: defaults).selectedPreset.name == "régularisation")
    }

    @Test("S5 既定プリセットは削除・名前変更・設定変更できない")
    func builtInPresetsAreReadOnly() {
        let store = PresetStore(defaults: defaults)
        let id = Preset.regularisation.id
        store.select(Preset.adresseHeritee.id)
        store.delete(Preset.adresseHeritee.id)
        #expect(store.selectedPreset.name == "Adresse héritée")

        store.delete(id)
        store.rename(id, to: "変更後")
        store.updateSettings(id, to: ConversionSettings())

        #expect(store.presets.map(\.name) == ["régularisation", "Adresse héritée", "ruby héritée"])
        #expect(store.preset(id: id)?.name == "régularisation")
        #expect(store.preset(id: id)?.settings.alphabet == .toASCII)
        #expect(store.preset(id: id)?.settings.guillemets == .singleToDouble)
        let reloaded = PresetStore(defaults: defaults)
        #expect(reloaded.presets.map(\.name) == ["régularisation", "Adresse héritée", "ruby héritée"])
        #expect(reloaded.preset(id: id)?.settings.alphabet == .toASCII)
        #expect(reloaded.preset(id: id)?.settings.guillemets == .singleToDouble)
    }

    @Test("S6 保存データ全体が壊れていても既定 3 つで起動する")
    func corruptedDataFallsBackToBuiltIns() {
        defaults.set(Data("not json".utf8), forKey: PresetStore.Key.userPresets)

        let store = PresetStore(defaults: defaults)

        #expect(store.presets.map(\.name) == ["régularisation", "Adresse héritée", "ruby héritée"])
        #expect(store.selectedPreset.name == "régularisation")
    }

    @Test("S7 壊れた要素だけを捨て、未知の設定値は preserve として読む")
    func corruptedElementIsDroppedAndUnknownValueIsPreserve() {
        let json = """
            [
                {"id": "11111111-1111-4111-8111-111111111111", "settings": {}},
                {
                    "id": "22222222-2222-4222-8222-222222222222",
                    "name": "未来の設定",
                    "settings": {"alphabet": "toKlingon", "space": "spaceToIdeographic"}
                }
            ]
            """
        defaults.set(Data(json.utf8), forKey: PresetStore.Key.userPresets)

        let store = PresetStore(defaults: defaults)

        #expect(store.userPresets.map(\.name) == ["未来の設定"])
        #expect(store.userPresets.first?.settings == ConversionSettings(space: .spaceToIdeographic))
    }
}
