import Testing
@testable import ReguCore

// c01-tests.md の A〜K(1 項目だけ設定し、他は preserve)
@Suite("Converter 単項目")
struct ConverterSingleSettingTests {
    // MARK: - A alphabet

    @Test("A1 全角英数を ASCII にする")
    func alphabetToASCII() {
        #expect(converted("ＡＢＣｘｙｚ０９", ConversionSettings(alphabet: .toASCII)) == scalars("ABCxyz09"))
    }

    @Test("A2 ASCII 英数を全角にする")
    func alphabetToFullwidth() {
        #expect(converted("Ab9", ConversionSettings(alphabet: .toFullwidth)) == scalars("Ａｂ９"))
    }

    @Test("A3 alphabet は全角記号を変えない")
    func alphabetLeavesSymbols() {
        #expect(converted("！＠", ConversionSettings(alphabet: .toASCII)) == scalars("！＠"))
    }

    // MARK: - B accent

    @Test("B1 結合文字を合成する", arguments: [
        ("e\u{301}", "\u{E9}"),
        ("\u{304B}\u{3099}", "\u{304C}")
    ])
    func accentToNFC(input: String, expected: String) {
        #expect(converted(input, ConversionSettings(accent: .toNFC)) == scalars(expected))
    }

    @Test("B2 合成済み文字を分解し、CJK 互換漢字は変えない", arguments: [
        ("\u{E9}", "e\u{301}"),
        ("\u{304C}", "\u{304B}\u{3099}"),
        ("\u{FA10}", "\u{FA10}")
    ])
    func accentToNFD(input: String, expected: String) {
        #expect(converted(input, ConversionSettings(accent: .toNFD)) == scalars(expected))
    }

    @Test("B3 NFC でも CJK 互換漢字(塚 U+FA10)は統合漢字に変えない")
    func accentToNFCKeepsCompatibilityIdeograph() {
        #expect(converted("\u{FA10}", ConversionSettings(accent: .toNFC)) == scalars("\u{FA10}"))
    }

    // MARK: - C space

    @Test("C1 和字間隔を空白 1 個にする")
    func ideographicToSpace() {
        #expect(converted("a\u{3000}b", ConversionSettings(space: .ideographicToSpace)) == scalars("a b"))
    }

    @Test("C2 和字間隔を空白 2 個にする")
    func ideographicToTwoSpaces() {
        #expect(converted("a\u{3000}b", ConversionSettings(space: .ideographicToTwoSpaces)) == scalars("a  b"))
    }

    @Test("C3 空白を和字間隔にする")
    func spaceToIdeographic() {
        #expect(converted("a b", ConversionSettings(space: .spaceToIdeographic)) == scalars("a\u{3000}b"))
    }

    @Test("C4 空白 2 個を左から和字間隔にし、余りの 1 個は残す")
    func twoSpacesToIdeographic() {
        #expect(converted("a   b", ConversionSettings(space: .twoSpacesToIdeographic)) == scalars("a\u{3000} b"))
    }

    @Test("C5 改行とタブは space のどの設定でも変えない", arguments: [
        SpaceOption.ideographicToSpace, .ideographicToTwoSpaces, .spaceToIdeographic, .twoSpacesToIdeographic
    ])
    func spaceLeavesNewlineAndTab(option: SpaceOption) {
        #expect(converted("a\n\tb", ConversionSettings(space: option)) == scalars("a\n\tb"))
    }

    // MARK: - D katakana

    @Test("D1 半角カナを全角にし、濁点・半濁点を合成する")
    func katakanaToFullwidth() {
        #expect(converted("ｶﾞｷﾞﾊﾟｳﾞｰｱ", ConversionSettings(katakana: .toFullwidth)) == scalars("ガギパヴーア"))
    }

    @Test("D2 全角カナを半角にし、濁音・半濁音を分ける")
    func katakanaToHalfwidth() {
        #expect(converted("ガパヴーア", ConversionSettings(katakana: .toHalfwidth)) == scalars("ｶﾞﾊﾟｳﾞｰｱ"))
    }

    @Test("D3 半角形の無いカナは残し、0201 の記号は半角にする")
    func katakanaToHalfwidthKeepsLettersWithoutHalfwidthForm() {
        #expect(converted("ヵヶヮ「」。、・", ConversionSettings(katakana: .toHalfwidth)) == scalars("ヵヶヮ｢｣｡､･"))
    }

    @Test("D4 0201 の記号を全角にし、ﾜﾞ を ヷ にする")
    func katakanaToFullwidthConvertsSymbolsAndVa() {
        #expect(converted("｢｣｡､･ﾜﾞ", ConversionSettings(katakana: .toFullwidth)) == scalars("「」。、・\u{30F7}"))
    }

    // MARK: - E hiragana

    @Test("E1 カタカナをひらがなにする(ヴ→ゔ を含む)")
    func katakanaToHiragana() {
        #expect(converted("カタカナヴ", ConversionSettings(hiragana: .katakanaToHiragana)) == scalars("かたかな\u{3094}"))
    }

    @Test("E2 ひらがなをカタカナにする")
    func hiraganaToKatakana() {
        #expect(converted("ひらがな", ConversionSettings(hiragana: .hiraganaToKatakana)) == scalars("ヒラガナ"))
    }

    @Test("E3 swap はひらがなとカタカナを入れ替える")
    func hiraganaSwap() {
        #expect(converted("ひらカタ", ConversionSettings(hiragana: .swap)) == scalars("ヒラかた"))
    }

    @Test("E4 長音記号と半角カナはひらがなにしない")
    func katakanaToHiraganaLeavesProlongedMarkAndHalfwidth() {
        #expect(converted("ーｶ", ConversionSettings(hiragana: .katakanaToHiragana)) == scalars("ーｶ"))
    }

    // MARK: - F symbol

    @Test("F1 全角記号を ASCII にする(＼～ を含む)")
    func symbolToASCII() {
        #expect(converted("！＃＄＼～（）", ConversionSettings(symbol: .toASCII)) == scalars("!#$\\~()"))
    }

    @Test("F2 toASCII は ￥ ￣ と全角英字を変えない")
    func symbolToASCIIKeepsYenMacronAndLetters() {
        #expect(converted("￥￣ＡＢ", ConversionSettings(symbol: .toASCII)) == scalars("￥￣ＡＢ"))
    }

    @Test("F3 toCP932Lower は ￥ ￣ も 0x5C 0x7E にする")
    func symbolToCP932Lower() {
        #expect(converted("￥￣！", ConversionSettings(symbol: .toCP932Lower)) == scalars("\\~!"))
    }

    @Test("F4 ASCII 記号を全角にし、英数は変えない")
    func symbolFromASCII() {
        #expect(converted("!\\~a1", ConversionSettings(symbol: .fromASCII)) == scalars("！＼～a1"))
    }

    @Test("F5 fromCP932Lower は \\ ~ を ￥ ￣ にする")
    func symbolFromCP932Lower() {
        #expect(converted("\\~!", ConversionSettings(symbol: .fromCP932Lower)) == scalars("￥￣！"))
    }

    // MARK: - G guillemets

    @Test("G1 「」を『』にする")
    func guillemetsSingleToDouble() {
        #expect(converted("「a」『b』", ConversionSettings(guillemets: .singleToDouble)) == scalars("『a』『b』"))
    }

    @Test("G2 『』を「」にする")
    func guillemetsDoubleToSingle() {
        #expect(converted("『a』", ConversionSettings(guillemets: .doubleToSingle)) == scalars("「a」"))
    }

    // MARK: - H unit

    @Test("H1 SI の組文字を英字にし、べき乗は上付きにする")
    func unitLigatureToSI() {
        #expect(converted("㎜㎝㎞㎡㎥㏄", ConversionSettings(unit: .ligatureToSI)) == scalars("mmcmkmm²m³cc"))
    }

    @Test("H2 数字の直後の単位だけを組文字にする")
    func unitSIToLigature() {
        #expect(converted("10mm 5 km² comma", ConversionSettings(unit: .siToLigature)) == scalars("10㎜ 5 ㎢ comma"))
    }

    @Test("H3 カタカナ組文字と非 SI の組文字は変えない")
    func unitLigatureToSIKeepsNonSI() {
        #expect(converted("㍉㏌㏂㏍", ConversionSettings(unit: .ligatureToSI)) == scalars("㍉㏌㏂㏍"))
    }

    @Test("H4 表に無い語・後ろに英字が続く単位は変えず、m2 は ㎡ にする")
    func unitSIToLigatureRequiresUnitBoundary() {
        #expect(
            converted("3 in stock 2 a.m. 10 m2 5mmx", ConversionSettings(unit: .siToLigature))
                == scalars("3 in stock 2 a.m. 10 ㎡ 5mmx")
        )
        #expect(converted("mm と km", ConversionSettings(unit: .siToLigature)) == scalars("mm と km"))
        #expect(converted("10mmの長さ、5km先", ConversionSettings(unit: .siToLigature)) == scalars("10㎜の長さ、5㎞先"))
    }

    @Test("H4b μ はギリシャ文字 U+03BC とマイクロ記号 U+00B5 のどちらでも組文字にする")
    func unitSIToLigatureAcceptsMicroSign() {
        #expect(
            converted("5\u{03BC}m 5\u{00B5}m 3 \u{00B5}g", ConversionSettings(unit: .siToLigature))
                == scalars("5㎛ 5㎛ 3 ㎍")
        )
    }

    @Test("H5 組文字を展開した英字も alphabet で全角になる")
    func unitLigatureToSIThenAlphabetToFullwidth() {
        #expect(converted("㎜", ConversionSettings(alphabet: .toFullwidth, unit: .ligatureToSI)) == scalars("ｍｍ"))
    }

    // MARK: - I HTML entity

    @Test("I1 名前付き・数値の文字参照を戻し、未知の名前は残す")
    func htmlDecode() {
        #expect(
            converted("&lt;&gt;&amp;&quot;&apos;&#x41;&#66;&eacute;&unknown;", ConversionSettings(htmlEntity: .decode))
                == scalars("<>&\"'AB\u{E9}&unknown;")
        )
    }

    @Test("I1b 1 パスだけ戻し、無効な数値と ; の無い参照は残す")
    func htmlDecodeSinglePassAndInvalidReferences() {
        #expect(
            converted("&amp;lt; &#0; &#x110000; &lt", ConversionSettings(htmlEntity: .decode))
                == scalars("&lt; &#0; &#x110000; &lt")
        )
    }

    @Test("I2 & < > \" ' の 5 文字を文字参照にする")
    func htmlEncode() {
        #expect(
            converted("<a href=\"x\">'&", ConversionSettings(htmlEntity: .encode))
                == scalars("&lt;a href=&quot;x&quot;&gt;&apos;&amp;")
        )
    }

    // MARK: - J URL entity

    @Test("J1 %XX の UTF-8 列を文字に戻す")
    func urlDecode() {
        #expect(converted("%E6%A4%9C%E7%B4%A2", ConversionSettings(urlEntity: .decode)) == scalars("検索"))
    }

    @Test("J2 % 単独・不完全な UTF-8・+ は変えない", arguments: ["100%", "%E6%A4", "a+b"])
    func urlDecodeLeavesInvalidSequences(input: String) {
        #expect(converted(input, ConversionSettings(urlEntity: .decode)) == scalars(input))
    }

    @Test("J2b 塊の中の有効な列だけ戻し(大小文字とも)、無効なバイトは %XX のまま残す")
    func urlDecodeMixedRun() {
        #expect(converted("%41%e6%a4%9c%E6%A4 %ZZ", ConversionSettings(urlEntity: .decode)) == scalars("A検%E6%A4 %ZZ"))
    }

    @Test("J3 非 ASCII 文字だけを %XX にする")
    func urlEncode() {
        #expect(
            converted("https://x.jp/検索?q=a b", ConversionSettings(urlEntity: .encode))
                == scalars("https://x.jp/%E6%A4%9C%E7%B4%A2?q=a b")
        )
    }

    // MARK: - K

    @Test("K1 全項目 preserve なら何も変えない")
    func allPreserveKeepsText() {
        let text = "ＡＢＣ abc\u{3000}ｶﾞ カナ かな「」『』！!㎜ 10mm &amp; %41 \u{E9}e\u{301}\u{FA10}\n\t"
        #expect(converted(text, ConversionSettings()) == scalars(text))
    }
}
