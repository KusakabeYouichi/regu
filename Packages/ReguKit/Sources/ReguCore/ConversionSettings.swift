import Foundation

// 各設定項目の選択肢。保存値（rawValue）が未知なら preserve として読む
public protocol SettingOption: CaseIterable, Codable, Hashable, Sendable, RawRepresentable where RawValue == String {
    static var preserve: Self { get }
    // numbers「設定項目」シートの表記
    var label: String { get }
}

extension SettingOption {
    static func decodeLossy(from decoder: any Decoder) -> Self {
        guard let container = try? decoder.singleValueContainer(),
              let raw = try? container.decode(String.self) else {
            return .preserve
        }
        return Self(rawValue: raw) ?? .preserve
    }
}

public enum AlphabetOption: String, SettingOption {
    case preserve
    case toASCII
    case toFullwidth

    public init(from decoder: any Decoder) throws {
        self = Self.decodeLossy(from: decoder)
    }

    public var label: String {
        switch self {
        case .preserve: "preserve"
        case .toASCII: "JIS X 0208 → ASCII"
        case .toFullwidth: "ASCII → JIS X 0208"
        }
    }
}

public enum AccentOption: String, SettingOption {
    case preserve
    case toNFD
    case toNFC

    public init(from decoder: any Decoder) throws {
        self = Self.decodeLossy(from: decoder)
    }

    public var label: String {
        switch self {
        case .preserve: "preserve"
        case .toNFD: "NFC → NFD"
        case .toNFC: "NFD → NFC"
        }
    }
}

public enum SpaceOption: String, SettingOption {
    case preserve
    case ideographicToSpace
    case ideographicToTwoSpaces
    case spaceToIdeographic
    case twoSpacesToIdeographic

    public init(from decoder: any Decoder) throws {
        self = Self.decodeLossy(from: decoder)
    }

    public var label: String {
        switch self {
        case .preserve: "preserve"
        case .ideographicToSpace: "U+3000 → U+0020"
        case .ideographicToTwoSpaces: "U+3000 → U+0020 × 2"
        case .spaceToIdeographic: "U+0020 → U+3000"
        case .twoSpacesToIdeographic: "U+0020 × 2 → U+3000"
        }
    }
}

public enum KatakanaOption: String, SettingOption {
    case preserve
    case toFullwidth
    case toHalfwidth

    public init(from decoder: any Decoder) throws {
        self = Self.decodeLossy(from: decoder)
    }

    public var label: String {
        switch self {
        case .preserve: "preserve"
        case .toFullwidth: "JIS X 0201 → JIS X 0208"
        case .toHalfwidth: "JIS X 0208 → JIS X 0201"
        }
    }
}

public enum HiraganaOption: String, SettingOption {
    case preserve
    case katakanaToHiragana
    case hiraganaToKatakana
    case swap

    public init(from decoder: any Decoder) throws {
        self = Self.decodeLossy(from: decoder)
    }

    public var label: String {
        switch self {
        case .preserve: "preserve"
        case .katakanaToHiragana: "カタカナ→ひらがな"
        case .hiraganaToKatakana: "ひらがな→カタカナ"
        case .swap: "ひらがな↔カタカナ"
        }
    }
}

public enum SymbolOption: String, SettingOption {
    case preserve
    case toASCII
    case toCP932Lower
    case fromASCII
    case fromCP932Lower

    public init(from decoder: any Decoder) throws {
        self = Self.decodeLossy(from: decoder)
    }

    public var label: String {
        switch self {
        case .preserve: "preserve"
        case .toASCII: "JIS X 0208 → ASCII"
        case .toCP932Lower: "JIS X 0208 → CP932(〜0x7f)"
        case .fromASCII: "ASCII → JIS X 0208"
        case .fromCP932Lower: "CP932(〜0x7f) → JIS X 0208"
        }
    }
}

public enum GuillemetsOption: String, SettingOption {
    case preserve
    case singleToDouble
    case doubleToSingle

    public init(from decoder: any Decoder) throws {
        self = Self.decodeLossy(from: decoder)
    }

    public var label: String {
        switch self {
        case .preserve: "preserve"
        case .singleToDouble: "「」→『』"
        case .doubleToSingle: "『』→「」"
        }
    }
}

public enum UnitOption: String, SettingOption {
    case preserve
    case ligatureToSI
    case siToLigature

    public init(from decoder: any Decoder) throws {
        self = Self.decodeLossy(from: decoder)
    }

    public var label: String {
        switch self {
        case .preserve: "preserve"
        case .ligatureToSI: "ligature → SI"
        case .siToLigature: "SI → ligature"
        }
    }
}

public enum HTMLEntityOption: String, SettingOption {
    case preserve
    case decode
    case encode

    public init(from decoder: any Decoder) throws {
        self = Self.decodeLossy(from: decoder)
    }

    public var label: String {
        switch self {
        case .preserve: "preserve"
        case .decode: "HTML Entity → Code Point"
        case .encode: "Code Point → HTML Entity"
        }
    }
}

public enum URLEntityOption: String, SettingOption {
    case preserve
    case decode
    case encode

    public init(from decoder: any Decoder) throws {
        self = Self.decodeLossy(from: decoder)
    }

    public var label: String {
        switch self {
        case .preserve: "preserve"
        case .decode: "URL Entity → Code Point"
        case .encode: "Code Point → URL Entity"
        }
    }
}

public struct ConversionSettings: Codable, Hashable, Sendable {
    public var alphabet: AlphabetOption
    public var accent: AccentOption
    public var space: SpaceOption
    public var katakana: KatakanaOption
    public var hiragana: HiraganaOption
    public var symbol: SymbolOption
    public var guillemets: GuillemetsOption
    public var unit: UnitOption
    public var htmlEntity: HTMLEntityOption
    public var urlEntity: URLEntityOption

    public init(
        alphabet: AlphabetOption = .preserve,
        accent: AccentOption = .preserve,
        space: SpaceOption = .preserve,
        katakana: KatakanaOption = .preserve,
        hiragana: HiraganaOption = .preserve,
        symbol: SymbolOption = .preserve,
        guillemets: GuillemetsOption = .preserve,
        unit: UnitOption = .preserve,
        htmlEntity: HTMLEntityOption = .preserve,
        urlEntity: URLEntityOption = .preserve
    ) {
        self.alphabet = alphabet
        self.accent = accent
        self.space = space
        self.katakana = katakana
        self.hiragana = hiragana
        self.symbol = symbol
        self.guillemets = guillemets
        self.unit = unit
        self.htmlEntity = htmlEntity
        self.urlEntity = urlEntity
    }

    private enum CodingKeys: String, CodingKey {
        case alphabet, accent, space, katakana, hiragana, symbol, guillemets, unit, htmlEntity, urlEntity
    }

    // 欠けた項目は preserve として読む
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        alphabet = try container.decodeIfPresent(AlphabetOption.self, forKey: .alphabet) ?? .preserve
        accent = try container.decodeIfPresent(AccentOption.self, forKey: .accent) ?? .preserve
        space = try container.decodeIfPresent(SpaceOption.self, forKey: .space) ?? .preserve
        katakana = try container.decodeIfPresent(KatakanaOption.self, forKey: .katakana) ?? .preserve
        hiragana = try container.decodeIfPresent(HiraganaOption.self, forKey: .hiragana) ?? .preserve
        symbol = try container.decodeIfPresent(SymbolOption.self, forKey: .symbol) ?? .preserve
        guillemets = try container.decodeIfPresent(GuillemetsOption.self, forKey: .guillemets) ?? .preserve
        unit = try container.decodeIfPresent(UnitOption.self, forKey: .unit) ?? .preserve
        htmlEntity = try container.decodeIfPresent(HTMLEntityOption.self, forKey: .htmlEntity) ?? .preserve
        urlEntity = try container.decodeIfPresent(URLEntityOption.self, forKey: .urlEntity) ?? .preserve
    }
}

// 編集画面の Section（numbers の group 列）
public enum SettingGroup: String, CaseIterable, Identifiable, Sendable {
    case latin
    case espace
    case kanas
    case symbole
    case entity

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .latin: "latin"
        case .espace: "espace"
        case .kanas: "les kanas"
        case .symbole: "symbole"
        case .entity: "Entity"
        }
    }

    public var fields: [SettingField] {
        SettingField.allCases.filter { $0.group == self }
    }
}

// 選択肢 1 つ分の表示用の値
public struct SettingChoice: Hashable, Identifiable, Sendable {
    public let rawValue: String
    public let label: String

    public var id: String { rawValue }
}

// 編集画面の 1 行（numbers の設定名列）
public enum SettingField: String, CaseIterable, Identifiable, Sendable {
    case alphabet
    case accent
    case space
    case katakana
    case hiragana
    case symbol
    case guillemets
    case unit
    case htmlEntity
    case urlEntity

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .alphabet: "alphabet"
        case .accent: "lettre accentuée"
        case .space: "space"
        case .katakana: "les katakana"
        case .hiragana: "les hiraganas"
        case .symbol: "symbole"
        case .guillemets: "guillemets"
        case .unit: "unit"
        case .htmlEntity: "HTML Entity"
        case .urlEntity: "URL entity"
        }
    }

    public var group: SettingGroup {
        switch self {
        case .alphabet, .accent: .latin
        case .space: .espace
        case .katakana, .hiragana: .kanas
        case .symbol, .guillemets, .unit: .symbole
        case .htmlEntity, .urlEntity: .entity
        }
    }

    public var choices: [SettingChoice] {
        switch self {
        case .alphabet: Self.choices(of: AlphabetOption.self)
        case .accent: Self.choices(of: AccentOption.self)
        case .space: Self.choices(of: SpaceOption.self)
        case .katakana: Self.choices(of: KatakanaOption.self)
        case .hiragana: Self.choices(of: HiraganaOption.self)
        case .symbol: Self.choices(of: SymbolOption.self)
        case .guillemets: Self.choices(of: GuillemetsOption.self)
        case .unit: Self.choices(of: UnitOption.self)
        case .htmlEntity: Self.choices(of: HTMLEntityOption.self)
        case .urlEntity: Self.choices(of: URLEntityOption.self)
        }
    }

    private static func choices<Option: SettingOption>(of type: Option.Type) -> [SettingChoice] {
        Option.allCases.map { SettingChoice(rawValue: $0.rawValue, label: $0.label) }
    }
}

extension ConversionSettings {
    // 編集画面の Picker から項目を文字列で読み書きする
    public func rawValue(for field: SettingField) -> String {
        switch field {
        case .alphabet: alphabet.rawValue
        case .accent: accent.rawValue
        case .space: space.rawValue
        case .katakana: katakana.rawValue
        case .hiragana: hiragana.rawValue
        case .symbol: symbol.rawValue
        case .guillemets: guillemets.rawValue
        case .unit: unit.rawValue
        case .htmlEntity: htmlEntity.rawValue
        case .urlEntity: urlEntity.rawValue
        }
    }

    // 未知の値は無視する（選択肢は SettingField.choices からしか来ない）
    public mutating func setRawValue(_ rawValue: String, for field: SettingField) {
        switch field {
        case .alphabet: alphabet = AlphabetOption(rawValue: rawValue) ?? alphabet
        case .accent: accent = AccentOption(rawValue: rawValue) ?? accent
        case .space: space = SpaceOption(rawValue: rawValue) ?? space
        case .katakana: katakana = KatakanaOption(rawValue: rawValue) ?? katakana
        case .hiragana: hiragana = HiraganaOption(rawValue: rawValue) ?? hiragana
        case .symbol: symbol = SymbolOption(rawValue: rawValue) ?? symbol
        case .guillemets: guillemets = GuillemetsOption(rawValue: rawValue) ?? guillemets
        case .unit: unit = UnitOption(rawValue: rawValue) ?? unit
        case .htmlEntity: htmlEntity = HTMLEntityOption(rawValue: rawValue) ?? htmlEntity
        case .urlEntity: urlEntity = URLEntityOption(rawValue: rawValue) ?? urlEntity
        }
    }
}
