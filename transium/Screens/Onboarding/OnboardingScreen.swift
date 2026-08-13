//
//  OnboardingScreen.swift
//  transium
//

import SwiftUI

struct OnboardingScreen: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onComplete: () -> Void

    @State private var currentPage = 0
    @GestureState private var dragOffset: CGFloat = 0
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
                    dragOffset: dragOffset,
                    animation: pageAnimation
                )
                .frame(height: 120)

                OnboardingVisualPager(
                    pages: pages,
                    currentPage: currentPage,
                    dragOffset: dragOffset,
                    animation: pageAnimation
                )
                    .frame(height: 350)
                    .padding(.top, 10)

                Spacer(minLength: 28)

                PageIndicator(currentPage: currentPage, totalPages: pages.count)
                    .padding(.bottom, 20)

                TransiumPrimaryButton(title: page.buttonTitle, action: advance)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .contentShape(.rect)
        .gesture(swipeGesture)
    }

    // MARK: Important Flow - Onboarding Navigation

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 36)
            .updating($dragOffset) { value, state, _ in
                state = rubberBandedDragOffset(value.translation.width)
            }
            .onEnded { value in
                handleSwipe(value.predictedEndTranslation.width)
            }
    }

    private func handleSwipe(_ horizontalTranslation: CGFloat) {
        let threshold: CGFloat = 54

        if horizontalTranslation <= -threshold {
            goToNextPage()
        } else if horizontalTranslation >= threshold {
            goBack()
        }
    }

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

    private func rubberBandedDragOffset(_ horizontalTranslation: CGFloat) -> CGFloat {
        let isDraggingBeforeFirstPage = currentPage == 0 && horizontalTranslation > 0
        let isDraggingAfterLastPage = currentPage == pages.count - 1 && horizontalTranslation < 0

        return isDraggingBeforeFirstPage || isDraggingAfterLastPage
            ? horizontalTranslation * 0.22
            : horizontalTranslation
    }

    private var navigationBar: some View {
        HStack {
            if currentPage > 0 {
                TransiumIconButton(systemName: "arrow.left", accessibilityLabel: "Previous onboarding page", action: goBack)
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

private struct OnboardingCopyPager: View {
    let pages: [OnboardingPage]
    let currentPage: Int
    let dragOffset: CGFloat
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
            .offset(x: pageTrackOffset(width: proxy.size.width))
            .animation(animation, value: currentPage)
        }
        .clipped()
    }

    private func pageTrackOffset(width: CGFloat) -> CGFloat {
        (-CGFloat(currentPage) * width) + dragOffset
    }
}

private struct OnboardingPageContent: View {
    let page: OnboardingPage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(page.title)
                .font(TransiumFont.display(45))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.86)

            Text(page.description)
                .font(TransiumFont.body(17))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct OnboardingVisualPager: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let pages: [OnboardingPage]
    let currentPage: Int
    let dragOffset: CGFloat
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
                        }
                    }
                    .offset(x: pageTrackOffset(width: proxy.size.width))
                    .animation(animation.delay(0.035), value: currentPage)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private func visualPage(for page: OnboardingPage) -> some View {
        VStack(spacing: 20) {
            Image(page.imageName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: 350)
                .accessibilityHidden(true)
        }
    }

    private func pageTrackOffset(width: CGFloat) -> CGFloat {
        (-CGFloat(currentPage) * width) + dragOffset
    }
}

private struct OnboardingPage {
    let title: String
    let description: String
    let imageName: String
    let buttonTitle: String

    static let defaultPages = [
        OnboardingPage(
            title: "Explore Bali",
            description: "Find places, routes, and local moments without the guesswork.",
            imageName: TransiumAsset.Illustration.onboardingExplore,
            buttonTitle: "Next"
        ),
        OnboardingPage(
            title: "Worry-free Adventure!",
            description: "Keep every move simple, safe, and ready before you head out.",
            imageName: TransiumAsset.Illustration.onboardingAdventure,
            buttonTitle: "Next"
        ),
        OnboardingPage(
            title: "Make your friend FOMO",
            description: "Wanna be a cooler traveler?\nCollect the badges and share them.",
            imageName: TransiumAsset.Illustration.onboardingShare,
            buttonTitle: "Get Started!"
        )
    ]
}

#Preview {
    OnboardingScreen {}
}
