import Foundation

// 設定どおりに文字列を変換する。実行順は numbers「実行順」シートの 3 段階:
// Prétraitement(復号・正規化)を全部終えてから Traitement(文字種の変換)、それを全部終えてから Post-traitement(符号化・分解)。
// 各段階の中は番号順。Traitement はシートの並び順(扱う文字が重ならないので結果は順に依存しない)
public enum Converter {
    public static func convert(_ text: String, settings: ConversionSettings) -> String {
        var text = text
        // Prétraitement
        // 1. HTML Entity → Code Point
        if settings.htmlEntity == .decode {
            text = EntityConversion.htmlDecode(text)
        }
        // 2. URL Entity → Code Point
        if settings.urlEntity == .decode {
            text = EntityConversion.urlDecode(text)
        }
        // 3. ligature → SI
        if settings.unit == .ligatureToSI {
            text = UnitConversion.convert(text, .ligatureToSI)
        }
        // 4. JIS X 0201 → JIS X 0208(カナ)
        if settings.katakana == .toFullwidth {
            text = KanaConversion.toFullwidthKatakana(text)
        }
        // 5. NFD → NFC
        if settings.accent == .toNFC {
            text = convertAccent(text, .toNFC)
        }
        // 6. MIME-decode(まだ無い機能)

        // Traitement
        // [ラテン] alphabet
        text = mapScalars(text) { convertAlphabet($0, settings.alphabet) }
        // [空白] space
        text = convertSpace(text, settings.space)
        // [仮名] hiragana
        text = mapScalars(text) { KanaConversion.convertHiragana($0, settings.hiragana) }
        // [記号] symbol, guillemets
        text = convertSymbol(text, settings.symbol)
        text = mapScalars(text) { convertGuillemets($0, settings.guillemets) }

        // Post-traitement
        // 1. MIME-encode(まだ無い機能)
        // 2. NFC → NFD
        if settings.accent == .toNFD {
            text = convertAccent(text, .toNFD)
        }
        // 3. JIS X 0208 → JIS X 0201(カナ)
        if settings.katakana == .toHalfwidth {
            text = KanaConversion.toHalfwidthKatakana(text)
        }
        // 4. SI → ligature
        if settings.unit == .siToLigature {
            text = UnitConversion.convert(text, .siToLigature)
        }
        // 5. Code Point → URL Entity
        if settings.urlEntity == .encode {
            text = EntityConversion.urlEncode(text)
        }
        // 6. Code Point → HTML Entity
        if settings.htmlEntity == .encode {
            text = EntityConversion.htmlEncode(text)
        }
        return text
    }

    static func mapScalars(_ text: String, _ transform: (Unicode.Scalar) -> Unicode.Scalar) -> String {
        var result = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            result.append(transform(scalar))
        }
        return String(result)
    }

    static func shifted(_ scalar: Unicode.Scalar, by offset: Int) -> Unicode.Scalar {
        Unicode.Scalar(UInt32(Int(scalar.value) + offset)) ?? scalar
    }

    // MARK: - accent

    // CJK 互換漢字(U+F900-FAFF, U+2F800-2FA1F)を含む書記素は正規化すると統合漢字に変わるため除外する
    private static func convertAccent(_ text: String, _ option: AccentOption) -> String {
        guard option != .preserve else {
            return text
        }
        var result = ""
        for character in text {
            let grapheme = String(character)
            if grapheme.unicodeScalars.contains(where: isCJKCompatibilityIdeograph) {
                result.append(contentsOf: grapheme)
            } else if option == .toNFD {
                result.append(contentsOf: grapheme.decomposedStringWithCanonicalMapping)
            } else {
                result.append(contentsOf: grapheme.precomposedStringWithCanonicalMapping)
            }
        }
        return result
    }

    private static func isCJKCompatibilityIdeograph(_ scalar: Unicode.Scalar) -> Bool {
        (0xF900...0xFAFF).contains(scalar.value) || (0x2F800...0x2FA1F).contains(scalar.value)
    }

    // MARK: - alphabet

    // Ａ-Ｚ ａ-ｚ ０-９ ↔ ASCII(全角と ASCII の差は 0xFEE0)
    private static func convertAlphabet(_ scalar: Unicode.Scalar, _ option: AlphabetOption) -> Unicode.Scalar {
        switch option {
        case .preserve:
            return scalar
        case .toASCII:
            return isFullwidthAlphanumeric(scalar) ? shifted(scalar, by: -0xFEE0) : scalar
        case .toFullwidth:
            return isASCIIAlphanumeric(scalar) ? shifted(scalar, by: 0xFEE0) : scalar
        }
    }

    static func isASCIIAlphanumeric(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x30...0x39, 0x41...0x5A, 0x61...0x7A: true
        default: false
        }
    }

    private static func isFullwidthAlphanumeric(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0xFF10...0xFF19, 0xFF21...0xFF3A, 0xFF41...0xFF5A: true
        default: false
        }
    }

    // MARK: - symbol

    private static let fullwidthYen: Unicode.Scalar = "\u{FFE5}"
    private static let fullwidthMacron: Unicode.Scalar = "\u{FFE3}"

    // 全角記号(U+FF01-FF5E の英数以外)↔ ASCII 記号。CP932 系は 0x5C=¥, 0x7E=‾ として ￥ ￣ と対応させる
    private static func convertSymbol(_ text: String, _ option: SymbolOption) -> String {
        guard option != .preserve else {
            return text
        }
        return mapScalars(text) { scalar in
            switch option {
            case .preserve:
                return scalar
            case .toASCII, .toCP932Lower:
                if option == .toCP932Lower {
                    if scalar == fullwidthYen {
                        return "\\"
                    }
                    if scalar == fullwidthMacron {
                        return "~"
                    }
                }
                let isFullwidthSymbol = (0xFF01...0xFF5E).contains(scalar.value) && !isFullwidthAlphanumeric(scalar)
                return isFullwidthSymbol ? shifted(scalar, by: -0xFEE0) : scalar
            case .fromASCII, .fromCP932Lower:
                if option == .fromCP932Lower {
                    if scalar == "\\" {
                        return fullwidthYen
                    }
                    if scalar == "~" {
                        return fullwidthMacron
                    }
                }
                let isASCIISymbol = (0x21...0x7E).contains(scalar.value) && !isASCIIAlphanumeric(scalar)
                return isASCIISymbol ? shifted(scalar, by: 0xFEE0) : scalar
            }
        }
    }

    // MARK: - space

    private static let ideographicSpace: Unicode.Scalar = "\u{3000}"

    private static func convertSpace(_ text: String, _ option: SpaceOption) -> String {
        guard option != .preserve else {
            return text
        }
        var result = String.UnicodeScalarView()
        var pendingSpace = false
        for scalar in text.unicodeScalars {
            switch option {
            case .preserve:
                result.append(scalar)
            case .ideographicToSpace:
                if scalar == ideographicSpace {
                    result.append(" ")
                } else {
                    result.append(scalar)
                }
            case .ideographicToTwoSpaces:
                if scalar == ideographicSpace {
                    result.append(contentsOf: "  ".unicodeScalars)
                } else {
                    result.append(scalar)
                }
            case .spaceToIdeographic:
                result.append(scalar == " " ? ideographicSpace : scalar)
            case .twoSpacesToIdeographic:
                // 左から 2 個ずつ置き換え、余りの 1 個は残す
                if scalar == " " {
                    if pendingSpace {
                        result.append(ideographicSpace)
                        pendingSpace = false
                    } else {
                        pendingSpace = true
                    }
                } else {
                    if pendingSpace {
                        result.append(" ")
                        pendingSpace = false
                    }
                    result.append(scalar)
                }
            }
        }
        if pendingSpace {
            result.append(" ")
        }
        return String(result)
    }

    // MARK: - guillemets

    private static func convertGuillemets(_ scalar: Unicode.Scalar, _ option: GuillemetsOption) -> Unicode.Scalar {
        switch (option, scalar) {
        case (.singleToDouble, "「"): "『"
        case (.singleToDouble, "」"): "』"
        case (.doubleToSingle, "『"): "「"
        case (.doubleToSingle, "』"): "」"
        default: scalar
        }
    }
}
