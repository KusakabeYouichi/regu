import Foundation

// HTML の文字参照と URL の %XX 表記
enum EntityConversion {
    // MARK: - HTML

    // 1 パスで置き換える(&amp;lt; は &lt; になる)。未知の名前・無効な数値・; の無いものはそのまま
    static func htmlDecode(_ text: String) -> String {
        let scalars = Array(text.unicodeScalars)
        var result = String.UnicodeScalarView()
        var index = 0
        while index < scalars.count {
            if scalars[index] == "&", let (decoded, length) = decodeReference(scalars, at: index) {
                result.append(contentsOf: decoded.unicodeScalars)
                index += length
            } else {
                result.append(scalars[index])
                index += 1
            }
        }
        return String(result)
    }

    // & の位置から ; までを読む。戻り値は置き換え後の文字列と、& から ; までの長さ
    private static func decodeReference(_ scalars: [Unicode.Scalar], at start: Int) -> (String, Int)? {
        var end = start + 1
        while end < scalars.count, scalars[end] != ";", end - start <= 32 {
            end += 1
        }
        guard end < scalars.count, scalars[end] == ";", end > start + 1 else {
            return nil
        }
        let body = String(String.UnicodeScalarView(scalars[(start + 1)..<end]))
        let length = end - start + 1
        if body.hasPrefix("#") {
            guard let scalar = numericReference(String(body.dropFirst())) else {
                return nil
            }
            return (String(scalar), length)
        }
        guard let value = HTMLEntityTable.named[body], let scalar = Unicode.Scalar(value) else {
            return nil
        }
        return (String(scalar), length)
    }

    // &#0;・サロゲート・U+10FFFF 超は無効(Unicode.Scalar がサロゲートと範囲外を弾く)
    private static func numericReference(_ digits: String) -> Unicode.Scalar? {
        let value: UInt32?
        if digits.hasPrefix("x") || digits.hasPrefix("X") {
            let hex = digits.dropFirst()
            value = hex.allSatisfy(\.isHexDigit) ? UInt32(hex, radix: 16) : nil
        } else {
            value = digits.allSatisfy { $0.isASCII && $0.isNumber } ? UInt32(digits, radix: 10) : nil
        }
        guard let value, value != 0 else {
            return nil
        }
        return Unicode.Scalar(value)
    }

    // & < > " ' の 5 文字だけを参照にする
    static func htmlEncode(_ text: String) -> String {
        var result = ""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\"": result += "&quot;"
            case "'": result += "&apos;"
            default: result.unicodeScalars.append(scalar)
            }
        }
        return result
    }

    // MARK: - URL

    // %XX の連続を 1 塊とし、有効な UTF-8 列だけを復号する。無効なバイトは元の %XX 表記のまま残す。+ は空白にしない
    static func urlDecode(_ text: String) -> String {
        let scalars = Array(text.unicodeScalars)
        var result = String.UnicodeScalarView()
        var index = 0
        while index < scalars.count {
            var bytes: [UInt8] = []
            var originals: [String] = []
            while let byte = percentByte(scalars, at: index) {
                bytes.append(byte)
                originals.append(String(String.UnicodeScalarView(scalars[index..<(index + 3)])))
                index += 3
            }
            if bytes.isEmpty {
                result.append(scalars[index])
                index += 1
            } else {
                result.append(contentsOf: decodeUTF8Run(bytes, originals: originals).unicodeScalars)
            }
        }
        return String(result)
    }

    private static func percentByte(_ scalars: [Unicode.Scalar], at index: Int) -> UInt8? {
        guard index + 2 < scalars.count, scalars[index] == "%" else {
            return nil
        }
        let hex = String(String.UnicodeScalarView(scalars[(index + 1)...(index + 2)]))
        guard hex.allSatisfy(\.isHexDigit) else {
            return nil
        }
        return UInt8(hex, radix: 16)
    }

    private static func decodeUTF8Run(_ bytes: [UInt8], originals: [String]) -> String {
        var result = ""
        var index = 0
        while index < bytes.count {
            if let (scalar, length) = decodeUTF8Scalar(bytes, at: index) {
                result.unicodeScalars.append(scalar)
                index += length
            } else {
                result += originals[index]
                index += 1
            }
        }
        return result
    }

    // 先頭バイトから 1 文字分を読む。過長表現・サロゲート・範囲外は無効
    private static func decodeUTF8Scalar(_ bytes: [UInt8], at index: Int) -> (Unicode.Scalar, Int)? {
        let lead = bytes[index]
        let length: Int
        let minimum: UInt32
        var value: UInt32
        switch lead {
        case 0x00...0x7F:
            return Unicode.Scalar(UInt32(lead)).map { ($0, 1) }
        case 0xC2...0xDF:
            length = 2
            minimum = 0x80
            value = UInt32(lead & 0x1F)
        case 0xE0...0xEF:
            length = 3
            minimum = 0x800
            value = UInt32(lead & 0x0F)
        case 0xF0...0xF4:
            length = 4
            minimum = 0x10000
            value = UInt32(lead & 0x07)
        default:
            return nil
        }
        guard index + length <= bytes.count else {
            return nil
        }
        for offset in 1..<length {
            let byte = bytes[index + offset]
            guard byte & 0xC0 == 0x80 else {
                return nil
            }
            value = (value << 6) | UInt32(byte & 0x3F)
        }
        guard value >= minimum, let scalar = Unicode.Scalar(value) else {
            return nil
        }
        return (scalar, length)
    }

    // 非 ASCII 文字だけを UTF-8 の %XX にする(URL の構造 :/?&= や空白は残す)
    static func urlEncode(_ text: String) -> String {
        var result = ""
        for scalar in text.unicodeScalars {
            if scalar.isASCII {
                result.unicodeScalars.append(scalar)
            } else {
                for byte in String(scalar).utf8 {
                    result += "%" + hexDigits(byte)
                }
            }
        }
        return result
    }

    private static func hexDigits(_ byte: UInt8) -> String {
        let digits = Array("0123456789ABCDEF")
        return String([digits[Int(byte >> 4)], digits[Int(byte & 0x0F)]])
    }
}
