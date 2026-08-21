//
//  SavedQuestScreen.swift
//  transium
//

import SwiftUI

struct SavedQuestScreen: View {
    @Environment(\.dismiss) private var dismiss

    @State private var bookmarkedQuests: [DetailPlaceScreen.Quest] = []
    @State private var isLoading: Bool = true

    private let fallbackQuests: [DetailPlaceScreen.Quest] = [
        DetailPlaceScreen.Quest(
            imageName: "sanoored",
            title: "Sanoored",
            description: "Enjoy the vibe along the shore of Sanur",
            points: 10,
            theme: .blue
        ),
        DetailPlaceScreen.Quest(
            imageName: "gelatour",
            title: "Gela-tour",
            description: "Gelato + Sanur weather = perfect summer",
            points: 10,
            theme: .red
        ),
        DetailPlaceScreen.Quest(
            imageName: "littlestalls",
            title: "Little Stalls",
            description: "Go local by enjoying snacks from small businesses",
            points: 10,
            theme: .green
        )
    ]

    var body: some View {
        ZStack(alignment: .top) {
            TransiumColor.primaryBlue
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if isLoading {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 14) {
                            QuestRowSkeleton(theme: .blue)
                            QuestRowSkeleton(theme: .red)
                            QuestRowSkeleton(theme: .green)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                } else if displayedQuests.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 14) {
                            ForEach(displayedQuests) { quest in
                                SavedQuestCard(quest: quest) {
                                    // Start quest handler
                                    dismiss()
                                } onRemove: {
                                    removeBookmark(quest: quest)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .task {
            await loadBookmarks()
        }
    }

    private var displayedQuests: [DetailPlaceScreen.Quest] {
        bookmarkedQuests.isEmpty ? fallbackQuests : bookmarkedQuests
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Saved Quest")
                .font(TransiumFont.display(34, weight: .bold))
                .foregroundColor(.white)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "arrow.left")
                        .foregroundColor(TransiumColor.primaryBlue)
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.12), radius: 6, y: 3)
                }

                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 96, height: 96)

                Image(systemName: "bookmark.slash")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(.white)
            }

            VStack(spacing: 6) {
                Text("No Saved Quests Yet")
                    .font(TransiumFont.display(24, weight: .bold))
                    .foregroundColor(.white)

                Text("Save quests you'd love to explore later by tapping the bookmark icon.")
                    .font(TransiumFont.body(14))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                dismiss()
            } label: {
                Text("Explore Quests")
                    .font(TransiumFont.body(14, weight: .bold))
                    .foregroundColor(TransiumColor.primaryBlue)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.1), radius: 8, y: 4)
            }
            .padding(.top, 8)

            Spacer()
        }
    }

    // MARK: - Data Loading

    private func loadBookmarks() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let bookmarks = try await BookmarkService.shared.listBookmarks()
            if !bookmarks.isEmpty {
                self.bookmarkedQuests = bookmarks.map { bookmark in
                    let theme: DetailPlaceScreen.QuestTheme = switch bookmark.questCategory.lowercased() {
                    case "culture", "heritage": .red
                    case "nature", "culinary": .green
                    default: .blue
                    }

                    return DetailPlaceScreen.Quest(
                        id: bookmark.questId,
                        fallbackImageName: "sanoored",
                        title: bookmark.questName,
                        description: "\(bookmark.questCategory) Quest",
                        points: 10,
                        theme: theme
                    )
                }
            } else {
                self.bookmarkedQuests = fallbackQuests
            }
        } catch {
            self.bookmarkedQuests = fallbackQuests
        }
    }

    private func removeBookmark(quest: DetailPlaceScreen.Quest) {
        withAnimation(.easeOut(duration: 0.25)) {
            bookmarkedQuests.removeAll { $0.id == quest.id }
        }
        Task {
            try? await BookmarkService.shared.removeBookmark(questId: quest.id)
        }
    }
}

// MARK: - SavedQuestCard

private struct SavedQuestCard: View {
    let quest: DetailPlaceScreen.Quest
    var onStart: (() -> Void)? = nil
    var onRemove: (() -> Void)? = nil

    var body: some View {
        let stampVariant: TransiumStampVariant = {
            switch quest.theme {
            case .blue: return .blue
            case .red: return .warm
            case .green: return .green
            }
        }()

        HStack(spacing: 14) {
            TransiumStampCard(
                size: 74,
                tilt: .degrees(0),
                variant: stampVariant
            ) {
                thumbnailView
            }
            .frame(width: 74, height: 74)

            VStack(alignment: .leading, spacing: 4) {
                Text(quest.title)
                    .font(TransiumFont.body(16, weight: .bold))
                    .foregroundColor(TransiumColor.darkBlue)
                    .lineLimit(1)

                Text(quest.description)
                    .font(TransiumFont.body(13))
                    .foregroundColor(Color.black.opacity(0.55))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                Button {
                    onStart?()
                } label: {
                    Text("Start Quest")
                        .font(TransiumFont.body(11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(quest.theme.accent)
                        .clipShape(Capsule())
                        .shadow(color: quest.theme.accent.opacity(0.35), radius: 6, y: 3)
                }

                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 0.98, green: 0.72, blue: 0.12))
                    Text("+\(quest.points) pts")
                        .font(TransiumFont.body(11, weight: .bold))
                        .foregroundColor(TransiumColor.darkBlue.opacity(0.65))
                }
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let imageUrl = quest.imageUrl, let url = URL(string: imageUrl.hasPrefix("http") ? imageUrl : "https://transium-api.heryandjaruma.workers.dev\(imageUrl)") {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .empty:
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.black.opacity(0.08))
                default:
                    Image(quest.fallbackImageName)
                        .resizable()
                        .scaledToFill()
                }
            }
        } else {
            Image(quest.fallbackImageName)
                .resizable()
                .scaledToFill()
        }
    }
}

#Preview {
    SavedQuestScreen()
}
