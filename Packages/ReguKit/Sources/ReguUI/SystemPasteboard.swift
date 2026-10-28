import ReguCore

#if os(iOS)
import UIKit

// UIPasteboard.general を ReguCore の Pasteboard として使う
@MainActor
public final class SystemPasteboard: ReguCore.Pasteboard {
    private let pasteboard = UIPasteboard.general

    public init() {}

    public var changeCount: Int {
        pasteboard.changeCount
    }

    public var hasStrings: Bool {
        pasteboard.hasStrings
    }

    public var string: String? {
        pasteboard.string
    }

    public func setString(_ string: String) {
        pasteboard.string = string
    }
}

#elseif os(macOS)
import AppKit

// NSPasteboard.general を ReguCore の Pasteboard として使う
@MainActor
public final class SystemPasteboard: ReguCore.Pasteboard {
    private let pasteboard = NSPasteboard.general

    public init() {}

    public var changeCount: Int {
        pasteboard.changeCount
    }

    public var hasStrings: Bool {
        pasteboard.availableType(from: [.string]) != nil
    }

    public var string: String? {
        pasteboard.string(forType: .string)
    }

    public func setString(_ string: String) {
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }
}

#endif
