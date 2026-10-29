import ReguCore
import ReguUI
import SwiftUI

@main
struct ReguApp: App {
    @Environment(\.scenePhase) private var scenePhase
    // 複数ウィンドウは無効（UIApplicationSupportsMultipleScenes = NO）なので、状態は 1 つだけ持つ
    @State private var session: ConversionSession
    @State private var hasActivated = false
    @State private var wasInBackground = false

    init() {
        #if DEBUG
        Self.resetDefaultsForUITestIfRequested()
        #endif
        _session = State(initialValue: ConversionSession(pasteboard: SystemPasteboard(), defaults: .standard))
    }

    var body: some Scene {
        WindowGroup {
            MainView(session: session)
        }
        .onChange(of: scenePhase, initial: true) { _, newPhase in
            handle(newPhase)
        }
    }

    // background → active は必ず inactive を経由するので、直前の値ではなく background を通ったかで見分ける
    private func handle(_ phase: ScenePhase) {
        switch phase {
        case .background:
            wasInBackground = true
            session.enterBackground()
        case .active:
            let source: ActivationSource
            if !hasActivated {
                source = .launch
            } else if wasInBackground {
                source = .background
            } else {
                source = .inactive
            }
            hasActivated = true
            wasInBackground = false
            session.activate(from: source)
        default:
            break
        }
    }

    #if DEBUG
    // UI テスト（reguUITests）用。起動引数 -reguUITestReset があれば、セッションを作る前にアプリの UserDefaults を消す
    private static func resetDefaultsForUITestIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-reguUITestReset"),
                let domain = Bundle.main.bundleIdentifier else {
            return
        }
        UserDefaults.standard.removePersistentDomain(forName: domain)
    }
    #endif
}
