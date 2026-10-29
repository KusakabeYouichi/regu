import Foundation

// システムのクリップボード(UIPasteboard / NSPasteboard)を差し替えられるようにする
@MainActor
public protocol Pasteboard: AnyObject {
    // 内容が変わるたびに増える値
    var changeCount: Int { get }
    // 読み取らずに文字列の有無だけを返す(iOS ではペースト許可を求めない)
    var hasStrings: Bool { get }
    // iOS では読み取り時にペースト許可を求めることがある。拒否されたら nil
    var string: String? { get }
    func setString(_ string: String)
}
