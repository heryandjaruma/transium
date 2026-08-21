//
//  SavedQuestScreen.swift
//  transium
//

import SwiftUI

struct SavedQuestScreen: View {
    @Environment(\.dismiss) private var dismiss

    @State private var bookmarkedQuests: [DetailPlaceScreen.Quest] = []
    @State private var isLoading: Bool = true

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
                } else if bookmarkedQuests.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 14) {
                            ForEach(bookmarkedQuests) { quest in
                                SavedQuestCard(quest: quest) {
                                    // Start quest action
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

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Saved Quest")
                .font(TransiumFont.display(32, weight: .bold))
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
        .padding(.top, 24)
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
            guard !bookmarks.isEmpty else {
                self.bookmarkedQuests = []
                return
            }

            // Enrich each bookmark with thumbnail and quest details if available
            var enrichedQuests: [DetailPlaceScreen.Quest] = []
            for bookmark in bookmarks {
                let theme: DetailPlaceScreen.QuestTheme = switch bookmark.questCategory.lowercased() {
                case "culture", "heritage": .red
                case "nature", "culinary": .green
                default: .blue
                }

                if let questDetail = try? await QuestService.shared.getQuest(id: bookmark.questId) {
                    let thumbUrl = questDetail.thumbnails.first?.url
                    enrichedQuests.append(
                        DetailPlaceScreen.Quest(
                            id: bookmark.questId,
                            imageUrl: thumbUrl,
                            fallbackImageName: "sanoored",
                            title: questDetail.name,
                            description: questDetail.description,
                            points: questDetail.xp ?? 10,
                            theme: theme
                        )
                    )
                } else {
                    enrichedQuests.append(
                        DetailPlaceScreen.Quest(
                            id: bookmark.questId,
                            imageUrl: nil,
                            fallbackImageName: "sanoored",
                            title: bookmark.questName,
                            description: "\(bookmark.questCategory) Quest",
                            points: 10,
                            theme: theme
                        )
                    )
                }
            }

            self.bookmarkedQuests = enrichedQuests
        } catch {
            self.bookmarkedQuests = []
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
            QuestBadgePostageStack(
                badgeUrls: quest.badgeImageUrls,
                fallbackImageName: quest.fallbackImageName,
                theme: quest.theme
            )
            .frame(width: 76, height: 76)

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
}

#Preview {
    SavedQuestScreen()
}
