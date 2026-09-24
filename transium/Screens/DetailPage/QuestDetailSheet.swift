//
//  QuestDetailSheet.swift
//  transium
//
//  Created by Abigail Metanoia Melody on 19/08/26.
//

import SwiftUI

// MARK: - Quest Detail Data Model

struct QuestDetailInfo: Identifiable {
    let id: String
    let stampImageUrl: String?
    let stampImageName: String
    let title: String
    let shortDescription: String
    let category: String
    let location: String
    let access: String
    let about: String
    let steps: [String]
    let points: Int
    let theme: DetailPlaceScreen.QuestTheme
}

// MARK: - Quest Detail Sheet

struct QuestDetailSheet: View {
    let quest: QuestDetailInfo
    var onStartQuest: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                dragHandle
                headerCard
                infoRow
                aboutSection
                whatYoullDoSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 100) // space above the sticky button
        }
        .safeAreaInset(edge: .bottom) {
            startQuestButton
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 16)
                .background(
                    LinearGradient(
                        colors: [Color.white.opacity(0), Color.white],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 90)
                    .allowsHitTesting(false),
                    alignment: .top
                )
        }
        .background(Color.white)
    }

    // MARK: Drag Handle

    private var dragHandle: some View {
        Capsule()
            .fill(Color.gray.opacity(0.35))
            .frame(width: 44, height: 5)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: Header (stamp image + title + badge)

    private var headerCard: some View {
        HStack(alignment: .top, spacing: 16) {
            stampImage
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(-4))

            VStack(alignment: .leading, spacing: 8) {
                Text(quest.title)
                    .font(TransiumFont.display(32, weight: .bold))
                    .foregroundColor(.primary)

                Text(quest.shortDescription)
                    .font(TransiumFont.body(15))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                categoryBadge
            }
        }
    }

    private var stampImage: some View {
        ZStack {
            if let urlString = quest.stampImageUrl,
               let url = APIConfiguration.resolveURL(urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .empty:
                        Rectangle().fill(Color(.systemGray5))
                    default:
                        Rectangle().fill(Color(.systemGray4))
                    }
                }
            } else {
                Image(quest.stampImageName)
                    .resizable()
                    .scaledToFill()
            }
        }
        .clipped()
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(
                    quest.theme.accent.opacity(0.85),
                    style: StrokeStyle(lineWidth: 5, dash: [1, 8], dashPhase: 0)
                )
        )
        .padding(6)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
    }

    private var categoryBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: categoryIcon)
                .font(.system(size: 11, weight: .bold))
            Text(quest.category.transiumLocalized)
                .font(TransiumFont.display(12, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(quest.theme.accent)
        .clipShape(Capsule())
    }

    private var categoryIcon: String {
        let normalized = quest.category.lowercased()
        if normalized.contains("beach") { return "beach.umbrella" }
        if normalized.contains("nature") || normalized.contains("mountain") { return "leaf.fill" }
        if normalized.contains("cult") || normalized.contains("temple") { return "sparkles" }
        return "mappin.and.ellipse"
    }

    // MARK: Location / Access Row

    private var infoRow: some View {
        HStack(spacing: 0) {
            infoItem(icon: "mappin.and.ellipse", label: "Location", value: quest.location)

            Divider()
                .frame(height: 32)
                .padding(.horizontal, 16)

            infoItem(icon: "hand.tap", label: "Access", value: quest.access)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func infoItem(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(quest.theme.accent.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .foregroundColor(quest.theme.accent)
                    .font(.system(size: 14, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label.transiumLocalized)
                    .font(TransiumFont.body(13))
                    .foregroundColor(.gray)
                Text(value)
                    .font(TransiumFont.body(14, weight: .semibold))
                    .foregroundColor(.black)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: About Section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("About This Quest".transiumLocalized)
                .font(TransiumFont.body(20, weight: .bold))
                .foregroundColor(.black)

            Text(quest.about.transiumLocalized)
                .font(TransiumFont.body(15))
                .foregroundColor(.gray)
                .lineSpacing(4)
        }
    }

    // MARK: What You'll Do Section

    private var whatYoullDoSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(quest.theme.accent)
                    .font(.system(size: 25, weight: .semibold))
                Text("What You'll Do".transiumLocalized)
                    .font(TransiumFont.body(17, weight: .bold))
                    .foregroundColor(.black)
            }

            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(quest.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(TransiumFont.display(15, weight: .bold))
                            .foregroundColor(quest.theme.accent)
                            .frame(width: 32, height: 32)
                            .background(quest.theme.accent.opacity(0.15))
                            .clipShape(Circle())

                        Text(step.transiumLocalized)
                            .font(TransiumFont.body(15))
                            .foregroundColor(.black.opacity(0.75))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(18)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: Start Quest Button

    private var startQuestButton: some View {
        Button {
            onStartQuest?()
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Text("Start Quest".transiumLocalized)
                    .font(TransiumFont.display(17, weight: .bold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(quest.theme.accent)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Preview

#Preview {
    QuestDetailSheet(
        quest: QuestDetailInfo(
            id: "1",
            stampImageUrl: nil,
            stampImageName: "sample_sanur",
            title: "Sanur",
            shortDescription: "Visit Sanur before 8 AM and capture the sunrise.",
            category: "Beach",
            location: "Sanur Beach, Bali",
            access: "Free",
            about: "Slow down and jeoy the calm side of Bali at sanur beach. thisSlow down and jeoy the calm side of Bali at sanur beach. thisSlow down and jeoy the calm side of Bali at sanur beach. thisSlow down and jeoy the calm side of Bali at sanur beach.",
            steps: [
                "Come to Sanur Beach (any time in the morning)",
                "Take a photo with the beach/sunrise.",
                "Check in on the app.",
                "Collect your points!"
            ],
            points: 10,
            theme: .blue
        )
    )
}
