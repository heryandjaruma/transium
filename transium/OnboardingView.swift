import SwiftUI

let pages = [
    OnboardingPage(
        title: "Explore Bali",
        description: "No matter if you've been here 20 years or 20 minutes.",
        imageName: "Onboarding1",
        buttonTitle: "Next"
    ),

    OnboardingPage(
        title: "Worry-free Adventure!",
        description: "No matter if you've been here 20 years or 20 minutes.",
        imageName: "Onboarding2",
        buttonTitle: "Next"
    ),

    OnboardingPage(
        title: "Make your friend FOMO",
        description: "Wanna be a cooler traveler?\nCollect the badges and share them.",
        imageName: "Onboarding3",
        buttonTitle: "Get Started!"
    )
]

struct OnboardingView: View {

    @State private var currentPage = 0

    var body: some View {

        let page = pages[currentPage]

        ZStack {
            Color("PrimaryBlue")
                .ignoresSafeArea()

            VStack {

                // Top area
                HStack {
                    if currentPage > 0 {
                        BackButton {
                            currentPage -= 1
                        }
                    }

                    Spacer()

                    SkipButton {
                        print("Skip tapped")
                    }
                }
                .padding(.horizontal, 20)
                .padding (.top, 10)

                Spacer()

                // Content
                VStack(alignment: .leading, spacing: 12) {
                    Text(page.title)
                        .font(.custom("Londrina Solid", size: 45))
                        .foregroundStyle(.white)

                    Text(page.description)
                        .font(.custom("Poppins", size: 17))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 25)

                // Illustration
                Image(page.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 350)

                Spacer()

                // Page indicator
                PageIndicator(
                    currentPage: currentPage,
                    totalPages: pages.count
                )

                // Bottom button
                PrimaryButton(title: page.buttonTitle) {
                    if currentPage < pages.count - 1 {
                        currentPage += 1
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .padding(.bottom, 24)
        }
    }
}

#Preview {
    OnboardingView()
}
