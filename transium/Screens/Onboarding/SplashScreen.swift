import SwiftUI

// MARK: - Splash Screen

struct SplashScreenView: View {

    /// Called once the splash animation has finished holding, so the
    /// parent view can switch over to your main content.
    var onFinished: () -> Void = {}

    @State private var circleScale: CGFloat = 0.01
    @State private var logoScale: CGFloat = 0.4
    @State private var logoOpacity: Double = 0

    private let brandBlue = Color(red: 0x34/255, green: 0x72/255, blue: 0xFB/255)

    var body: some View {
        GeometryReader { geo in
            // Big enough that the circle fully covers every corner of the screen
            let diagonal = sqrt(pow(geo.size.width, 2) + pow(geo.size.height, 2))

            ZStack {
                Color.white
                    .ignoresSafeArea()

                Circle()
                    .fill(brandBlue)
                    .frame(width: diagonal * 1.15, height: diagonal * 1.15)
                    .scaleEffect(circleScale)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)

                logo
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
            }
        }
        .ignoresSafeArea()
        .onAppear(perform: animate)
    }

    // Swap this for your real bus asset, e.g.
    //   Image("BusLogo").resizable().scaledToFit().frame(width: 96, height: 96)
    private var logo: some View {
        Image(systemName: "bus.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(.white)
            .frame(width: 72, height: 72)
    }

    private func animate() {
        // Phase 1 — the dot grows into a circle that swallows the whole screen.
        withAnimation(.easeOut(duration: 0.6)) {
            circleScale = 1.0
        }

        // Phase 2 — logo scales + fades in partway through the expansion,
        // with a touch of spring so it settles instead of just stopping.
        withAnimation(.spring(response: 0.5, dampingFraction: 0.72).delay(0.28)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }

        // Hold on the finished state briefly, then hand off to the caller.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            onFinished()
        }
    }
}

// MARK: - Example usage

struct RootView: View {
    @State private var showSplash = true

    var body: some View {
        ZStack {
            ContentView() // <- your real app entry point

            if showSplash {
                SplashScreenView {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showSplash = false
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
