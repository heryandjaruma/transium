import CoreLocation
import SwiftUI

enum SearchSheetState {
    case searching   // detent .large — search input + keyboard
    case pinning     // detent .medium — drag point mode
}


struct SearchSheetView: View {
    @Binding var state: SearchSheetState
    @Binding var searchText: String
    /// The address for whatever coordinate is currently under the fixed map pin — kept live
    /// by the caller as the user drags (see `LocalBaliMapView.onPinCenterChanged`), since this
    /// view has no access to the map itself.
    var pinnedAddressLabel: String = "Locating address..."
    /// A search result was picked (either it already carried coordinates, or this view
    /// resolved its `resolveToken` first) — the caller centers the map's pin on it and moves
    /// `state` to `.pinning`.
    var onSelectLocation: (CLLocationCoordinate2D, String) -> Void = { _, _ in }
    var onConfirmStartingPoint: () -> Void = {}
    var onUseCurrentLocation: () -> Void = {}
    var onCancel: () -> Void

    @FocusState private var isSearchFieldFocused: Bool
    @State private var suggestions: [AutocompleteSuggestion] = []
    @State private var isSearching = false
    @State private var isResolvingSelection = false

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
        .task(id: searchText) {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else {
                suggestions = []
                isSearching = false
                return
            }
            isSearching = true
            // Debounce — wait for typing to pause before spending a network call, cancelled
            // automatically by `.task(id:)` re-running whenever `searchText` changes again.
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            let results = (try? await LocationService.shared.search(query: query)) ?? []
            guard !Task.isCancelled else { return }
            suggestions = results
            isSearching = false
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

            resultsList
        }
    }

    @ViewBuilder
    private var resultsList: some View {
        if isResolvingSelection {
            HStack {
                Spacer()
                ProgressView().tint(.white)
                Spacer()
            }
            .padding(.top, 24)
        } else if isSearching && suggestions.isEmpty {
            HStack {
                Spacer()
                ProgressView().tint(.white)
                Spacer()
            }
            .padding(.top, 24)
        } else if suggestions.isEmpty {
            if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("No results for \"\(searchText)\"")
                    .font(TransiumFont.body(13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
            }
            Spacer()
        } else {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(action: { selectSuggestion(suggestion) }) {
                            suggestionRow(suggestion)
                        }
                        .buttonStyle(.transiumNoOpacity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
        }
    }

    private func suggestionRow(_ suggestion: AutocompleteSuggestion) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(TransiumColor.primaryBlue)

            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.label)
                    .font(TransiumFont.body(14, weight: .semibold))
                    .foregroundStyle(.black)
                    .lineLimit(1)

                if let sublabel = suggestion.sublabel, !sublabel.isEmpty {
                    Text(sublabel)
                        .font(TransiumFont.body(12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    /// Suggestions from GET /maps/search either already carry coordinates, or (a minority —
    /// generic completions Apple hasn't pinned to one place yet) carry a `resolveToken`
    /// instead, requiring one extra GET /maps/search/resolve call before there's a coordinate
    /// to center the pin on.
    private func selectSuggestion(_ suggestion: AutocompleteSuggestion) {
        if let coordinate = suggestion.coordinate {
            onSelectLocation(coordinate, suggestion.label)
            return
        }

        guard let token = suggestion.resolveToken else { return }
        isResolvingSelection = true
        Task {
            let resolved = (try? await LocationService.shared.resolve(token: token))?.first
            await MainActor.run {
                isResolvingSelection = false
                guard let resolved else { return }
                onSelectLocation(resolved.coordinate, resolved.label)
            }
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

                    Text(pinnedAddressLabel)
                        .font(TransiumFont.body(14))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }

                Spacer()

                Button(action: {
                    state = .searching
                }) {
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
                Button(action: onConfirmStartingPoint) {
                    Text("Set Starting Point")
                        .font(TransiumFont.body(16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(TransiumColor.darkBlue)
                        .clipShape(Capsule())
                }

                Button(action: onUseCurrentLocation) {
                    HStack(spacing: 8) {
                        Image(systemName: "location")
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(TransiumColor.primaryBlue)
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
        searchText: .constant(""),
        pinnedAddressLabel: "Jl. Danau Tamblingan, Sanur",
        onCancel: {}
    )
}

#Preview{
    HomeScreen()
}
