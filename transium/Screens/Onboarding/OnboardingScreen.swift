//
//  OnboardingScreen.swift
//  transium
//

import SwiftUI

struct OnboardingScreen: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onComplete: () -> Void

    @State private var currentPage = 0
    private let pages = OnboardingPage.defaultPages

    init(initialPage: Int = 0, onComplete: @escaping () -> Void) {
        let pageBounds = OnboardingPage.defaultPages.indices
        let safeInitialPage = pageBounds.contains(initialPage) ? initialPage : 0

        self.onComplete = onComplete
        _currentPage = State(initialValue: safeInitialPage)
    }

    var body: some View {
        let page = pages[currentPage]

        ZStack {
            TransiumColor.primaryBlue
                .ignoresSafeArea()

            VStack(spacing: 0) {
                navigationBar

                Spacer(minLength: 26)

                OnboardingCopyPager(
                    pages: pages,
                    currentPage: currentPage,
                    animation: pageAnimation
                )
                .frame(height: 200)

                OnboardingVisualPager(
                    pages: pages,
                    currentPage: currentPage,
                    animation: pageAnimation
                )
                    .frame(height: 350)
                    .padding(.top, 10)

                Spacer(minLength: 28)

                // Page navigation is button-only now, so the indicator is a
                // small 3-dot progress marker (same visual language as the
                // old PageIndicator) instead of a full-width bar.
                OnboardingProgressDots(currentPage: currentPage, totalPages: pages.count)
                    .padding(.bottom, 20)

                TransiumPrimaryButton(title: page.buttonTitle, action: advance)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
    }

    // MARK: Important Flow - Onboarding Navigation

    private func advance() {
        guard currentPage < pages.count - 1 else {
            onComplete()
            return
        }

        goToNextPage()
    }

    private func goToNextPage() {
        guard currentPage < pages.count - 1 else {
            return
        }

        withAnimation(pageAnimation) {
            currentPage += 1
        }
    }

    private func goBack() {
        guard currentPage > 0 else {
            return
        }

        withAnimation(pageAnimation) {
            currentPage -= 1
        }
    }

    private var pageAnimation: Animation {
        reduceMotion ? .linear(duration: 0.12) : .smooth(duration: 0.34, extraBounce: 0)
    }

    private var navigationBar: some View {
        HStack {
            if currentPage > 0 {
                TransiumIconButton(icon: .system("arrow.left"), accessibilityLabel: "Previous onboarding page", action: goBack)
                    .transition(.opacity.combined(with: .scale))
            }

            Spacer()

            TransiumCapsuleTextButton(title: "Skip", action: onComplete)
                .accessibilityLabel("Skip onboarding")
        }
        .frame(height: 44)
        .padding(.horizontal, 20)
    }
}

// MARK: - 3-dot progress indicator (replaces the old dot PageIndicator)

private struct OnboardingProgressDots: View {
    let currentPage: Int
    let totalPages: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { index in
                Capsule()
                    .fill(Color.white.opacity(index == currentPage ? 1 : 0.35))
                    .frame(width: index == currentPage ? 22 : 8, height: 8)
            }
        }
        .animation(.smooth(duration: 0.34, extraBounce: 0), value: currentPage)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Onboarding progress")
        .accessibilityValue("Step \(currentPage + 1) of \(totalPages)")
    }
}

// MARK: - Copy pager (title / description)

private struct OnboardingCopyPager: View {
    let pages: [OnboardingPage]
    let currentPage: Int
    let animation: Animation

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                ForEach(pages.indices, id: \.self) { pageIndex in
                    OnboardingPageContent(page: pages[pageIndex])
                        .padding(.horizontal, 25)
                        .frame(width: proxy.size.width)
                }
            }
            .offset(x: -CGFloat(currentPage) * proxy.size.width)
            .animation(animation, value: currentPage)
        }
        .clipped()
    }
}

private struct OnboardingPageContent: View {
    let page: OnboardingPage

    var body: some View {
        VStack(alignment: page.contentAlignment, spacing: 12) {
            if let badgeIconName = page.badgeIconName {
                Image(badgeIconName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 64)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityHidden(true)
            }

            Text(page.title)
                .font(TransiumFont.display(45))
                .foregroundStyle(.white)
                .multilineTextAlignment(page.textAlignment)
                .lineLimit(2)
                .minimumScaleFactor(0.86)
                .frame(maxWidth: .infinity, alignment: page.frameAlignment)

            Text(page.description)
                .font(TransiumFont.body(17))
                .foregroundStyle(.white)
                .multilineTextAlignment(page.textAlignment)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: page.frameAlignment)
        }
        .frame(maxWidth: .infinity, alignment: page.frameAlignment)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Visual pager (illustration / badge gallery)

private struct OnboardingVisualPager: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let pages: [OnboardingPage]
    let currentPage: Int
    let animation: Animation

    var body: some View {
        Group {
            if reduceMotion {
                visualPage(for: pages[currentPage])
            } else {
                GeometryReader { proxy in
                    HStack(spacing: 0) {
                        ForEach(pages.indices, id: \.self) { pageIndex in
                            visualPage(for: pages[pageIndex])
                                .frame(width: proxy.size.width)
                                // Clip PER PAGE, not just around the whole track.
                                // The badge gallery deliberately draws its fan
                                // cards past its own edges; without this, that
                                // overflow bleeds into whichever page happens to
                                // sit in the adjacent slot (e.g. showing up on
                                // page 2 while page 3 is still off-screen).
                                .clipped()
                        }
                    }
                    .offset(x: -CGFloat(currentPage) * proxy.size.width)
                    .animation(animation.delay(0.035), value: currentPage)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }

    @ViewBuilder
    private func visualPage(for page: OnboardingPage) -> some View {
        if let galleryImageNames = page.galleryImageNames, !galleryImageNames.isEmpty {
            // Badge gallery: user can freely swipe between badge photos,
            // independent from the (button-only) onboarding pages.
            // Pass `initialIndex:` to start on a different badge, e.g. `initialIndex: 1`
            // to open on the second photo instead of the first.
            OnboardingBadgeGallery(imageNames: galleryImageNames)
        } else {
            VStack(spacing: 20) {
                Image(page.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: 350)
                    .accessibilityHidden(true)
            }
        }
    }
}

// MARK: - Badge gallery (used on the "Make your friend FOMO" page)
//
// Renders a "stamp fan" layout: the current badge sits large and upright in
// the middle with a white border; the previous/next badges peek out from
// behind it, scaled down, tinted, rotated outward and dropped slightly lower
// — giving the arc/"rainbow" look from the design, instead of a flat
// full-width slide. No page indicator here on purpose.

private struct OnboardingBadgeGallery: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let imageNames: [String]

    @State private var galleryIndex: Int
    @GestureState private var dragOffset: CGFloat = 0

    init(imageNames: [String], initialIndex: Int = 0) {
        self.imageNames = imageNames
        let safeInitialIndex = imageNames.indices.contains(initialIndex) ? initialIndex : 0
        _galleryIndex = State(initialValue: safeInitialIndex)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(imageNames.indices, id: \.self) { index in
                    badgeCard(index: index, proxy: proxy)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .gesture(dragGesture(width: proxy.size.width))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Badge gallery")
        .accessibilityValue("Photo \(galleryIndex + 1) of \(imageNames.count)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: goToNextBadge()
            case .decrement: goToPreviousBadge()
            @unknown default: break
            }
        }
    }

    @ViewBuilder
    private func badgeCard(index: Int, proxy: GeometryProxy) -> some View {
        let position = relativePosition(for: index, width: proxy.size.width)
        let isCenter = abs(position) < 0.5
        let cardSize = proxy.size.width * 0.56

        Image(imageNames[index])
            .resizable()
            .scaledToFill()
            .frame(width: cardSize, height: cardSize)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(isCenter ? 14 : 8)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(borderColor(for: position))
            )
            .shadow(color: .black.opacity(isCenter ? 0.18 : 0.1), radius: isCenter ? 14 : 8, y: 6)
            .rotationEffect(.degrees(rotation(for: position)))
            .scaleEffect(scale(for: position))
            .offset(x: xOffset(for: position, width: proxy.size.width), y: yOffset(for: position))
            .opacity(opacity(for: position))
            .zIndex(isCenter ? 1 : 0)
            .animation(galleryAnimation, value: galleryIndex)
    }

    private func relativePosition(for index: Int, width: CGFloat) -> CGFloat {
        CGFloat(index - galleryIndex) + rubberBandedDragOffset(dragOffset) / max(width, 1)
    }

    private func borderColor(for position: CGFloat) -> Color {
        if position < -0.5 { return Color(red: 0.94, green: 0.55, blue: 0.5) }   // coral, previous badge
        if position > 0.5 { return Color(red: 0.96, green: 0.79, blue: 0.42) }   // mustard, next badge
        return .white
    }

    private func rotation(for position: CGFloat) -> Double {
        Double(position) * 14
    }

    private func scale(for position: CGFloat) -> CGFloat {
        1 - min(abs(position), 1) * 0.28
    }

    private func xOffset(for position: CGFloat, width: CGFloat) -> CGFloat {
        position * width * 0.5
    }

    private func yOffset(for position: CGFloat) -> CGFloat {
        min(abs(position), 1) * 26
    }

    private func opacity(for position: CGFloat) -> Double {
        abs(position) > 1.4 ? 0 : 1
    }

    private func rubberBandedDragOffset(_ translation: CGFloat) -> CGFloat {
        let isBeforeFirst = galleryIndex == 0 && translation > 0
        let isAfterLast = galleryIndex == imageNames.count - 1 && translation < 0
        return isBeforeFirst || isAfterLast ? translation * 0.22 : translation
    }

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($dragOffset) { value, state, _ in
                state = value.translation.width
            }
            .onEnded { value in
                let threshold = width * 0.22
                if value.predictedEndTranslation.width <= -threshold {
                    goToNextBadge()
                } else if value.predictedEndTranslation.width >= threshold {
                    goToPreviousBadge()
                }
            }
    }

    private func goToNextBadge() {
        guard galleryIndex < imageNames.count - 1 else { return }
        withAnimation(galleryAnimation) { galleryIndex += 1 }
    }

    private func goToPreviousBadge() {
        guard galleryIndex > 0 else { return }
        withAnimation(galleryAnimation) { galleryIndex -= 1 }
    }

    private var galleryAnimation: Animation {
        reduceMotion ? .linear(duration: 0.12) : .smooth(duration: 0.3, extraBounce: 0)
    }
}

// MARK: - Page model

private struct OnboardingPage {
    let title: String
    let description: String
    let imageName: String
    let buttonTitle: String
    /// Small badge/icon shown above the title (e.g. the trophy on the last page).
    let badgeIconName: String?
    /// When set, the visual area becomes a swipeable badge gallery instead of a single image.
    let galleryImageNames: [String]?
    /// Leading (default) for pages 1–2, center for the last "FOMO" page.
    let contentAlignment: HorizontalAlignment
    let textAlignment: TextAlignment

    var frameAlignment: Alignment {
        Alignment(horizontal: contentAlignment, vertical: .center)
    }

    init(
        title: String,
        description: String,
        imageName: String,
        buttonTitle: String,
        badgeIconName: String? = nil,
        galleryImageNames: [String]? = nil,
        contentAlignment: HorizontalAlignment = .leading,
        textAlignment: TextAlignment = .leading
    ) {
        self.title = title
        self.description = description
        self.imageName = imageName
        self.buttonTitle = buttonTitle
        self.badgeIconName = badgeIconName
        self.galleryImageNames = galleryImageNames
        self.contentAlignment = contentAlignment
        self.textAlignment = textAlignment
    }

    static let defaultPages = [
        OnboardingPage(
            title: "Explore Bali ✈️",
            description: "Find places, routes, and local moments without the guesswork.",
            imageName: TransiumAsset.Illustration.onboardingExplore,
            buttonTitle: "Next"
        ),
        OnboardingPage(
            title: "Worry-free\nAdventure!✨",
            description: "You will explore, but you won't get lost!",
            imageName: TransiumAsset.Illustration.onboardingAdventure,
            buttonTitle: "Next"
        ),
        OnboardingPage(
            title: "Make your friend FOMO",
            description: "Wanna be a cooler traveler?\nCollect the badges and share them.",
            imageName: TransiumAsset.Illustration.onboardingShare,
            buttonTitle: "Get Started!",
            badgeIconName: TransiumAsset.Illustration.onboard3trophy,
            galleryImageNames: [
                TransiumAsset.Illustration.onboard3photo1,
                TransiumAsset.Illustration.onboard3photo2,
                TransiumAsset.Illustration.onboard3photo3
            ],
            contentAlignment: .center,
            textAlignment: .center
        )
    ]
}

#Preview {
    OnboardingScreen {}
}
