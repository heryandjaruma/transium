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
                        .foregroundStyle(.secondary)

                    TextField("Cari tujuan atau alamat", text: $searchText)
                        .focused($isSearchFieldFocused)
                        .font(TransiumFont.body(14))
                        .submitLabel(.search)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .clipShape(.rect(cornerRadius: 12, style: .continuous))

                Button("Batal", action: onCancel)
                    .font(TransiumFont.body(13, weight: .semibold))
                    .foregroundStyle(TransiumColor.linkBlue)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // TODO: list hasil pencarian / recent locations (komponen kartu, menyusul)
            Spacer()
        }
    }

    private var pinningContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TransiumColor.primaryBlue)

                Text("Pilih titik di peta")
                    .font(TransiumFont.body(12, weight: .semibold))
            }

            Text("Geser peta di belakang untuk memindahkan pin ke lokasi yang kamu mau.")
                .font(TransiumFont.body(11))
                .foregroundStyle(.secondary)

            // TODO: "Selected starting point" + tombol Set starting point /
            // Use my current location (komponen kartu, menyusul)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
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
