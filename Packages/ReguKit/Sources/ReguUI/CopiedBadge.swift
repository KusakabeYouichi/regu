import SwiftUI

// 「✓ コピーしました」の小さなカプセル。表示・消去の時間は MainView が受け持つ
struct CopiedBadge: View {
    var body: some View {
        Label("コピーしました", systemImage: "checkmark")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.accent)
            .lineLimit(1)
            // 結果カードの角に重ねる小さな表示なので、文字の拡大は大きめの通常サイズまでに留める
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                Capsule()
                    .fill(Theme.card)
                    .overlay {
                        Capsule().strokeBorder(Theme.accent.opacity(0.5), lineWidth: 1)
                    }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("コピーしました")
            .accessibilityIdentifier("copiedBadge")
    }
}
