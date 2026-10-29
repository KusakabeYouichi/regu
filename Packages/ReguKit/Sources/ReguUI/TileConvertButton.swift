import SwiftUI

// 変換ボタン。白い陶器のタイルに「れ＋朱の点」の画像を載せ、直下に小さく「変換」（高さが足りないときは省く）。
// タイルの面・角丸・影は ここで描き、画像は透過の筆文字だけを持つ。
// VoiceOver には 1 要素「変換」として見せる。触覚はこのボタンの押下だけ（自動変換では震えない）
struct TileConvertButton: View {
    static let regularTileSize: CGFloat = 60
    // 横長でキーボード表示中など、高さが足りないとき。押しやすさの下限 44pt を保つ
    static let compactTileSize: CGFloat = 44

    let tileSize: CGFloat
    let showsCaption: Bool
    let action: () -> Void
    @State private var pressCount = 0

    var body: some View {
        Button {
            pressCount += 1
            action()
        } label: {
            VStack(spacing: 6) {
                ConvertTile(size: tileSize)
                if showsCaption {
                    Text("変換")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(TilePressStyle())
        .sensoryFeedback(.impact(weight: .light), trigger: pressCount)
        .accessibilityLabel("変換")
    }
}

// タイル単体。ライトは柔らかい影、ダークは面を少し落として影の代わりに細い縁取り
private struct ConvertTile: View {
    let size: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
        glyph
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .padding(size * 0.14)
            .frame(width: size, height: size)
            .background {
                shape
                    .fill(Theme.tileFace)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.16), radius: 6, y: 3)
            }
            .overlay {
                if colorScheme == .dark {
                    shape.strokeBorder(.white.opacity(0.35), lineWidth: 0.5)
                }
            }
            .accessibilityHidden(true)
    }
}

private extension ConvertTile {
    // 画像はパッケージ資源の素の PNG。Image(_:bundle:) はアセットカタログしか探さないので、プラットフォームの画像として読む
    // 資源が無いとき（同梱漏れ）は、リリースでは筆文字なしの白いタイルのまま押せるようにし、デバッグでは止めて気づかせる
    var glyph: Image {
        #if os(iOS)
        guard let image = UIImage(named: "ConvertTile", in: .module, with: nil) else {
            assertionFailure("ConvertTile resource missing")
            return Image(uiImage: UIImage())
        }
        return Image(uiImage: image)
        #elseif os(macOS)
        guard let image = Bundle.module.image(forResource: "ConvertTile") else {
            assertionFailure("ConvertTile resource missing")
            return Image(nsImage: NSImage())
        }
        return Image(nsImage: image)
        #endif
    }
}

// 押下で少し縮む。Reduce Motion のときは縮めない
private struct TilePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PressScaleBody(label: configuration.label, isPressed: configuration.isPressed)
    }
}

private struct PressScaleBody<Label: View>: View {
    let label: Label
    let isPressed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        label
            .scaleEffect(isPressed && !reduceMotion ? 0.94 : 1)
            .animation(reduceMotion ? nil : .spring(duration: 0.2), value: isPressed)
    }
}
