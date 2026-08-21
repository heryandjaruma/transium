//
//  TransiumShimmer.swift
//  transium
//

import SwiftUI

public struct TransiumShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1.0

    var baseColor: Color
    var highlightColor: Color
    var duration: Double

    public init(
        baseColor: Color = Color.white.opacity(0.12),
        highlightColor: Color = Color.white.opacity(0.35),
        duration: Double = 1.3
    ) {
        self.baseColor = baseColor
        self.highlightColor = highlightColor
        self.duration = duration
    }

    public func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .overlay {
                    GeometryReader { geo in
                        let width = max(geo.size.width, 1)
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: highlightColor, location: 0.5),
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: width * 1.5)
                        .offset(x: phase * (width * 1.5) - (width * 0.25))
                    }
                    .mask(content)
                }
                .onAppear {
                    withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                        phase = 1.2
                    }
                }
        }
    }
}

public extension View {
    func transiumShimmer(
        baseColor: Color = Color.white.opacity(0.12),
        highlightColor: Color = Color.white.opacity(0.38),
        duration: Double = 1.3
    ) -> some View {
        modifier(TransiumShimmerModifier(baseColor: baseColor, highlightColor: highlightColor, duration: duration))
    }
}

public struct TransiumSkeletonBlock: View {
    var width: CGFloat?
    var height: CGFloat
    var cornerRadius: CGFloat
    var color: Color
    var shimmerHighlight: Color

    public init(
        width: CGFloat? = nil,
        height: CGFloat = 16,
        cornerRadius: CGFloat = 8,
        color: Color = Color.white.opacity(0.2),
        shimmerHighlight: Color = Color.white.opacity(0.45)
    ) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
        self.color = color
        self.shimmerHighlight = shimmerHighlight
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(color)
            .frame(width: width, height: height)
            .transiumShimmer(baseColor: color, highlightColor: shimmerHighlight)
    }
}
