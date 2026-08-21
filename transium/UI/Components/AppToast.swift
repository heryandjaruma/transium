//
//  AppToast.swift
//  transium
//

import Combine
import SwiftUI

enum AppToastKind {
    case success
    case warning
    case error

    var iconName: String {
        switch self {
        case .success:
            "checkmark.circle.fill"
        case .warning:
            "exclamationmark.triangle.fill"
        case .error:
            "xmark.octagon.fill"
        }
    }

    var tint: Color {
        switch self {
        case .success:
            Color(red: 0.12, green: 0.55, blue: 0.32)
        case .warning:
            Color(red: 0.88, green: 0.54, blue: 0.08)
        case .error:
            Color(red: 0.82, green: 0.16, blue: 0.18)
        }
    }
}

struct AppToast: Identifiable, Equatable {
    let id = UUID()
    let kind: AppToastKind
    let title: String
    let message: String
}

@MainActor
final class AppToastCenter: ObservableObject {
    static let shared = AppToastCenter()

    @Published private(set) var toast: AppToast?
    private var dismissalTask: Task<Void, Never>?

    private init() {}

    func show(_ toast: AppToast, duration: Duration = .seconds(3)) {
        dismissalTask?.cancel()

        withAnimation(.easeOut(duration: 0.3)) {
            self.toast = toast
        }

        dismissalTask = Task { [weak self] in
            try? await Task.sleep(for: duration)

            await MainActor.run {
                self?.dismiss()
            }
        }
    }

    func showSuccess(title: String, message: String) {
        show(AppToast(kind: .success, title: title, message: message))
    }

    func showWarning(title: String, message: String) {
        show(AppToast(kind: .warning, title: title, message: message))
    }

    func showError(title: String, message: String) {
        show(AppToast(kind: .error, title: title, message: message))
    }

    func dismiss() {
        dismissalTask?.cancel()
        dismissalTask = nil

        withAnimation(.easeIn(duration: 0.22)) {
            toast = nil
        }
    }
}

struct AppToastOverlay: ViewModifier {
    @ObservedObject var toastCenter: AppToastCenter

    func body(content: Content) -> some View {
        content
            .background(ToastWindowSceneAttachment())
            .overlay(alignment: .top) {
                // Fallback overlay for environments without active window scene (e.g. previews)
                if ToastWindowController.shared.window == nil, let toast = toastCenter.toast {
                    GeometryReader { proxy in
                        AppToastView(toast: toast) {
                            toastCenter.dismiss()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, max(proxy.safeAreaInsets.top, 56) + 12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .transition(.toastSlide)
                        .zIndex(100)
                    }
                    .ignoresSafeArea()
                    .allowsHitTesting(true)
                }
            }
    }
}

// MARK: - Global Window-Level Toast Presenter (Above All Sheets)

@MainActor
final class ToastWindowController {
    static let shared = ToastWindowController()

    private(set) var window: PassthroughToastWindow?

    func setupIfNeeded(scene: UIWindowScene) {
        guard window == nil else { return }

        let toastWindow = PassthroughToastWindow(windowScene: scene)
        toastWindow.windowLevel = .statusBar + 100
        toastWindow.backgroundColor = .clear

        let hostingController = ToastHostingController(rootView: GlobalToastOverlayView())
        hostingController.view.backgroundColor = .clear

        toastWindow.rootViewController = hostingController
        toastWindow.isHidden = false
        toastWindow.isUserInteractionEnabled = true
        self.window = toastWindow
    }
}

final class PassthroughToastWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let view = super.hitTest(point, with: event) else { return nil }
        // Pass touches through if the user tapped on the empty background area
        if view === rootViewController?.view {
            return nil
        }
        return view
    }
}

final class ToastHostingController<Content: View>: UIHostingController<Content> {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }
}

struct GlobalToastOverlayView: View {
    @ObservedObject private var toastCenter = AppToastCenter.shared

    var body: some View {
        ZStack(alignment: .top) {
            if let toast = toastCenter.toast {
                GeometryReader { proxy in
                    AppToastView(toast: toast) {
                        toastCenter.dismiss()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, max(proxy.safeAreaInsets.top, 50) + 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .transition(.toastSlide)
                }
                .ignoresSafeArea()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
    }
}

private struct ToastWindowSceneAttachment: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = ToastAnchorView()
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    final class ToastAnchorView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let scene = window?.windowScene {
                ToastWindowController.shared.setupIfNeeded(scene: scene)
            }
        }
    }
}

private struct AppToastView: View {
    let toast: AppToast
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: toast.kind.iconName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(toast.kind.tint)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(toast.title)
                    .font(TransiumFont.body(15, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(toast.message)
                    .font(TransiumFont.body(13))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss notification")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(.ultraThinMaterial)
        .background(.white.opacity(0.88))
        .clipShape(.rect(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.72), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 22, y: 10)
        .accessibilityElement(children: .combine)
    }
}

private extension AnyTransition {
    static var toastSlide: AnyTransition {
        .modifier(
            active: AppToastSlideModifier(yOffset: -112),
            identity: AppToastSlideModifier(yOffset: 0)
        )
    }
}

private struct AppToastSlideModifier: ViewModifier {
    let yOffset: CGFloat

    func body(content: Content) -> some View {
        content.offset(y: yOffset)
    }
}

@MainActor
extension View {
    func appToastOverlay(_ toastCenter: AppToastCenter) -> some View {
        modifier(AppToastOverlay(toastCenter: toastCenter))
    }
}
