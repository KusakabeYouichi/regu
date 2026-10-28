import Testing
@testable import ReguCore

// c01-tests.md の L（組み合わせと適用順）
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
}
