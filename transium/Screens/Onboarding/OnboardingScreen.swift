//
//  OnboardingScreen.swift
//  transium
//

import SwiftUI

struct OnboardingScreen: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onComplete: () -> Void

    @State private var currentPage = 0
    @State private var pageDirection = 1

    private let pages = OnboardingPage.defaultPages

    var body: some View {
        let page = pages[currentPage]

        ZStack {
            TransiumColor.primaryBlue
                .ignoresSafeArea()

            VStack(spacing: 0) {
                navigationBar

                Spacer(minLength: 26)

                OnboardingPageContent(page: page)
                    .padding(.horizontal, 25)

                OnboardingVisualPager(
                    pages: pages,
                    currentPage: currentPage,
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
    }

    // MARK: Important Flow - Onboarding Navigation

    private func advance() {
        guard currentPage < pages.count - 1 else {
            onComplete()
            return
        }

        pageDirection = 1

        withAnimation(pageAnimation) {
            currentPage += 1
        }
    }

    private func goBack() {
        guard currentPage > 0 else {
            return
        }

        pageDirection = -1

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

private struct OnboardingPageContent: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let page: OnboardingPage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(page.title)
                .font(TransiumFont.display(45))
                .foregroundStyle(.white)

            Text(page.description)
                .font(TransiumFont.body(17))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .id(page.title)
        .transition(pageTransition)
        .accessibilityElement(children: .combine)
    }

    private var pageTransition: AnyTransition {
        guard !reduceMotion else {
            return .opacity
        }

        return AnyTransition.asymmetric(
            insertion: AnyTransition.opacity.combined(with: .offset(y: 10)),
            removal: AnyTransition.opacity.combined(with: .offset(y: -8))
        )
    }
}

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
}

private struct OnboardingPage {
    let title: String
    let description: String
    let imageName: String
    let buttonTitle: String

    static let defaultPages = [
        OnboardingPage(
            title: "Explore Bali",
            description: "No matter if you've been here 20 years or 20 minutes.",
            imageName: TransiumAsset.Illustration.onboardingExplore,
            buttonTitle: "Next"
        ),
        OnboardingPage(
            title: "Worry-free Adventure!",
            description: "No matter if you've been here 20 years or 20 minutes.",
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
