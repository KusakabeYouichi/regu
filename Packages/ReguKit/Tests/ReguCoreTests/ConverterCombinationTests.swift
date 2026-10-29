import Testing
@testable import ReguCore

// c01-tests.md の L(組み合わせと適用順)
@Suite("Converter 組み合わせ・順序")
struct ConverterCombinationTests {
    @Test("L1 ひらがなをカタカナにしてから半角にする")
    func hiraganaToKatakanaThenHalfwidth() {
        let settings = ConversionSettings(katakana: .toHalfwidth, hiragana: .hiraganaToKatakana)
        #expect(converted("ふりがな", settings) == scalars("ﾌﾘｶﾞﾅ"))
    }

    @Test("L2 半角カナを全角にしてからひらがなにする")
    func fullwidthThenKatakanaToHiragana() {
        let settings = ConversionSettings(katakana: .toFullwidth, hiragana: .katakanaToHiragana)
        #expect(converted("ﾌﾘｶﾞﾅ", settings) == scalars("ふりがな"))
    }

    @Test("L3 URL decode の結果も alphabet で全角になる")
    func urlDecodeThenAlphabet() {
        let settings = ConversionSettings(alphabet: .toFullwidth, urlEntity: .decode)
        #expect(converted("%41", settings) == scalars("Ａ"))
    }

    @Test("L4 HTML encode の後に URL encode し、参照の & は % にしない")
    func htmlEncodeThenURLEncode() {
        let settings = ConversionSettings(htmlEntity: .encode, urlEntity: .encode)
        #expect(converted("<検>", settings) == scalars("&lt;%E6%A4%9C&gt;"))
    }

    // c04-tests.md の M(numbers「実行順」シートの 3 段階に依存するもの)
    @Test("M1 HTML を先に復号してから URL を復号するので、&#37;41 が A になる")
    func htmlDecodeThenURLDecode() {
        let settings = ConversionSettings(htmlEntity: .decode, urlEntity: .decode)
        #expect(converted("&#37;41 &amp;", settings) == scalars("A &"))
    }

    @Test("M2 SI → 組文字は後処理なので、全角の １０ｍｍ も ASCII 化の後に組文字になる")
    func alphabetToASCIIThenSIToLigature() {
        let settings = ConversionSettings(alphabet: .toASCII, unit: .siToLigature)
        #expect(converted("１０ｍｍ ５ｋｍ", settings) == scalars("10㎜ 5㎞"))
    }

    @Test("M3 前処理は半角カナ→全角の後に NFC なので、ｶ+結合濁点 も合成されてからひらがな化される")
    func pretreatmentThenHiragana() {
        let settings = ConversionSettings(accent: .toNFC, katakana: .toFullwidth, hiragana: .katakanaToHiragana)
        #expect(converted("ﾌﾘｶﾞﾅ ｶ\u{3099} e\u{301}", settings) == scalars("ふりがな が é"))
    }

    @Test("M4 カタカナ化の後に後処理(半角カナ・NFD)をする")
    func katakanaThenPosttreatment() {
        let settings = ConversionSettings(accent: .toNFD, katakana: .toHalfwidth, hiragana: .hiraganaToKatakana)
        #expect(converted("ふりがな é", settings) == scalars("ﾌﾘｶﾞﾅ e\u{301}"))
    }

    @Test("M9 NFD は後処理なので、全角化した後に分解される(é は英字でないため全角化されず e+U+0301 になる)")
    func fullwidthThenNFD() {
        let settings = ConversionSettings(alphabet: .toFullwidth, accent: .toNFD)
        #expect(converted("aé", settings) == scalars("ａe\u{301}"))
    }

    @Test("M5 符号化は変換後の文字に対して行う(全角化した ＜＞ は HTML ではなく URL で符号化される)")
    func symbolThenEncode() {
        let settings = ConversionSettings(symbol: .fromASCII, htmlEntity: .encode, urlEntity: .encode)
        #expect(converted("<検>", settings) == scalars("%EF%BC%9C%E6%A4%9C%EF%BC%9E"))
    }

    @Test("M6 かぎ括弧の変換の後に半角カナ化するので、「」は ｢｣ になり 『』 は残る")
    func guillemetsThenHalfwidth() {
        let toSingle = ConversionSettings(katakana: .toHalfwidth, guillemets: .doubleToSingle)
        #expect(converted("『a』", toSingle) == scalars("｢a｣"))
        let toDouble = ConversionSettings(katakana: .toHalfwidth, guillemets: .singleToDouble)
        #expect(converted("「a」", toDouble) == scalars("『a』"))
    }

    @Test("M7 全角化の後に SI → 組文字が来るため、全角の数字・英字には組文字が作られない(既知の帰結)")
    func fullwidthThenSIToLigatureDoesNotMatch() {
        let settings = ConversionSettings(alphabet: .toFullwidth, unit: .siToLigature)
        #expect(converted("10mm", settings) == scalars("１０ｍｍ"))
    }

    @Test("M8 HTML を URL より先に復号するため、URL 符号化された HTML 参照は参照のまま残る(既知の制限)")
    func urlEncodedHTMLEntityStaysEntity() {
        let settings = ConversionSettings(htmlEntity: .decode, urlEntity: .decode)
        #expect(converted("%26amp;", settings) == scalars("&amp;"))
    }
}
