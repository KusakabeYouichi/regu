import Foundation
import Observation

// 前面化の種類。自動変換は launch と background からの復帰だけで行う
public enum ActivationSource: Sendable {
    case launch
    case background
    // コントロールセンター・ペースト許可アラート等から戻ったとき
    case inactive
}

// メイン画面の状態。クリップボードの読み込み・変換・書き戻しを受け持つ
@Observable
@MainActor
public final class ConversionSession {
    enum Key {
        static let lastWrittenChangeCount = "regu.lastWrittenChangeCount"
        static let lastAttemptedChangeCount = "regu.lastAttemptedChangeCount"
        static let lastWrittenDigest = "regu.lastWrittenDigest"
    }

    public var input = ""
    public private(set) var output = ""
    // 結果欄の全選択要求。値が変わるたびに画面が全選択する
    public private(set) var selectAllToken = 0

    public let store: PresetStore

    @ObservationIgnored private let pasteboard: any Pasteboard
    @ObservationIgnored private let defaults: UserDefaults
    // 前面にいる間に自分が書き込んだか。背面へ移るときに changeCount を記録し直す
    @ObservationIgnored private var hasUnconfirmedWrite = false

    public init(pasteboard: any Pasteboard, defaults: UserDefaults) {
        self.pasteboard = pasteboard
        self.defaults = defaults
        store = PresetStore(defaults: defaults)
    }

    public var selectedPresetID: UUID {
        store.selectedPresetID
    }

    // 保存だけ行い、再変換はしない
    public func select(_ presetID: UUID) {
        store.select(presetID)
    }

    // 自分が書き込んだ内容と、読み込みを試みた内容（拒否された場合を含む）は再び読まない。
    // 記録は UserDefaults に残し、再起動後も自分の出力を再変換しない。
    // 書き込み直後の changeCount は古い値のことがある（iOS で確認）ため、中身の指紋でも自分の出力かを判定する。
    // 指紋には変換設定も含め、設定を変えた後は同じ文字列でも変換する
    public func activate(from source: ActivationSource) {
        guard source != .inactive else {
            return
        }
        let changeCount = pasteboard.changeCount
        guard changeCount != storedCount(Key.lastWrittenChangeCount),
                changeCount != storedCount(Key.lastAttemptedChangeCount) else {
            return
        }
        defaults.set(changeCount, forKey: Key.lastAttemptedChangeCount)
        guard pasteboard.hasStrings, let string = pasteboard.string, !string.isEmpty else {
            return
        }
        guard Self.digest(of: string, settings: store.selectedPreset.settings)
                != defaults.string(forKey: Key.lastWrittenDigest) else {
            defaults.set(changeCount, forKey: Key.lastWrittenChangeCount)
            return
        }
        input = string
        convertAndCopy()
    }

    // 書き込み直後の changeCount は古いことがあるため、背面へ移るときに読み直して記録する。
    // 前面にいる間は他アプリがクリップボードを変えられないので、この時点の値は自分の書き込みのもの
    public func enterBackground() {
        guard hasUnconfirmedWrite else {
            return
        }
        defaults.set(pasteboard.changeCount, forKey: Key.lastWrittenChangeCount)
        hasUnconfirmedWrite = false
    }

    // 空白だけの入力では何もしない（クリップボードも書かない）
    public func convertTapped() {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        convertAndCopy()
    }

    private func convertAndCopy() {
        output = Converter.convert(input, settings: store.selectedPreset.settings)
        selectAllToken += 1
        pasteboard.setString(output)
        defaults.set(pasteboard.changeCount, forKey: Key.lastWrittenChangeCount)
        hasUnconfirmedWrite = true
        defaults.set(Self.digest(of: output, settings: store.selectedPreset.settings), forKey: Key.lastWrittenDigest)
    }

    // 文字列そのものは保存せず、設定と文字列を合わせた FNV-1a 64 の指紋だけを残す
    private static func digest(of text: String, settings: ConversionSettings) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let settingsBytes = (try? encoder.encode(settings)) ?? Data()
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in settingsBytes + [0] + Data(text.utf8) {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return String(hash, radix: 16)
    }

    private func storedCount(_ key: String) -> Int? {
        defaults.object(forKey: key) as? Int
    }
}
