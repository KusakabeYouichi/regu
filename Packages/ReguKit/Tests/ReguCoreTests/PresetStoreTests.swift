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

    // c03-tests.md の A(ビルトインの別名)

    @Test("A1 新規の保存先ではビルトインに別名がなく、表示名も一覧名も本当の名前")
    func freshStoreHasNoAliases() {
        let store = PresetStore(defaults: defaults)

        #expect(store.alias(for: Preset.regularisation.id) == nil)
        #expect(store.alias(for: Preset.adresseHeritee.id) == nil)
        #expect(store.alias(for: Preset.rubyHeritee.id) == nil)
        #expect(store.displayName(for: .regularisation) == "régularisation")
        #expect(store.listName(for: .regularisation) == "régularisation")
    }

    @Test("A2 別名を付けると表示名は別名、一覧名は「本当の名前 - 別名」")
    func aliasIsUsedForDisplayAndList() {
        let store = PresetStore(defaults: defaults)

        store.setAlias("正規化", for: Preset.regularisation.id)

        #expect(store.alias(for: Preset.regularisation.id) == "正規化")
        #expect(store.displayName(for: .regularisation) == "正規化")
        #expect(store.listName(for: .regularisation) == "régularisation - 正規化")
    }

    @Test("A3 付けた別名は読み直しても残る")
    func aliasSurvivesReload() {
        PresetStore(defaults: defaults).setAlias("正規化", for: Preset.regularisation.id)

        let reloaded = PresetStore(defaults: defaults)

        #expect(reloaded.alias(for: Preset.regularisation.id) == "正規化")
        #expect(reloaded.displayName(for: .regularisation) == "正規化")
    }

    @Test("A4 別名の前後の空白は除いて保存する")
    func aliasIsTrimmed() {
        let store = PresetStore(defaults: defaults)

        store.setAlias("  正規化  ", for: Preset.regularisation.id)

        #expect(store.alias(for: Preset.regularisation.id) == "正規化")
        #expect(PresetStore(defaults: defaults).alias(for: Preset.regularisation.id) == "正規化")
    }

    @Test("A5 空の別名を付けると別名が消える", arguments: ["", "   "])
    func emptyAliasRemovesAlias(empty: String) {
        let store = PresetStore(defaults: defaults)
        store.setAlias("正規化", for: Preset.regularisation.id)

        store.setAlias(empty, for: Preset.regularisation.id)

        #expect(store.alias(for: Preset.regularisation.id) == nil)
        #expect(store.displayName(for: .regularisation) == "régularisation")
        let reloaded = PresetStore(defaults: defaults)
        #expect(reloaded.alias(for: Preset.regularisation.id) == nil)
        #expect(reloaded.listName(for: .regularisation) == "régularisation")
    }

    @Test("A6 ユーザープリセットには別名を付けられず、名前も変わらない")
    func userPresetIgnoresAlias() {
        let store = PresetStore(defaults: defaults)
        let user = store.add(name: "テスト")

        store.setAlias("別名", for: user.id)

        #expect(store.alias(for: user.id) == nil)
        #expect(store.preset(id: user.id)?.name == "テスト")
        #expect(PresetStore(defaults: defaults).alias(for: user.id) == nil)
    }

    @Test("A7 3 つのビルトインの別名はそれぞれ独立に保存・表示される")
    func aliasesAreIndependentPerBuiltIn() {
        let store = PresetStore(defaults: defaults)

        store.setAlias("正規化", for: Preset.regularisation.id)
        store.setAlias("住所", for: Preset.adresseHeritee.id)
        store.setAlias("ルビ", for: Preset.rubyHeritee.id)
        store.setAlias("", for: Preset.adresseHeritee.id)

        let reloaded = PresetStore(defaults: defaults)
        #expect(reloaded.displayName(for: .regularisation) == "正規化")
        #expect(reloaded.displayName(for: .adresseHeritee) == "Adresse héritée")
        #expect(reloaded.displayName(for: .rubyHeritee) == "ルビ")
        #expect(reloaded.listName(for: .rubyHeritee) == "ruby héritée - ルビ")
    }

    @Test("A8 別名の保存データが辞書でなくても、別名なしで起動する")
    func corruptedAliasDataFallsBackToNoAliases() {
        defaults.set("not a dictionary", forKey: PresetStore.Key.builtInAliases)

        let store = PresetStore(defaults: defaults)

        #expect(store.alias(for: Preset.regularisation.id) == nil)
        #expect(store.displayName(for: .regularisation) == "régularisation")
        #expect(store.presets.map(\.name) == ["régularisation", "Adresse héritée", "ruby héritée"])
    }

    @Test("A8 別名の値が文字列でない要素だけを捨てる")
    func nonStringAliasValueIsDropped() {
        defaults.set(
            [
                "6F1C2A10-0000-4000-8000-000000000001": 42,
                "6F1C2A10-0000-4000-8000-000000000003": "ルビ",
            ],
            forKey: PresetStore.Key.builtInAliases
        )

        let store = PresetStore(defaults: defaults)

        #expect(store.alias(for: Preset.regularisation.id) == nil)
        #expect(store.alias(for: Preset.rubyHeritee.id) == "ルビ")
    }

    @Test("A9 未知の ID とユーザープリセットの ID の別名は読み込み時に捨てる")
    func unknownIDAliasIsDropped() {
        let user = PresetStore(defaults: defaults).add(name: "テスト")
        let unknownID = UUID(uuidString: "99999999-9999-4999-8999-999999999999")!
        defaults.set(
            [
                "99999999-9999-4999-8999-999999999999": "幽霊",
                user.id.uuidString: "別名",
                "6F1C2A10-0000-4000-8000-000000000002": "住所",
            ],
            forKey: PresetStore.Key.builtInAliases
        )

        let store = PresetStore(defaults: defaults)

        #expect(store.alias(for: unknownID) == nil)
        #expect(store.alias(for: user.id) == nil)
        #expect(store.displayName(for: store.preset(id: user.id)!) == "テスト")
        #expect(store.alias(for: Preset.adresseHeritee.id) == "住所")
    }

    @Test("A14 読み込み時も保存時と同じ規則で整える(前後の空白・本当の名前と同じ・空白だけ)")
    func loadedAliasesAreNormalized() {
        defaults.set(
            [
                "6F1C2A10-0000-4000-8000-000000000001": "  正規化  ",
                "6F1C2A10-0000-4000-8000-000000000002": "Adresse héritée",
                "6F1C2A10-0000-4000-8000-000000000003": "   ",
            ],
            forKey: PresetStore.Key.builtInAliases
        )

        let store = PresetStore(defaults: defaults)

        #expect(store.alias(for: Preset.regularisation.id) == "正規化")
        #expect(store.alias(for: Preset.adresseHeritee.id) == nil)
        #expect(store.listName(for: Preset.adresseHeritee) == "Adresse héritée")
        #expect(store.alias(for: Preset.rubyHeritee.id) == nil)
    }

    @Test("A10 ユーザープリセットの表示名と一覧名は名前そのもの")
    func userPresetNamesAreItsName() {
        let store = PresetStore(defaults: defaults)
        let user = store.add(name: "テスト")

        #expect(store.displayName(for: user) == "テスト")
        #expect(store.listName(for: user) == "テスト")
    }

    @Test("A11 別名が他のプリセット名や他の別名と重なっても、表示名と選択は ID ごとに独立")
    func duplicateAliasesStayIndependent() {
        let store = PresetStore(defaults: defaults)
        store.setAlias("ruby héritée", for: Preset.regularisation.id)
        let user = store.add(name: "テスト")
        store.setAlias("テスト", for: Preset.rubyHeritee.id)

        #expect(store.displayName(for: .regularisation) == "ruby héritée")
        #expect(store.displayName(for: .rubyHeritee) == "テスト")
        #expect(store.displayName(for: user) == "テスト")
        store.select(Preset.rubyHeritee.id)
        #expect(store.selectedPreset.name == "ruby héritée")
        #expect(store.selectedPreset.settings == ConversionSettings(katakana: .toHalfwidth, hiragana: .hiraganaToKatakana))
        store.select(user.id)
        #expect(store.selectedPreset.name == "テスト")
        store.select(Preset.regularisation.id)
        #expect(store.selectedPreset.name == "régularisation")
    }

    @Test("A12 別名を付けても変換設定は変わらず、自分の出力から戻っても再変換しない")
    func aliasDoesNotAffectSettingsOrReconversion() {
        let pasteboard = FakePasteboard()
        pasteboard.lagsAfterOwnWrite = true
        let session = ConversionSession(pasteboard: pasteboard, defaults: defaults)
        session.activate(from: .launch)
        session.input = "ｶﾅ　ＡＢ"
        session.convertTapped()

        session.store.setAlias("正規化", for: Preset.regularisation.id)
        session.activate(from: .background)

        let expectedSettings = ConversionSettings(
            alphabet: .toASCII,
            accent: .toNFC,
            space: .ideographicToSpace,
            katakana: .toFullwidth,
            symbol: .toASCII,
            guillemets: .singleToDouble,
            unit: .ligatureToSI
        )
        #expect(session.store.selectedPreset.settings == expectedSettings)
        #expect(session.input == "ｶﾅ　ＡＢ")
        #expect(session.output == "カナ AB")
        #expect(session.selectAllToken == 1)
        #expect(pasteboard.content == "カナ AB")
    }

    @Test("A13 本当の名前と同じ別名は別名なしとして扱う")
    func aliasEqualToNameIsNoAlias() {
        let store = PresetStore(defaults: defaults)
        store.setAlias("正規化", for: Preset.regularisation.id)

        store.setAlias("régularisation", for: Preset.regularisation.id)

        #expect(store.alias(for: Preset.regularisation.id) == nil)
        #expect(store.listName(for: .regularisation) == "régularisation")
        #expect(PresetStore(defaults: defaults).alias(for: Preset.regularisation.id) == nil)
    }

    // c06-design.md の N
    @Test("N1 既定の名前・全 preserve のままなら消え、読み直しても無い")
    func discardsUntouchedNewPreset() {
        let store = PresetStore(defaults: defaults)
        let added = store.add(name: "新しいプリセット")

        #expect(store.discardIfUntouched(added.id, defaultName: "新しいプリセット"))

        #expect(store.preset(id: added.id) == nil)
        #expect(PresetStore(defaults: defaults).userPresets.isEmpty)
    }

    @Test("N2 名前だけ変えたものは残る")
    func keepsRenamedNewPreset() {
        let store = PresetStore(defaults: defaults)
        let added = store.add(name: "新しいプリセット")
        store.rename(added.id, to: "住所用")

        #expect(!store.discardIfUntouched(added.id, defaultName: "新しいプリセット"))

        #expect(PresetStore(defaults: defaults).userPresets.map(\.name) == ["住所用"])
    }

    @Test("N3 設定を 1 つでも変えたものは残る")
    func keepsNewPresetWithChangedSetting() {
        let store = PresetStore(defaults: defaults)
        let added = store.add(name: "新しいプリセット")
        store.updateSettings(added.id, to: ConversionSettings(space: .spaceToIdeographic))

        #expect(!store.discardIfUntouched(added.id, defaultName: "新しいプリセット"))

        #expect(PresetStore(defaults: defaults).userPresets.map(\.settings) == [ConversionSettings(space: .spaceToIdeographic)])
    }

    @Test("N4 名前と設定を変えてから元に戻したものは消える")
    func discardsNewPresetRevertedToDefaults() {
        let store = PresetStore(defaults: defaults)
        let added = store.add(name: "新しいプリセット")
        store.rename(added.id, to: "住所用")
        store.updateSettings(added.id, to: ConversionSettings(hiragana: .swap))
        store.rename(added.id, to: "新しいプリセット")
        store.updateSettings(added.id, to: ConversionSettings())

        #expect(store.discardIfUntouched(added.id, defaultName: "新しいプリセット"))

        #expect(PresetStore(defaults: defaults).userPresets.isEmpty)
    }

    @Test("N5 ビルトイン・未知の ID では何もしない")
    func ignoresBuiltInAndUnknownIDs() {
        let store = PresetStore(defaults: defaults)
        let kept = store.add(name: "新しいプリセット")

        #expect(!store.discardIfUntouched(Preset.regularisation.id, defaultName: "régularisation"))
        #expect(!store.discardIfUntouched(UUID(), defaultName: "新しいプリセット"))

        #expect(store.presets.count == 4)
        #expect(store.preset(id: kept.id) != nil)
    }
}
