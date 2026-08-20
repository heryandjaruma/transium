//
//  GoComponents.swift
//  transium
//
//  Created by Abigail Metanoia Melody on 20/08/26.
//
//  Reusable building blocks for the "Go Mode" navigation screen.
//  Screens that assemble these (e.g. GoComponentMode) live in their own file.

import SwiftUI

// MARK: - Go Top Bar
// Back button (leading) + END / Locate / Mute stacked vertically (trailing),
// matching TransiumIconButton's shadow + glossy-highlight surface.

struct GoTopBar: View {
    let onBack: () -> Void
    let onEnd: () -> Void
    let onLocate: () -> Void
    let isMuted: Bool
    let onToggleMute: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            TransiumIconButton(
                icon: .system("arrow.left"),
                accessibilityLabel: "Back",
                size: 54
            ) {
                onBack()
            }

            Spacer()

            VStack(spacing: 12) {
                TransiumIconButton(
                    icon: .system("xmark"),
                    label: "END",
                    accessibilityLabel: "End trip",
                    backgroundColor: TransiumColor.lightRed,
                    foregroundColor: .white,
                    size: 54
                ) {
                    onEnd()
                }

                TransiumIconButton(
                    icon: .asset("focus"),
                    accessibilityLabel: "Recenter map",
                    foregroundColor: .black,
                    size: 54
                ) {
                    onLocate()
                }

                TransiumIconButton(
                    icon: .system(isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill"),
                    accessibilityLabel: isMuted ? "Unmute voice guidance" : "Mute voice guidance",
                    foregroundColor: .black,
                    size: 54
                ) {
                    onToggleMute()
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Go Travel Mode
// What kind of leg this step represents. Drives the leading icon in `GoStepCard`.

enum GoTravelMode {
    case walking
    case bus(providerCode: String)

    fileprivate var symbolName: String {
        switch self {
        case .walking: "figure.walk"
        case .bus: "bus.fill"
        }
    }

    fileprivate var badgeCode: String? {
        switch self {
        case .walking: nil
        case .bus(let providerCode): providerCode
        }
    }
}

// MARK: - Go Step Icon
private struct GoStepIcon: View {
    let mode: GoTravelMode
    var size: CGFloat = 65

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: size * 0.35, style: .continuous)
                .fill(.white)
                .frame(width: size, height: size)
                .overlay {
                    Image(systemName: mode.symbolName)
                        .font(.system(size: size * 0.60, weight: .semibold))
                        .foregroundStyle(TransiumColor.primaryBlue)
                }
//                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)

            if let badgeCode = mode.badgeCode {
                Text(badgeCode)
                    .font(TransiumFont.body(size * 0.20, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, size * 0.1)
                    .padding(.vertical, size * 0.04)
                    .background(TransiumColor.lightRed)
                    .clipShape(.rect(cornerRadius: size * 0.12))
                    .overlay {
                        RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
                            .strokeBorder(.white, lineWidth: 2)
                    }
                    .offset(x: 0.06, y: 15)
            }
        }
    }
}

// MARK: - Go Step Card
struct GoStepCard: View {
    struct Metric {
        let value: String
        let unit: String

        init(_ value: String, _ unit: String) {
            self.value = value
            self.unit = unit
        }
    }

    let mode: GoTravelMode
    let verb: String
    let destination: String
    let metrics: [Metric]

    /// Dipakai kalau cuma ada 1 metrik. Contoh: GoStepCard(..., metricValue: "5", metricUnit: "min")
    init(mode: GoTravelMode, verb: String, destination: String, metricValue: String, metricUnit: String) {
        self.mode = mode
        self.verb = verb
        self.destination = destination
        self.metrics = [Metric(metricValue, metricUnit)]
    }

    /// Dipakai kalau ada lebih dari 1 metrik (misal durasi + jarak).
    /// Contoh: GoStepCard(..., metrics: [.init("15", "min"), .init("1.2", "kilometer")])
    init(mode: GoTravelMode, verb: String, destination: String, metrics: [Metric]) {
        self.mode = mode
        self.verb = verb
        self.destination = destination
        self.metrics = metrics
    }

    var body: some View {
        HStack(spacing: 20) {
            GoStepIcon(mode: mode)

            VStack(alignment: .leading, spacing: 2) {
                Text(verb)
                    .font(TransiumFont.body(17, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))

                Text(destination)
                    .font(TransiumFont.body(24, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                metricsRow
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(TransiumColor.primaryBlue)
        .clipShape(.rect(cornerRadius: 30))
    }

    private var metricsRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            ForEach(Array(metrics.enumerated()), id: \.offset) { index, metric in
                if index > 0 {
                    Text("·")
                        .font(TransiumFont.body(21, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                }

                Text(metric.value)
                    .font(TransiumFont.body(28, weight: .bold))
                    .foregroundStyle(.white)

                Text(metric.unit)
                    .font(TransiumFont.body(15, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - Go Bus App Card
// "Check bus live location on Trans Metro Dewata App [Download TMD App]"

struct GoBusAppCard: View {
    let providerCode: String
    let promptText: String
    let appName: String
    let downloadLabel: String
    let onDownload: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            GoStepIcon(mode: .bus(providerCode: providerCode))

            VStack(alignment: .leading, spacing: 5) {
                VStack(alignment: .leading, spacing: 2){
                    Text(promptText)
                        .font(TransiumFont.body(16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))

                    Text(appName)
                        .font(TransiumFont.body(21, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Button(action: onDownload) {
                    HStack(spacing: 5) {
                        Image("logo_tmd")
                            .resizable()
                            .frame(width: 20, height: 20)
                        Text(downloadLabel)
                            .font(TransiumFont.body(13, weight: .semibold))
                        Image(systemName: "app.badge")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(TransiumColor.primaryBlue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.white)
                    .clipShape(.capsule)
                }
                .buttonStyle(.transiumNoOpacity)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(TransiumColor.primaryBlue)
        .clipShape(.rect(cornerRadius: 22))
    }
}

// MARK: - Go Bus Live Pill
// Small white floating card above the blue card:
// "Check Bus Live Location / Open Trans Metro Dewata  >"

struct GoBusLivePill: View {
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "bus.fill")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(TransiumColor.primaryBlue)
                    .frame(width: 40, height: 40)
                    .clipShape(.circle)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(TransiumFont.body(14, weight: .semibold))
                        .foregroundStyle(.black)

                    Text(subtitle)
                        .font(TransiumFont.body(11, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 10)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.white)
            .clipShape(.rect(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 3)
        }
        .buttonStyle(.transiumNoOpacity)
    }
}

