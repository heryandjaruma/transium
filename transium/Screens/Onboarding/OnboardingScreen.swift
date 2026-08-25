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
                    .padding(.top, 10)

                Spacer(minLength: 20)

                // Coordinated copy pager (title + description)
                OnboardingCopyPager(
                    pages: pages,
                    currentPage: currentPage,
                    animation: pageAnimation
                )
                .frame(height: 200)

                // Visual area: Step 3 has the interactive stamp carousel
                OnboardingVisualPager(
                    pages: pages,
                    currentPage: currentPage,
                    animation: pageAnimation
                )
                .frame(height: 335)
                .padding(.top, 4)

                Spacer(minLength: 24)

                VStack(spacing: 16) {
                    OnboardingProgressDots(currentPage: currentPage, totalPages: pages.count)

                    TransiumPrimaryButton(title: page.buttonTitle, action: advance)
                        .padding(.horizontal, 20)
                }
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Navigation Actions

    private func advance() {
        guard currentPage < pages.count - 1 else {
            onComplete()
            return
        }

        withAnimation(pageAnimation) {
            currentPage += 1
        }
    }

    private func goBack() {
        guard currentPage > 0 else { return }

        withAnimation(pageAnimation) {
            currentPage -= 1
        }
    }

    private var pageAnimation: Animation {
        reduceMotion ? .linear(duration: 0.12) : .smooth(duration: 0.35, extraBounce: 0)
    }

    private var navigationBar: some View {
        HStack {
            if currentPage > 0 {
                TransiumIconButton(
                    icon: .system("arrow.left"),
                    accessibilityLabel: "Previous onboarding page",
                    action: goBack
                )
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

// MARK: - Copy Pager

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
        VStack(alignment: page.contentAlignment, spacing: 8) {
            if let badgeIconName = page.badgeIconName {
                Image(badgeIconName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 90)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 12)
                    .accessibilityHidden(true)
            }

            Text(page.title)
                .font(TransiumFont.display(40))
                .foregroundStyle(.white)
                .multilineTextAlignment(page.textAlignment)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: page.frameAlignment)

            Text(page.description)
                .font(TransiumFont.body(16))
                .foregroundStyle(.white.opacity(0.92))
                .multilineTextAlignment(page.textAlignment)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: page.frameAlignment)
        }
        .frame(maxWidth: .infinity, alignment: page.frameAlignment)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Visual Pager

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
                                .clipped()
                        }
                    }
                    .offset(x: -CGFloat(currentPage) * proxy.size.width)
                    .animation(animation, value: currentPage)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }

    @ViewBuilder
    private func visualPage(for page: OnboardingPage) -> some View {
        if let galleryImageNames = page.galleryImageNames, !galleryImageNames.isEmpty {
            // Page 3: Postage stamp carousel
            OnboardingBadgeFanView(imageNames: galleryImageNames)
                .frame(height: 330)
        } else {
            // Pages 1 & 2: A bit bigger, well-proportioned illustrations
            VStack(spacing: 0) {
                Image(page.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: 320)
                    .padding(.horizontal, 16)
                    .accessibilityHidden(true)
            }
            .frame(height: 330)
        }
    }
}

// MARK: - Badge Fan (Interactive 3D Carousel without white background)

private struct OnboardingBadgeFanView: View {
    let imageNames: [String]
    @State private var activeIndex = 0 // Starts from 1st postage stamp
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let centerSize = min(width * 0.54, 215)

            ZStack {
                ForEach(imageNames.indices, id: \.self) { index in
                    let rawPosition = CGFloat(index - activeIndex) + (dragOffset / max(width * 0.45, 1))
                    let isCenter = abs(rawPosition) < 0.5
                    let scale = max(0.72, 1.0 - min(abs(rawPosition), 1.2) * 0.18)
                    let cardSize = centerSize * scale
                    let xOffset = rawPosition * (width * 0.38)
                    let yOffset = min(abs(rawPosition), 1.0) * 20
                    let rotation = Double(rawPosition) * 11.0
                    let zIndex = 10.0 - Double(abs(rawPosition)) * 4.0
                    let shadowRadius: CGFloat = isCenter ? 14 : 7
                    let shadowOpacity = isCenter ? 0.26 : 0.13

                    Image(imageNames[index])
                        .resizable()
                        .scaledToFit()
                        .frame(width: cardSize, height: cardSize)
                        .shadow(
                            color: Color.black.opacity(shadowOpacity),
                            radius: shadowRadius,
                            x: 0,
                            y: isCenter ? 8 : 4
                        )
                        .rotationEffect(.degrees(rotation))
                        .offset(x: xOffset, y: yOffset)
                        .zIndex(zIndex)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if activeIndex != index {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                                    activeIndex = index
                                    dragOffset = 0
                                }
                            }
                        }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        let translation = value.translation.width
                        let isAtStart = activeIndex == 0 && translation > 0
                        let isAtEnd = activeIndex == imageNames.count - 1 && translation < 0
                        dragOffset = (isAtStart || isAtEnd) ? translation * 0.25 : translation
                    }
                    .onEnded { value in
                        let translation = value.translation.width
                        let predicted = value.predictedEndTranslation.width
                        let threshold = width * 0.14

                        var targetIndex = activeIndex
                        if predicted < -threshold || translation < -threshold {
                            targetIndex = min(imageNames.count - 1, activeIndex + 1)
                        } else if predicted > threshold || translation > threshold {
                            targetIndex = max(0, activeIndex - 1)
                        }

                        if targetIndex != activeIndex {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }

                        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                            activeIndex = targetIndex
                            dragOffset = 0
                        }
                    }
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Badge postage stamps carousel")
        .accessibilityValue("Stamp \(activeIndex + 1) of \(imageNames.count)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                if activeIndex < imageNames.count - 1 {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) { activeIndex += 1 }
                }
            case .decrement:
                if activeIndex > 0 {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) { activeIndex -= 1 }
                }
            @unknown default: break
            }
        }
    }
}

// MARK: - 3-Dot Progress Indicator

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

// MARK: - Page Model

private struct OnboardingPage {
    let title: String
    let description: String
    let imageName: String
    let buttonTitle: String
    let badgeIconName: String?
    let galleryImageNames: [String]?
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
            badgeIconName: TransiumAsset.Illustration.onboardingTrophy,
            galleryImageNames: [
                TransiumAsset.Illustration.onboardingStampMonkey,
                TransiumAsset.Illustration.onboardingStampTemple,
                TransiumAsset.Illustration.onboardingStampStatue
            ],
            contentAlignment: .center,
            textAlignment: .center
        )
    ]
}

#Preview {
    OnboardingScreen {}
}
