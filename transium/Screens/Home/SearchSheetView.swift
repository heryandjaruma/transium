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
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(TransiumColor.primaryBlue)

                    TextField("Search by name, address, or landmark", text: $searchText)
                        .focused($isSearchFieldFocused)
                        .font(TransiumFont.body(14))
                        .submitLabel(.search)

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.gray.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }

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
            .padding(.bottom, 10)
            .foregroundStyle(TransiumColor.primaryBlue)

            resultsList
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var resultsList: some View {
        if isResolvingSelection || (isSearching && suggestions.isEmpty) {
            VStack {
                HStack {
                    Spacer()
                    ProgressView().tint(.white)
                    Spacer()
                }
                .padding(.top, 28)

                Spacer()
            }
        } else if suggestions.isEmpty {
            VStack(alignment: .leading) {
                if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("No results for \"\(searchText)\"")
                        .font(TransiumFont.body(14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                }
                Spacer()
            }
        } else {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(action: { selectSuggestion(suggestion) }) {
                            suggestionRow(suggestion)
                        }
                        .buttonStyle(.transiumNoOpacity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 24)
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
        VStack(spacing: 14) {
            // Drag handle indicator
            Capsule()
                .fill(Color.white.opacity(0.35))
                .frame(width: 38, height: 4.5)
                .padding(.top, 10)

            // Location Info Card
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.98, green: 0.28, blue: 0.28).opacity(0.12))
                        .frame(width: 48, height: 48)

                    Image("location_red")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Selected Starting Point")
                        .font(TransiumFont.body(11, weight: .bold))
                        .foregroundStyle(TransiumColor.primaryBlue)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    Text(pinnedAddressLabel)
                        .font(TransiumFont.body(15, weight: .bold))
                        .foregroundStyle(.black)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Button {
                    state = .searching
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(TransiumColor.primaryBlue)
                        .frame(width: 38, height: 38)
                        .background(TransiumColor.primaryBlue.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)

            // Fine-tune map pin hint
            HStack(spacing: 6) {
                Image(systemName: "hand.draw.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text("Drag the map to fine-tune your starting pin")
                    .font(TransiumFont.body(12, weight: .medium))
            }
            .foregroundStyle(Color.white.opacity(0.85))
            .padding(.vertical, 2)

            // Action Buttons
            VStack(spacing: 10) {
                Button(action: onConfirmStartingPoint) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("Set Starting Point")
                            .font(TransiumFont.body(16, weight: .bold))
                    }
                    .foregroundColor(TransiumColor.primaryBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.12), radius: 8, y: 3)
                }

                Button(action: onUseCurrentLocation) {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Use My Current Location")
                            .font(TransiumFont.body(15, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    )
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 2)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
