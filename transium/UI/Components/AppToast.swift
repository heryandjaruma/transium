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

        withAnimation(.snappy(duration: 0.28, extraBounce: 0)) {
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

        withAnimation(.snappy(duration: 0.22, extraBounce: 0)) {
            toast = nil
        }
    }
}

struct AppToastOverlay: ViewModifier {
    @ObservedObject var toastCenter: AppToastCenter

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast = toastCenter.toast {
                    AppToastView(toast: toast) {
                        toastCenter.dismiss()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .scale(scale: 0.96, anchor: .top)))
                    .zIndex(100)
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

@MainActor
extension View {
    func appToastOverlay(_ toastCenter: AppToastCenter) -> some View {
        modifier(AppToastOverlay(toastCenter: toastCenter))
    }
}
