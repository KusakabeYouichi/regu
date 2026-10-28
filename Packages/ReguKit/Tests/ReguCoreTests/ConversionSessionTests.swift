import Foundation
import Testing
@testable import ReguCore

// c01-tests.md の T（偽のクリップボードで確かめる）
@Suite("ConversionSession")
@MainActor
struct ConversionSessionTests {
    private let testDefaults = TestDefaults()

    private var defaults: UserDefaults {
        testDefaults.defaults
    }

    @Test("T1 起動時にクリップボードを読み、変換して全選択を求め、結果をクリップボードへ書く")
    func activateOnLaunchConvertsClipboard() {
        let pasteboard = FakePasteboard(content: "ＡＢＣ")
        let session = ConversionSession(pasteboard: pasteboard, defaults: defaults)

        session.activate(from: .launch)

        #expect(session.input == "ＡＢＣ")
        #expect(session.output == "ABC")
        #expect(session.selectAllToken == 1)
        #expect(pasteboard.content == "ABC")
    }

    @Test("T11 書き込み直後の changeCount が古くても、自分の出力は前面化で再変換せず、他アプリのコピーは変換する")
    func ownOutputIsRecognizedWhenChangeCountLags() {
        let pasteboard = FakePasteboard()
        pasteboard.lagsAfterOwnWrite = true
        let session = ConversionSession(pasteboard: pasteboard, defaults: defaults)
        session.activate(from: .launch)
        session.input = "ｶﾅ"
        session.convertTapped()

        session.activate(from: .background)

        #expect(session.input == "ｶﾅ")
        #expect(session.output == "カナ")
        #expect(session.selectAllToken == 1)
        #expect(pasteboard.content == "カナ")

        pasteboard.copyFromOtherApp("ＸＹ")
        session.activate(from: .background)

        #expect(session.input == "ＸＹ")
        #expect(session.output == "XY")
        #expect(pasteboard.content == "XY")
    }

    @Test("T13 書き込み直後の changeCount が古くても、背面へ移った後にプリセットを変えて戻ったとき自分の出力を再変換しない")
    func ownOutputIsNotReconvertedAfterPresetChangeWhenChangeCountLags() {
        let pasteboard = FakePasteboard()
        pasteboard.lagsAfterOwnWrite = true
        let session = ConversionSession(pasteboard: pasteboard, defaults: defaults)
        session.activate(from: .launch)
        session.input = "ｶﾅ"
        session.convertTapped()
        session.select(Preset.rubyHeritee.id)

        session.enterBackground()
        session.activate(from: .background)

        #expect(session.input == "ｶﾅ")
        #expect(session.output == "カナ")
        #expect(session.selectAllToken == 1)
        #expect(pasteboard.content == "カナ")
    }

    @Test("T12 自分の出力と同じ文字列でも、プリセットを変えた後に他アプリからコピーされたものは変換する")
    func sameTextIsConvertedAfterPresetChange() {
        let pasteboard = FakePasteboard(content: "ＡＢＣ")
        let session = ConversionSession(pasteboard: pasteboard, defaults: defaults)
        let keep = session.store.add(name: "そのまま", settings: ConversionSettings())
        session.select(keep.id)
        session.activate(from: .launch)
        #expect(session.output == "ＡＢＣ")

        session.select(Preset.regularisation.id)
        pasteboard.copyFromOtherApp("ＡＢＣ")
        session.activate(from: .background)

        #expect(session.output == "ABC")
        #expect(pasteboard.content == "ABC")
    }

    @Test("T2 自分が書いたクリップボードのままなら前面化しても何も変えない")
    func activateIgnoresOwnOutput() {
        let pasteboard = FakePasteboard(content: "ＡＢＣ")
        let session = ConversionSession(pasteboard: pasteboard, defaults: defaults)
        session.activate(from: .launch)

        session.activate(from: .background)

        #expect(session.input == "ＡＢＣ")
        #expect(session.output == "ABC")
        #expect(session.selectAllToken == 1)
        #expect(pasteboard.content == "ABC")
    }

    @Test("T3 swap の出力を再び前面化で変換して元に戻すことはない")
    func swapOutputIsNotConvertedBack() {
        let pasteboard = FakePasteboard(content: "ひら")
        let session = ConversionSession(pasteboard: pasteboard, defaults: defaults)
        let swap = session.store.add(name: "入れ替え", settings: ConversionSettings(hiragana: .swap))
        session.select(swap.id)

        session.activate(from: .launch)
        #expect(session.output == "ヒラ")

        session.activate(from: .background)
        #expect(session.output == "ヒラ")
        #expect(pasteboard.content == "ヒラ")
    }

    @Test("T4 クリップボードが空文字・文字列無しなら何も変えない", arguments: ["", nil] as [String?])
    func activateIgnoresEmptyClipboard(content: String?) {
        let pasteboard = FakePasteboard(content: content)
        let session = ConversionSession(pasteboard: pasteboard, defaults: defaults)

        session.activate(from: .launch)

        #expect(session.input == "")
        #expect(session.output == "")
        #expect(session.selectAllToken == 0)
        #expect(pasteboard.content == content)
    }

    @Test("T5 変換ボタンは手入力を変換し、全選択を求め、クリップボードへ書く")
    func convertTappedConvertsInput() {
        let pasteboard = FakePasteboard()
        let session = ConversionSession(pasteboard: pasteboard, defaults: defaults)
        session.input = "ｶﾅ"

        session.convertTapped()

        #expect(session.output == "カナ")
        #expect(session.selectAllToken == 1)
        #expect(pasteboard.content == "カナ")
    }

    @Test("T6 プリセットを変えると保存されるが、結果は変換し直さない")
    func selectingPresetSavesWithoutReconverting() {
        let pasteboard = FakePasteboard(content: "ＡＢＣ")
        let session = ConversionSession(pasteboard: pasteboard, defaults: defaults)
        session.activate(from: .launch)

        session.select(Preset.adresseHeritee.id)

        #expect(session.output == "ABC")
        #expect(pasteboard.content == "ABC")
        #expect(PresetStore(defaults: defaults).selectedPresetID == Preset.adresseHeritee.id)
    }

    @Test("T7 入力が空・空白だけなら変換ボタンは何もしない", arguments: ["", " \u{3000}\n"])
    func convertTappedIgnoresBlankInput(input: String) {
        let pasteboard = FakePasteboard(content: "元の内容")
        let session = ConversionSession(pasteboard: pasteboard, defaults: defaults)
        session.input = input

        session.convertTapped()

        #expect(session.output == "")
        #expect(session.selectAllToken == 0)
        #expect(pasteboard.content == "元の内容")
    }

    @Test("T8 再起動しても、自分が書いたクリップボードは変換しない")
    func relaunchIgnoresOwnOutput() {
        let pasteboard = FakePasteboard(content: "ＡＢＣ")
        ConversionSession(pasteboard: pasteboard, defaults: defaults).activate(from: .launch)

        let relaunched = ConversionSession(pasteboard: pasteboard, defaults: defaults)
        relaunched.activate(from: .launch)

        #expect(relaunched.input == "")
        #expect(relaunched.output == "")
        #expect(relaunched.selectAllToken == 0)
        #expect(pasteboard.content == "ABC")
    }

    @Test("T9 ペーストを拒否されたら、同じクリップボードの内容では読み取りを再び試みない")
    func deniedReadIsNotRetried() {
        let pasteboard = FakePasteboard(content: "ひら")
        pasteboard.deniesRead = true
        let session = ConversionSession(pasteboard: pasteboard, defaults: defaults)

        session.activate(from: .launch)
        pasteboard.deniesRead = false
        session.activate(from: .background)

        #expect(session.output == "")
        #expect(pasteboard.content == "ひら")
        #expect(session.selectAllToken == 0)
    }

    @Test("T10 inactive からの復帰では自動変換しない")
    func activateFromInactiveDoesNothing() {
        let pasteboard = FakePasteboard(content: "ひら")
        let session = ConversionSession(pasteboard: pasteboard, defaults: defaults)

        session.activate(from: .inactive)

        #expect(session.input == "")
        #expect(session.output == "")
        #expect(session.selectAllToken == 0)
        #expect(pasteboard.content == "ひら")
    }
}
