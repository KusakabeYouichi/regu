import Foundation
@testable import ReguCore

// Swift の String の == は正規等価で比べる（é と e+U+0301 が等しい）ため、変換結果はスカラー列で比べる
func scalars(_ text: String) -> [Unicode.Scalar] {
    Array(text.unicodeScalars)
}

func converted(_ text: String, _ settings: ConversionSettings) -> [Unicode.Scalar] {
    scalars(Converter.convert(text, settings: settings))
}

// テストごとに空の UserDefaults を用意し、終わったら消す
final class TestDefaults {
    let suiteName = "regu.tests.\(UUID().uuidString)"
    let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }
}

// クリップボードの偽物。書き込みと他アプリからのコピーで changeCount が増える
@MainActor
final class FakePasteboard: Pasteboard {
    private var count = 0
    private var reportsStaleCountOnce = false
    private(set) var content: String?
    // ペースト許可を拒否された状態（hasStrings は true のまま string が nil）
    var deniesRead = false
    // 自分の書き込み直後の 1 回だけ古い changeCount を返す（iOS で観測した挙動）
    var lagsAfterOwnWrite = false

    var changeCount: Int {
        if reportsStaleCountOnce {
            reportsStaleCountOnce = false
            return count - 1
        }
        return count
    }

    init(content: String? = nil) {
        if let content {
            copyFromOtherApp(content)
        }
    }

    var hasStrings: Bool {
        content != nil
    }

    var string: String? {
        deniesRead ? nil : content
    }

    func setString(_ string: String) {
        content = string
        count += 1
        reportsStaleCountOnce = lagsAfterOwnWrite
    }

    func copyFromOtherApp(_ string: String) {
        content = string
        count += 1
    }
}
