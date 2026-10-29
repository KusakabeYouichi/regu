import Foundation

// SI 単位の組文字(㎜ 等)↔ 英字表記。両方向で同じ表を使う
enum UnitConversion {
    // 組文字と SI 表記(べき乗は上付き)。非 SI(㏒ ㏑ ㏕ ㏏ ㏇ ㏋ 等)とカタカナ組文字は含めない
    private static let table: [(ligature: Unicode.Scalar, si: String)] = [
        ("㎎", "mg"), ("㎏", "kg"), ("㎜", "mm"), ("㎝", "cm"), ("㎞", "km"),
        ("㎟", "mm²"), ("㎠", "cm²"), ("㎡", "m²"), ("㎢", "km²"),
        ("㎣", "mm³"), ("㎤", "cm³"), ("㎥", "m³"), ("㎦", "km³"),
        ("㏄", "cc"), ("㎖", "mL"), ("㎗", "dL"), ("㎘", "kL"),
        ("㎐", "Hz"), ("㎑", "kHz"), ("㎒", "MHz"), ("㎓", "GHz"),
        ("㎾", "kW"), ("㎿", "MW"), ("㎽", "mW"), ("㎸", "kV"), ("㎶", "μV"), ("㎷", "mV"), ("㎹", "MV"),
        ("㎃", "mA"), ("㎂", "μA"), ("㎈", "cal"), ("㎉", "kcal"),
        ("㎳", "ms"), ("㎲", "μs"), ("㎱", "ns"), ("㎰", "ps"), ("㎧", "m/s"), ("㎨", "m/s²"),
        ("㍱", "hPa"), ("㎩", "Pa"), ("㎪", "kPa"), ("㎫", "MPa"), ("㎬", "GPa"),
        ("㏈", "dB"), ("㎛", "μm"), ("㍲", "da"), ("㍴", "bar"), ("㍷", "dm"), ("㍸", "dm²"), ("㍹", "dm³"),
        ("㎍", "μg"), ("㎕", "μL"), ("㏃", "Bq"), ("㏅", "cd"), ("㏉", "Gy"), ("㏖", "mol"),
        ("㏛", "sr"), ("㏜", "Sv"), ("㏝", "Wb"), ("㎭", "rad"), ("㏆", "C/kg")
    ]

    private static let ligatureToSI: [Unicode.Scalar: String] = {
        Dictionary(uniqueKeysWithValues: table.map { ($0.ligature, $0.si) })
    }()

    // SI 表記(² ³ を 2 3 で書いたもの、μ をマイクロ記号 U+00B5 で書いたものも含む)→ 組文字。
    // 長い順に並べて最長一致にする
    private static let siCandidates: [(si: [Unicode.Scalar], ligature: Unicode.Scalar)] = {
        var candidates: [(si: [Unicode.Scalar], ligature: Unicode.Scalar)] = []
        for entry in table {
            let plain = entry.si.replacingOccurrences(of: "²", with: "2").replacingOccurrences(of: "³", with: "3")
            let micro = entry.si.replacingOccurrences(of: "\u{03BC}", with: "\u{00B5}")
            for spelling in Set([entry.si, plain, micro]) {
                candidates.append((Array(spelling.unicodeScalars), entry.ligature))
            }
        }
        return candidates.sorted { $0.si.count > $1.si.count }
    }()

    static func convert(_ text: String, _ option: UnitOption) -> String {
        switch option {
        case .preserve:
            return text
        case .ligatureToSI:
            var result = String.UnicodeScalarView()
            for scalar in text.unicodeScalars {
                if let si = ligatureToSI[scalar] {
                    result.append(contentsOf: si.unicodeScalars)
                } else {
                    result.append(scalar)
                }
            }
            return String(result)
        case .siToLigature:
            return siToLigature(text)
        }
    }

    // 半角数字の直後(空白 0〜1 個を挟む)の単位だけを置き換える。後ろに英字が続くときは単位とみなさない
    private static func siToLigature(_ text: String) -> String {
        let scalars = Array(text.unicodeScalars)
        var result = String.UnicodeScalarView()
        var index = 0
        while index < scalars.count {
            if followsDigit(scalars, at: index), let match = longestMatch(scalars, at: index) {
                let end = index + match.si.count
                if end >= scalars.count || !isASCIILetter(scalars[end]) {
                    result.append(match.ligature)
                    index = end
                    continue
                }
            }
            result.append(scalars[index])
            index += 1
        }
        return String(result)
    }

    private static func followsDigit(_ scalars: [Unicode.Scalar], at index: Int) -> Bool {
        guard index > 0 else {
            return false
        }
        if isASCIIDigit(scalars[index - 1]) {
            return true
        }
        return index > 1 && scalars[index - 1] == " " && isASCIIDigit(scalars[index - 2])
    }

    private static func isASCIIDigit(_ scalar: Unicode.Scalar) -> Bool {
        (0x30...0x39).contains(scalar.value)
    }

    // かな・漢字が続く「10mmの」は単位とみなすため、英字は ASCII だけで判定する
    private static func isASCIILetter(_ scalar: Unicode.Scalar) -> Bool {
        (0x41...0x5A).contains(scalar.value) || (0x61...0x7A).contains(scalar.value)
    }

    private static func longestMatch(_ scalars: [Unicode.Scalar], at index: Int) -> (si: [Unicode.Scalar], ligature: Unicode.Scalar)? {
        siCandidates.first { candidate in
            index + candidate.si.count <= scalars.count
                && Array(scalars[index..<(index + candidate.si.count)]) == candidate.si
        }
    }
}
