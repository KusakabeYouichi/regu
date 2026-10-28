import Foundation

public struct Preset: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var settings: ConversionSettings
    public let isBuiltIn: Bool

    public init(id: UUID = UUID(), name: String, settings: ConversionSettings, isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.settings = settings
        self.isBuiltIn = isBuiltIn
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, settings
    }

    // 保存するのはユーザープリセットだけなので、読み込んだものは常に isBuiltIn = false
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        settings = try container.decode(ConversionSettings.self, forKey: .settings)
        isBuiltIn = false
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(settings, forKey: .settings)
    }
}

// numbers「préréglages」シートの 3 つ（ruby héritée の hiragana のみ決定7 で変更）
extension Preset {
    public static let regularisation = Preset(
        id: UUID(uuidString: "6F1C2A10-0000-4000-8000-000000000001")!,
        name: "régularisation",
        settings: ConversionSettings(
            alphabet: .toASCII,
            accent: .toNFC,
            space: .ideographicToSpace,
            katakana: .toFullwidth,
            symbol: .toASCII,
            guillemets: .singleToDouble,
            unit: .ligatureToSI
        ),
        isBuiltIn: true
    )

    public static let adresseHeritee = Preset(
        id: UUID(uuidString: "6F1C2A10-0000-4000-8000-000000000002")!,
        name: "Adresse héritée",
        settings: ConversionSettings(
            alphabet: .toFullwidth,
            accent: .toNFC,
            space: .spaceToIdeographic,
            katakana: .toHalfwidth,
            symbol: .fromASCII
        ),
        isBuiltIn: true
    )

    public static let rubyHeritee = Preset(
        id: UUID(uuidString: "6F1C2A10-0000-4000-8000-000000000003")!,
        name: "ruby héritée",
        settings: ConversionSettings(
            katakana: .toHalfwidth,
            hiragana: .hiraganaToKatakana
        ),
        isBuiltIn: true
    )

    public static let builtIns: [Preset] = [regularisation, adresseHeritee, rubyHeritee]
}
