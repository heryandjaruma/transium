//
//  TransiumTicketComponents.swift
//  transium
//

import SwiftUI

struct TransiumStampVariant: Equatable {
    let frameColor: Color
    let paperColor: Color
    let shadowColor: Color
    let imageBackground: Color

    static let classic = TransiumStampVariant(
        frameColor: .white,
        paperColor: Color(red: 0.98, green: 0.98, blue: 0.95),
        shadowColor: .black.opacity(0.18),
        imageBackground: TransiumColor.primaryYellow
    )

    static let blue = TransiumStampVariant(
        frameColor: Color(red: 0.86, green: 0.93, blue: 1.0),
        paperColor: Color(red: 0.95, green: 0.98, blue: 1.0),
        shadowColor: TransiumColor.ticketInk.opacity(0.18),
        imageBackground: Color(red: 0.74, green: 0.88, blue: 1.0)
    )

    static let warm = TransiumStampVariant(
        frameColor: Color(red: 1.0, green: 0.94, blue: 0.81),
        paperColor: Color(red: 1.0, green: 0.98, blue: 0.91),
        shadowColor: Color(red: 0.55, green: 0.32, blue: 0.08).opacity(0.2),
        imageBackground: TransiumColor.primaryYellow
    )

    static let green = TransiumStampVariant(
        frameColor: Color(red: 0.84, green: 0.95, blue: 0.88),
        paperColor: Color(red: 0.93, green: 0.98, blue: 0.95),
        shadowColor: Color(red: 0.12, green: 0.45, blue: 0.22).opacity(0.18),
        imageBackground: Color(red: 0.75, green: 0.92, blue: 0.82)
    )
}

struct TransiumBadgeVariant: Equatable {
    let backgroundColor: Color
    let foregroundColor: Color
    let borderColor: Color
    let shadowColor: Color
    let usesPaperShape: Bool

    static let paper = TransiumBadgeVariant(
        backgroundColor: .white,
        foregroundColor: TransiumColor.ticketInk,
        borderColor: .black.opacity(0.08),
        shadowColor: .black.opacity(0.14),
        usesPaperShape: true
    )

    static let blue = TransiumBadgeVariant(
        backgroundColor: Color(red: 0.84, green: 0.92, blue: 1.0),
        foregroundColor: TransiumColor.ticketBlue,
        borderColor: .white.opacity(0.4),
        shadowColor: TransiumColor.ticketInk.opacity(0.12),
        usesPaperShape: false
    )

    static let dark = TransiumBadgeVariant(
        backgroundColor: TransiumColor.ticketInk,
        foregroundColor: .white,
        borderColor: .white.opacity(0.12),
        shadowColor: .black.opacity(0.2),
        usesPaperShape: false
    )
}

struct TransiumTicketVariant: Equatable {
    let backgroundColor: Color
    let foregroundColor: Color
    let secondaryColor: Color
    let dividerColor: Color
    let notchColor: Color

    static let blue = TransiumTicketVariant(
        backgroundColor: TransiumColor.ticketBlue,
        foregroundColor: .white,
        secondaryColor: .white.opacity(0.82),
        dividerColor: TransiumColor.ticketInk.opacity(0.18),
        notchColor: TransiumColor.ticketInk
    )

    static let mint = TransiumTicketVariant(
        backgroundColor: TransiumColor.ticketMint,
        foregroundColor: TransiumColor.ticketInk,
        secondaryColor: TransiumColor.ticketInk.opacity(0.68),
        dividerColor: TransiumColor.ticketInk.opacity(0.16),
        notchColor: TransiumColor.ticketInk
    )

    static let coral = TransiumTicketVariant(
        backgroundColor: TransiumColor.ticketCoral,
        foregroundColor: .white,
        secondaryColor: .white.opacity(0.84),
        dividerColor: TransiumColor.ticketInk.opacity(0.16),
        notchColor: TransiumColor.ticketInk
    )
}

struct TransiumStampCard<Center: View>: View {
    let size: CGFloat
    let tilt: Angle
    let variant: TransiumStampVariant
    @ViewBuilder let center: () -> Center

    init(
        size: CGFloat = 104,
        tilt: Angle = .degrees(-4),
        variant: TransiumStampVariant = .classic,
        @ViewBuilder center: @escaping () -> Center
    ) {
        self.size = size
        self.tilt = tilt
        self.variant = variant
        self.center = center
    }

    var body: some View {
        ZStack {
            Image(TransiumAsset.Ticket.postageFrame)
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(variant.frameColor)
                .shadow(color: variant.shadowColor, radius: 0, x: 0, y: 2)

            center()
                .frame(width: size * 0.77, height: size * 0.71)
                .background(variant.imageBackground)
                .clipShape(.rect(cornerRadius: size * 0.025, style: .continuous))
                .padding(.top, size * 0.005)
        }
        .frame(width: size, height: size * 0.96)
        .rotationEffect(tilt)
        .accessibilityElement(children: .combine)
    }
}

extension TransiumStampCard where Center == Image {
    init(
        imageName: String,
        size: CGFloat = 104,
        tilt: Angle = .degrees(-4),
        variant: TransiumStampVariant = .classic
    ) {
        self.init(size: size, tilt: tilt, variant: variant) {
            Image(imageName)
                .resizable()
        }
    }
}

struct TransiumBadge: View {
    let text: String?
    let systemImage: String?
    let variant: TransiumBadgeVariant
    let size: Size

    enum Size {
        case small
        case regular

        var fontSize: CGFloat {
            switch self {
            case .small:
                10
            case .regular:
                12
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .small:
                9
            case .regular:
                11
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .small:
                8
            case .regular:
                10
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .small:
                5
            case .regular:
                6
            }
        }
    }

    init(
        _ text: String? = nil,
        systemImage: String? = nil,
        variant: TransiumBadgeVariant = .paper,
        size: Size = .regular
    ) {
        self.text = text
        self.systemImage = systemImage
        self.variant = variant
        self.size = size
    }

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: size.iconSize, weight: .bold))
            }

            if let text {
                Text(text)
                    .font(TransiumFont.body(size.fontSize, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .foregroundStyle(variant.foregroundColor)
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .background(badgeBackground)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var badgeBackground: some View {
        if variant.usesPaperShape {
            Image(TransiumAsset.Ticket.paperBadge)
                .resizable(capInsets: EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10), resizingMode: .stretch)
                .renderingMode(.template)
                .foregroundStyle(variant.backgroundColor)
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(variant.borderColor, lineWidth: 1)
                }
                .shadow(color: variant.shadowColor, radius: 0, x: 0, y: 2)
        } else {
            Capsule(style: .continuous)
                .fill(variant.backgroundColor)
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(variant.borderColor, lineWidth: 1)
                }
                .shadow(color: variant.shadowColor, radius: 0, x: 0, y: 2)
        }
    }
}

struct TransiumTicketCard<Stamp: View, BodyContent: View, Footer: View>: View {
    let variant: TransiumTicketVariant
    let stamp: Stamp
    let bodyContent: BodyContent
    let footer: Footer

    init(
        variant: TransiumTicketVariant = .blue,
        @ViewBuilder stamp: () -> Stamp,
        @ViewBuilder bodyContent: () -> BodyContent,
        @ViewBuilder footer: () -> Footer
    ) {
        self.variant = variant
        self.stamp = stamp()
        self.bodyContent = bodyContent()
        self.footer = footer()
    }

    var body: some View {
        HStack(spacing: 14) {
            stamp
                .frame(width: 104)

            TransiumTicketDivider(color: variant.dividerColor)
                .frame(width: 1, height: 124)

            VStack(alignment: .leading, spacing: 8) {
                bodyContent
                    .foregroundStyle(variant.foregroundColor)
                    .frame(height: 74, alignment: .topLeading)

                Spacer(minLength: 0)

                footer
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 16)
        .padding(.trailing, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, minHeight: 158, maxHeight: 158, alignment: .leading)
        .background {
            TransiumTicketShape()
                .fill(variant.backgroundColor)
        }
        .clipShape(TransiumTicketShape())
        .accessibilityElement(children: .combine)
    }
}

extension TransiumTicketCard where Stamp == TransiumStampCard<Image>, BodyContent == TransiumTicketCopy, Footer == TransiumTicketFooter {
    init(
        title: String,
        subtitle: String,
        distance: String,
        price: String,
        imageName: String,
        variant: TransiumTicketVariant = .blue
    ) {
        self.init(variant: variant) {
            TransiumStampCard(imageName: imageName, size: 104)
        } bodyContent: {
            TransiumTicketCopy(title: title, subtitle: subtitle, variant: variant)
        } footer: {
            TransiumTicketFooter(distance: distance, price: price, variant: variant)
        }
    }
}

extension TransiumTicketCard where Stamp == TransiumStampCard<AnyView>, BodyContent == TransiumTicketCopy, Footer == TransiumTicketFooter {
    init(
        title: String,
        subtitle: String,
        distance: String,
        price: String,
        imageUrl: String?,
        fallbackImageName: String = "kintamani",
        variant: TransiumTicketVariant = .blue
    ) {
        let stampVariant: TransiumStampVariant = {
            switch variant {
            case .blue: return .blue
            case .mint: return .green
            case .coral: return .warm
            default: return .classic
            }
        }()
        
        self.init(variant: variant) {
            TransiumStampCard(size: 104, tilt: .degrees(-4), variant: stampVariant) {
                AnyView(
                    Group {
                        if let imageUrl, let url = URL(string: imageUrl.hasPrefix("http") ? imageUrl : "https://transium-api.heryandjaruma.workers.dev\(imageUrl)") {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let img):
                                    img
                                        .resizable()
                                        .scaledToFill()
                                default:
                                    Image(fallbackImageName)
                                        .resizable()
                                        .scaledToFill()
                                }
                            }
                        } else {
                            Image(fallbackImageName)
                                .resizable()
                                .scaledToFill()
                        }
                    }
                )
            }
        } bodyContent: {
            TransiumTicketCopy(title: title, subtitle: subtitle, variant: variant)
        } footer: {
            TransiumTicketFooter(distance: distance, price: price, variant: variant)
        }
    }
}

struct TransiumTicketCopy: View {
    let title: String
    let subtitle: String
    let variant: TransiumTicketVariant

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(TransiumFont.body(23, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(subtitle)
                .font(TransiumFont.body(12, weight: .medium))
                .foregroundStyle(variant.secondaryColor)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct TransiumTicketFooter: View {
    let distance: String
    let price: String
    let variant: TransiumTicketVariant

    private var parsedDistance: (value: String, unit: String) {
        let trimmed = distance.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix(" km") {
            return (String(trimmed.dropLast(3)), "km")
        } else if trimmed.hasSuffix(" m") {
            return (String(trimmed.dropLast(2)), "m")
        } else if trimmed.hasSuffix("km") {
            return (String(trimmed.dropLast(2)), "km")
        } else if trimmed.hasSuffix("m") {
            return (String(trimmed.dropLast(1)), "m")
        }
        return (trimmed, "km")
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(parsedDistance.value)
                    .font(TransiumFont.body(28, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(parsedDistance.unit)
                    .font(TransiumFont.body(13, weight: .bold))
                    .padding(.bottom, 2)
            }
            .foregroundStyle(variant.foregroundColor)

            Spacer(minLength: 4)

            TransiumBadge(price, systemImage: "banknote", variant: .paper, size: .small)
                .rotationEffect(.degrees(-4))
                .offset(y: -8)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TransiumTicketDivider: View {
    let color: Color

    var body: some View {
        TransiumVerticalLine()
            .stroke(
                color,
                style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [5, 6])
            )
    }
}

private struct TransiumVerticalLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))

        return path
    }
}

private struct TransiumTicketShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = min(rect.height * 0.145, 18)
        let notchRadius = min(rect.height * 0.17, 27)
        let notchDepth = min(notchRadius * 0.66, 18)
        var path = Path()

        path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radius),
            control1: CGPoint(x: rect.maxX - radius * 0.45, y: rect.minY),
            control2: CGPoint(x: rect.maxX, y: rect.minY + radius * 0.45)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY - notchRadius))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY + notchRadius),
            control1: CGPoint(x: rect.maxX - notchDepth, y: rect.midY - notchRadius * 0.76),
            control2: CGPoint(x: rect.maxX - notchDepth, y: rect.midY + notchRadius * 0.76)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.maxY - radius * 0.45),
            control2: CGPoint(x: rect.maxX - radius * 0.45, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control1: CGPoint(x: rect.minX + radius * 0.45, y: rect.maxY),
            control2: CGPoint(x: rect.minX, y: rect.maxY - radius * 0.45)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control1: CGPoint(x: rect.minX, y: rect.minY + radius * 0.45),
            control2: CGPoint(x: rect.minX + radius * 0.45, y: rect.minY)
        )
        path.closeSubpath()

        return path
    }
}

#Preview {
    ZStack {
        TransiumColor.ticketInk
            .ignoresSafeArea()

        VStack(spacing: 24) {
            TransiumTicketCard(
                title: "Sanur",
                subtitle: "A laid-back coastal escape. Where earlybirds relax.",
                distance: "11",
                price: "Rp. 4,4k",
                imageName: TransiumAsset.Illustration.onboardingExplore
            )
            .frame(width: 336)

            HStack(spacing: 18) {
                TransiumStampCard(imageName: TransiumAsset.Illustration.onboardingAdventure, variant: .warm)
                TransiumBadge("Rp. 4,4k", systemImage: "banknote", variant: .paper)
                TransiumBadge("Saved", systemImage: "checkmark", variant: .blue)
            }
        }
        .padding()
    }
}
