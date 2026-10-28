import Testing
@testable import ReguCore

// c01-tests.md の P（numbers のプリセットシートどおり。ruby héritée は決定7）
@Suite("既定プリセット")
struct BuiltInPresetTests {
    @Test("P1 régularisation は英数記号を ASCII、半角カナを全角、「」を『』、組文字を展開、NFC にする")
    func regularisation() {
        #expect(
            converted("ＡＢＣ１２３！\u{3000}ｶﾀｶﾅ「x」㎜e\u{301}", Preset.regularisation.settings)
                == scalars("ABC123! カタカナ『x』mm\u{E9}")
        )
    }

    @Test("P2 Adresse héritée は英数記号と空白を全角、カタカナを半角にする")
    func adresseHeritee() {
        #expect(
            converted("Tokyo 1-2-3 カタカナ", Preset.adresseHeritee.settings)
                == scalars("Ｔｏｋｙｏ\u{3000}１－２－３\u{3000}ｶﾀｶﾅ")
        )
    }

    @Test("P3 ruby héritée はひらがなもカタカナも半角カナにする")
    func rubyHeritee() {
        #expect(converted("ヤマダ タロウ やまだ", Preset.rubyHeritee.settings) == scalars("ﾔﾏﾀﾞ ﾀﾛｳ ﾔﾏﾀﾞ"))
    }

    @Test("P4 既定は 3 つで、この順に並び、編集不可の印が付く")
    func namesAndOrder() {
        #expect(Preset.builtIns.map(\.name) == ["régularisation", "Adresse héritée", "ruby héritée"])
        #expect(Preset.builtIns.map(\.isBuiltIn) == [true, true, true])
    }
}
