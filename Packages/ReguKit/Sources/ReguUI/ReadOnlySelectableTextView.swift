import SwiftUI

// 結果欄。読み取り専用・選択可。selectAllToken が変わるたびに全体を選択する。
// window が無い間は選択できないので、未適用のトークンを Coordinator に残し、
// 画面の更新時と window に載った時点で再試行する
#if os(iOS)
import UIKit

public struct ReadOnlySelectableTextView: UIViewRepresentable {
    private let text: String
    private let selectAllToken: Int

    public init(text: String, selectAllToken: Int) {
        self.text = text
        self.selectAllToken = selectAllToken
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public func makeUIView(context: Context) -> UITextView {
        let textView = WindowObservingTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        // カードの上に載せるので地は透過。余白は入力欄（TextEditor）と同じ既定値に揃え、選択色は朱
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        textView.textContainer.lineFragmentPadding = 5
        textView.tintColor = Theme.accentPlatformColor
        let coordinator = context.coordinator
        textView.onMoveToWindow = { [weak textView] in
            guard let textView else {
                return
            }
            coordinator.applyPendingSelection(to: textView)
        }
        return textView
    }

    public func updateUIView(_ textView: UITextView, context: Context) {
        if textView.text != text {
            textView.text = text
        }
        context.coordinator.requestedToken = selectAllToken
        context.coordinator.applyPendingSelection(to: textView)
    }

    @MainActor
    public final class Coordinator {
        // 0 は「要求なし」（ConversionSession の初期値）
        var requestedToken = 0
        private var appliedToken = 0

        func applyPendingSelection(to textView: UITextView) {
            guard requestedToken != appliedToken, textView.window != nil else {
                return
            }
            guard textView.isFirstResponder || textView.becomeFirstResponder() else {
                return
            }
            textView.selectedRange = NSRange(location: 0, length: (textView.text as NSString).length)
            appliedToken = requestedToken
        }
    }
}

private final class WindowObservingTextView: UITextView {
    var onMoveToWindow: (() -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            onMoveToWindow?()
        }
    }
}

#elseif os(macOS)
import AppKit

public struct ReadOnlySelectableTextView: NSViewRepresentable {
    private let text: String
    private let selectAllToken: Int

    public init(text: String, selectAllToken: Int) {
        self.text = text
        self.selectAllToken = selectAllToken
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // scrollableTextView() はテキストコンテナ・リサイズ設定を揃えた NSTextView を documentView に持つ。
    // window への追加を知るため、外側に WindowObservingContainerView を 1 枚かぶせる
    public func makeNSView(context: Context) -> WindowObservingContainerView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        let container = WindowObservingContainerView(scrollView: scrollView)
        guard let textView = container.textView else {
            return container
        }
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.drawsBackground = false
        textView.font = NSFont.preferredFont(forTextStyle: .body)
        textView.textContainerInset = NSSize(width: 0, height: 8)
        textView.textContainer?.lineFragmentPadding = 5
        textView.selectedTextAttributes = [.backgroundColor: Theme.accentPlatformColor.withAlphaComponent(0.25)]
        let coordinator = context.coordinator
        container.onMoveToWindow = { [weak textView] in
            guard let textView else {
                return
            }
            coordinator.applyPendingSelection(to: textView)
        }
        return container
    }

    public func updateNSView(_ container: WindowObservingContainerView, context: Context) {
        guard let textView = container.textView else {
            return
        }
        if textView.string != text {
            textView.string = text
        }
        context.coordinator.requestedToken = selectAllToken
        context.coordinator.applyPendingSelection(to: textView)
    }

    @MainActor
    public final class Coordinator {
        // 0 は「要求なし」（ConversionSession の初期値）
        var requestedToken = 0
        private var appliedToken = 0

        func applyPendingSelection(to textView: NSTextView) {
            guard requestedToken != appliedToken, let window = textView.window else {
                return
            }
            guard window.makeFirstResponder(textView) else {
                return
            }
            textView.selectAll(nil)
            appliedToken = requestedToken
        }
    }
}

// macOS の結果欄の外枠。NSViewRepresentable の型として公開が要るが、中身は内部用
public final class WindowObservingContainerView: NSView {
    private let scrollView: NSScrollView
    var onMoveToWindow: (() -> Void)?

    init(scrollView: NSScrollView) {
        self.scrollView = scrollView
        super.init(frame: .zero)
        scrollView.frame = bounds
        scrollView.autoresizingMask = [.width, .height]
        addSubview(scrollView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    var textView: NSTextView? {
        scrollView.documentView as? NSTextView
    }

    override public func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            onMoveToWindow?()
        }
    }
}

#endif
