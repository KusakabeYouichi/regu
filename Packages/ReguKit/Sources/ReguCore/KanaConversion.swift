import Foundation

// 半角カナ（JIS X 0201）↔ 全角カナ（JIS X 0208）と、ひらがな ↔ カタカナ
enum KanaConversion {
    private static let halfwidthVoicedMark: Unicode.Scalar = "\u{FF9E}"
    private static let halfwidthSemiVoicedMark: Unicode.Scalar = "\u{FF9F}"
    private static let combiningVoicedMark: Unicode.Scalar = "\u{3099}"
    private static let combiningSemiVoicedMark: Unicode.Scalar = "\u{309A}"

    // JIS X 0201 カナ集合（記号を含む）と対応する全角文字。単独の濁点・半濁点は ゛ ゜ にする
    private static let halfwidthLetters = "｡｢｣､･ｦｧｨｩｪｫｬｭｮｯｰｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝﾞﾟ"
    private static let fullwidthLetters = "。「」、・ヲァィゥェォャュョッーアイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワン゛゜"

    private static let halfToFull: [Unicode.Scalar: Unicode.Scalar] = {
        Dictionary(uniqueKeysWithValues: zip(halfwidthLetters.unicodeScalars, fullwidthLetters.unicodeScalars))
    }()

    private static let fullToHalf: [Unicode.Scalar: Unicode.Scalar] = {
        Dictionary(uniqueKeysWithValues: zip(fullwidthLetters.unicodeScalars, halfwidthLetters.unicodeScalars))
    }()

    // ｶﾞ→ガ のように、後ろの濁点・半濁点と合成できる文字は 1 文字にする（ｳﾞ→ヴ, ﾜﾞ→ヷ, ｦﾞ→ヺ）
    static func toFullwidthKatakana(_ text: String) -> String {
        let scalars = Array(text.unicodeScalars)
        var result = String.UnicodeScalarView()
        var index = 0
        while index < scalars.count {
            let scalar = scalars[index]
            guard let full = halfToFull[scalar] else {
                result.append(scalar)
                index += 1
                continue
            }
            if index + 1 < scalars.count, let composed = composeVoiced(full, mark: scalars[index + 1]) {
                result.append(composed)
                index += 2
            } else {
                result.append(full)
                index += 1
            }
        }
        return String(result)
    }

    private static func composeVoiced(_ base: Unicode.Scalar, mark: Unicode.Scalar) -> Unicode.Scalar? {
        let combining: Unicode.Scalar
        switch mark {
        case halfwidthVoicedMark: combining = combiningVoicedMark
        case halfwidthSemiVoicedMark: combining = combiningSemiVoicedMark
        default: return nil
        }
        let composed = (String(base) + String(combining)).precomposedStringWithCanonicalMapping.unicodeScalars
        return composed.count == 1 ? composed.first : nil
    }

    // ガ→ｶﾞ のように分解して半角にする。半角形の無い文字（ヮ ヵ ヶ ヰ ヱ ヸ ヹ 等）はそのまま
    static func toHalfwidthKatakana(_ text: String) -> String {
        var result = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            if let half = fullToHalf[scalar] {
                result.append(half)
            } else if let pair = decomposeVoiced(scalar) {
                result.append(contentsOf: pair)
            } else {
                result.append(scalar)
            }
        }
        return String(result)
    }

    private static func decomposeVoiced(_ scalar: Unicode.Scalar) -> [Unicode.Scalar]? {
        guard (0x30A1...0x30FA).contains(scalar.value) else {
            return nil
        }
        let decomposed = Array(String(scalar).decomposedStringWithCanonicalMapping.unicodeScalars)
        guard decomposed.count == 2, let base = fullToHalf[decomposed[0]] else {
            return nil
        }
        switch decomposed[1] {
        case combiningVoicedMark: return [base, halfwidthVoicedMark]
        case combiningSemiVoicedMark: return [base, halfwidthSemiVoicedMark]
        default: return nil
        }
    }

    // ァ-ヶ ↔ ぁ-ゖ、ヽヾ ↔ ゝゞ（差は 0x60）。ヷ-ヺ・ー・半角カナは対象外
    static func convertHiragana(_ scalar: Unicode.Scalar, _ option: HiraganaOption) -> Unicode.Scalar {
        let isKatakana = (0x30A1...0x30F6).contains(scalar.value) || (0x30FD...0x30FE).contains(scalar.value)
        let isHiragana = (0x3041...0x3096).contains(scalar.value) || (0x309D...0x309E).contains(scalar.value)
        switch option {
        case .preserve:
            return scalar
        case .katakanaToHiragana:
            return isKatakana ? Converter.shifted(scalar, by: -0x60) : scalar
        case .hiraganaToKatakana:
            return isHiragana ? Converter.shifted(scalar, by: 0x60) : scalar
        case .swap:
            if isKatakana {
                return Converter.shifted(scalar, by: -0x60)
            }
            return isHiragana ? Converter.shifted(scalar, by: 0x60) : scalar
        }
    }
}
