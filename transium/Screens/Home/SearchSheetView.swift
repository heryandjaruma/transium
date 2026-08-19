import SwiftUI

enum SearchSheetState {
    case searching   // detent .large — search input + keyboard
    case pinning     // detent .medium — drag point mode
}


struct SearchSheetView: View {
    @Binding var state: SearchSheetState
    @Binding var searchText: String
    var onCancel: () -> Void

    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        Group {
            switch state {
            case .searching:
                searchingContent
            case .pinning:
                pinningContent
            }
        }
        .presentationBackground(TransiumColor.primaryBlue)
        .presentationCornerRadius(32)
        .ignoresSafeArea(.container, edges: .horizontal)
        .onAppear {
            if state == .searching {
                isSearchFieldFocused = true
            }
        }
        .onChange(of: state) { _, newState in
            isSearchFieldFocused = (newState == .searching)
        }
    }

    private var searchingContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(TransiumColor.primaryBlue)

                    TextField("Search by name, address, or landmark", text: $searchText)
                        .focused($isSearchFieldFocused)
                        .font(TransiumFont.body(14))
                        .submitLabel(.search)
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(TransiumColor.primaryBlue)
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 62)
                .background(Color.white.opacity(0.95))
                .clipShape(.capsule)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 4)

            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .foregroundStyle(TransiumColor.primaryBlue)
            Spacer()
        }
    }

    private var pinningContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image("location_red")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Selected Starting Point")
                        .font(TransiumFont.body(16, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text("Jl. Danau Tamblingan, Sanur")
                        .font(TransiumFont.body(14))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }

                Spacer()

                Button(action: onCancel) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }
                .background(TransiumColor.darkBlue)
                .clipShape(Circle())
            }
            .padding(.top, 25)

            VStack(spacing: 10) {
                Button {
                    //logika
                } label: {
                    Text("Set Starting Point")
                        .font(TransiumFont.body(16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(TransiumColor.darkBlue)
                        .clipShape(Capsule())
                }

                Button {
                    // logika
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "location")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Use my Current Location")
                            .font(TransiumFont.body(16, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.white)
                    .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 25)
        .padding(.bottom, 20)
    }
}

#Preview("Searching") {
    SearchSheetView(
        state: .constant(.searching),
        searchText: .constant(""),
        onCancel: {}
    )
}

#Preview("Pinning") {
    SearchSheetView(
        state: .constant(.pinning),
        searchText: .constant("")
    ) {}
}

#Preview{
    HomeScreen()
}
