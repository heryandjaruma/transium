//
//  DetailPlaceScreen.swift
//  transium
//
//  Created by Abigail Metanoia Melody on 19/08/26.
//

import SwiftUI

struct DetailPlaceScreen: View {
    
    // MARK: - Models
    
    struct Quest: Identifiable {
        let id: String
        let imageName: String
        let title: String
        let description: String
        let points: Int
        let theme: QuestTheme
        
        init(
            id: String = UUID().uuidString,
            imageName: String,
            title: String,
            description: String,
            points: Int = 10,
            theme: QuestTheme = .blue
        ) {
            self.id = id
            self.imageName = imageName
            self.title = title
            self.description = description
            self.points = points
            self.theme = theme
        }
    }
    
    enum QuestTheme {
        case blue, red, green
        
        var accent: Color {
            switch self {
            case .blue: return Color(red: 0.20, green: 0.42, blue: 0.95)
            case .red: return Color(red: 0.92, green: 0.42, blue: 0.38)
            case .green: return Color(red: 0.30, green: 0.68, blue: 0.42)
            }
        }
        
        /// Solid pastel background (accent blended 10% into white).
        /// Deliberately NOT `accent.opacity(0.10)` — a true-alpha color lets
        /// whatever sits behind it (map, images, other cards) show through.
        /// Blending into an opaque color keeps the same pastel look everywhere
        /// this theme is used, regardless of what's underneath.
        var background: Color {
            switch self {
            case .blue: return Color(red: 0.92, green: 0.942, blue: 0.995)
            case .red: return Color(red: 0.992, green: 0.942, blue: 0.938)
            case .green: return Color(red: 0.93, green: 0.968, blue: 0.942)
            }
        }
    }
    
    // MARK: - Properties & State
    
    var kelurahan: Kelurahan = Kelurahan(id: "20447277", kelurahanName: "Sanur", kecamatanName: "Denpasar Selatan")
    var initialQuests: [Quest] = []
    var onStartQuest: ((String) -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedImageIndex: Int = 0
    @State private var quests: [Quest] = []
    @State private var isLoadingQuests: Bool = false
    
    private let galleryImages = ["gallery-1", "gallery-2", "gallery-3"]
    
    private let defaultQuests: [Quest] = [
        Quest(
            id: "c8e567dc-e321-438f-9a30-33eb8ae06546",
            imageName: "sanoored",
            title: "Sanoored",
            description: "Enjoy the vibe along the shore of Sanur",
            points: 10,
            theme: .blue
        ),
        Quest(
            id: "gela-tour-quest",
            imageName: "traveling",
            title: "Gela-tour",
            description: "Gelato + Sanur weather = perfect summer",
            points: 10,
            theme: .red
        ),
        Quest(
            id: "little-stalls-quest",
            imageName: "gwk",
            title: "Little Stalls",
            description: "Go local by enjoying snacks from small businesses",
            points: 10,
            theme: .green
        )
    ]
    
    // MARK: - Body
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                imageCarousel
                content
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Color.white)
        .navigationBarBackButtonHidden(true)
        .task {
            await loadQuests()
        }
    }
    
    // MARK: - Image Carousel
    
    private var imageCarousel: some View {
        ZStack(alignment: .top) {
            VStack {
                Spacer()
                PageIndicator(currentPage: selectedImageIndex, totalPages: galleryImages.count)
                    .padding(.bottom, 20)
            }
            
            TabView(selection: $selectedImageIndex) {
                ForEach(Array(galleryImages.enumerated()), id: \.offset) { index, imageName in
                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                        .tag(index)
                        .clipped()
                }
            }
            .frame(height: 300)
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "arrow.left")
                        .foregroundColor(.black)
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .background(Color.white)
                        .clipShape(Circle())
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
        }
        .frame(height: 400)
    }
    
    // MARK: - Content
    
    private var content: some View {
        VStack(alignment: .leading, spacing: 20) {
            dragHandle

            titleSection
            
            RecommendedQuestCard(
                title: quests.first?.title ?? "Sanoored",
                subtitle: quests.first?.description ?? "Enjoy the vibe along the shore of Sanur",
                points: 10
            ) {
                let questId = quests.first?.id ?? "c8e567dc-e321-438f-9a30-33eb8ae06546"
                dismiss()
                onStartQuest?(questId)
            }
            
            VStack(spacing: 14) {
                ForEach(quests) { quest in
                    QuestRow(quest: quest) {
                        dismiss()
                        onStartQuest?(quest.id)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
        .background(
            Color.white
                .clipShape(RoundedCorner(radius: 28, corners: [.topLeft, .topRight]))
        )
        .offset(y: -130)
    }

    private var dragHandle: some View {
        Capsule()
            .fill(Color.gray.opacity(0.35))
            .frame(width: 44, height: 5)
            .padding(.top, 10)
            .frame(maxWidth: .infinity, alignment: .center)
    }
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top) {
                Text("\(kelurahan.kelurahanName) Quests")
                    .font(TransiumFont.display(28, weight: .bold))
                    .foregroundColor(.black)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Image("Beach")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 95, height: 30)
                    
                    Image("BusFee")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 95, height: 30)
                }
            }
            
            Text("\(kelurahan.kecamatanName) • Where earlybirds relax 🌊")
                .font(TransiumFont.body(15))
                .foregroundColor(.gray)
        }
    }
    
    // MARK: - Data Loading
    
    private func loadQuests() async {
        if !initialQuests.isEmpty {
            quests = initialQuests
            return
        }
        
        isLoadingQuests = true
        defer { isLoadingQuests = false }
        
        do {
            let detail = try await QuestService.shared.getKelurahanQuests(id: kelurahan.id)
            if !detail.quests.isEmpty {
                quests = detail.quests.enumerated().map { index, q in
                    let theme: QuestTheme = (index % 3 == 0) ? .blue : ((index % 3 == 1) ? .red : .green)
                    let imageName = q.badges.first?.badgeName.lowercased().contains("sanur") == true ? "sanoored" : "kintamani"
                    return Quest(
                        id: q.id,
                        imageName: imageName,
                        title: q.badges.first?.badgeName ?? q.name,
                        description: q.description,
                        points: 10,
                        theme: theme
                    )
                }
                return
            }
        } catch {
            // Fallback to defaults
        }
        
        quests = defaultQuests
    }
}

#Preview {
    DetailPlaceScreen()
}
