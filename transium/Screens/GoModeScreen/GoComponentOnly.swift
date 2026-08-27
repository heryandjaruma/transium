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
                    label: "END".transiumLocalized,
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

    /// Line name for the badge under the icon, truncated at the first "-" (e.g. "K5B-0" → "K5B") —
    /// the suffix after the dash is an internal variant/direction marker, not part of the line name.
    fileprivate var badgeCode: String? {
        switch self {
        case .walking: nil
        case .bus(let providerCode): providerCode.truncatedAtDash
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

            Image(systemName: mode.symbolName)
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundStyle(TransiumColor.primaryBlue)
                .frame(maxHeight: .infinity, alignment: .center)
                .padding(.bottom, mode.badgeCode != nil ? 10 : 0)

            if let badge = mode.badgeCode {
                Text(badge)
                    .font(TransiumFont.body(11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1.5)
                    .background(TransiumColor.darkBlue)
                    .clipShape(.capsule)
                    .offset(y: 4)
            }
        }
    }
}

// MARK: - Go Step Card
// Blue floating summary card for travel legs — walk or bus ride.

struct GoStepCard: View {
    struct Metric {
        let value: String
        let unit: String

        init(_ value: String, _ unit: String) {
            self.value = value
            self.unit = unit
        }

        init(value: String, unit: String) {
            self.value = value
            self.unit = unit
        }
    }

    let mode: GoTravelMode
    let verb: String
    let destination: String
    let metrics: [Metric]
    var caption: String? = nil
    var stopsRemaining: Int? = nil
    var cornerBadge: String? = nil

    init(mode: GoTravelMode, verb: String, destination: String, metricValue: String, metricUnit: String, caption: String? = nil) {
        self.mode = mode
        self.verb = verb
        self.destination = destination
        self.metrics = [Metric(metricValue, metricUnit)]
        self.caption = caption
    }

    init(
        mode: GoTravelMode,
        verb: String,
        destination: String,
        metrics: [Metric],
        caption: String? = nil,
        stopsRemaining: Int? = nil,
        cornerBadge: String? = nil
    ) {
        self.mode = mode
        self.verb = verb
        self.destination = destination
        self.metrics = metrics
        self.caption = caption
        self.stopsRemaining = stopsRemaining
        self.cornerBadge = cornerBadge
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 16) {
                GoStepIcon(mode: mode)

                VStack(alignment: .leading, spacing: 4) {
                    verbRow

                    Text(destination.transiumLocalized)
                        .font(TransiumFont.body(24, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    if cornerBadge == nil {
                        metricsRow
                    }

                    if let caption {
                        Text(caption.transiumLocalized)
                            .font(TransiumFont.body(11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(16)

            if let cornerBadge {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11, weight: .semibold))
                    Text(cornerBadge.transiumLocalized)
                        .font(TransiumFont.body(12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.2))
                .clipShape(.capsule)
                .padding(14)
            }
        }
        .frame(maxWidth: .infinity)
        .background(TransiumColor.primaryBlue)
        .clipShape(.rect(cornerRadius: 30))
    }

    @ViewBuilder
    private var verbRow: some View {
        if let stopsRemaining {
            HStack(spacing: 6) {
                Text("\(stopsRemaining)")
                    .font(TransiumFont.body(15, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.22))
                    .clipShape(.capsule)

                Text(stopsRemaining == 1 ? "Stop to".transiumLocalized : "Stops to".transiumLocalized)
                    .font(TransiumFont.body(17, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                
            }
        } else {
            Text(verb.transiumLocalized)
                .font(TransiumFont.body(17, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
        }
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

                Text(metric.unit.transiumLocalized)
                    .font(TransiumFont.body(15, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - Go Mission Card
// Blue-family floating card for a "mission" segment as the current step — instructions plus a
// white "I'm here" confirm button, matching GoStepCard/GoBusAppCard's shape and typography but
// in the yellow used everywhere else in Go Mode to mark a mission (vs. a travel leg).

struct GoMissionCard: View {
    let instructions: String
    /// Whether this mission's action is a photo capture (`JourneyAttemptStep.isPhotoCheckpoint`)
    /// — changes the confirm button's label/icon to "Take a Photo" (matching `manualActionCard`'s
    /// same distinction for unlocated steps), since tapping it does trigger the camera: it
    /// routes through the same `handleGeofenceEntered` a real geofence entry uses, which pops
    /// the camera for any not-yet-done photo checkpoint regardless of how it was triggered.
    let isCapture: Bool
    /// Whether the device is close enough to this mission's own location for the confirm
    /// button to make sense — see `JourneyAttemptStep.isWithinConfirmationRange`. The button is
    /// omitted (not just disabled) while out of range, same as the trip-details list used to do
    /// before this card took over as the only place a mission gets confirmed from.
    let isConfirmable: Bool
    let onConfirm: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 65 * 0.35, style: .continuous)
                    .fill(.white)
                    .frame(width: 65, height: 65)
                Image(systemName: "questionmark.app.fill")
                    .font(.system(size: 65 * 0.5, weight: .semibold))
                    .foregroundStyle(TransiumColor.primaryYellow)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Mission")
                    .font(TransiumFont.body(14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))

                Text(instructions.transiumLocalized)
                    .font(TransiumFont.body(19, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                if isConfirmable {
                    Button(action: onConfirm) {
                        HStack(spacing: 5) {
                            Image(systemName: isCapture ? "camera.fill" : "checkmark.circle")
                                .font(.system(size: 12, weight: .semibold))
                            Text(isCapture ? "Take a Photo".transiumLocalized : "I'm here".transiumLocalized)
                                .font(TransiumFont.body(13, weight: .semibold))
                        }
                        .foregroundStyle(TransiumColor.primaryYellow)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.white)
                        .clipShape(.capsule)
                    }
                    .buttonStyle(.transiumNoOpacity)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(TransiumColor.primaryYellow)
        .clipShape(.rect(cornerRadius: 30))
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
                    Text(promptText.transiumLocalized)
                        .font(TransiumFont.body(16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))

                    Text(appName.transiumLocalized)
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
                        Text(downloadLabel.transiumLocalized)
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

