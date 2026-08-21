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
        let imageUrl: String?
        let fallbackImageName: String
        let title: String
        let description: String
        let points: Int
        let theme: QuestTheme
        
        init(
            id: String = UUID().uuidString,
            imageUrl: String? = nil,
            fallbackImageName: String = "sanoored",
            title: String,
            description: String,
            points: Int = 10,
            theme: QuestTheme = .blue
        ) {
            self.id = id
            self.imageUrl = imageUrl
            self.fallbackImageName = fallbackImageName
            self.title = title
            self.description = description
            self.points = points
            self.theme = theme
        }

        init(
            id: String = UUID().uuidString,
            imageName: String,
            title: String,
            description: String,
            points: Int = 10,
            theme: QuestTheme = .blue
        ) {
            self.init(
                id: id,
                imageUrl: nil,
                fallbackImageName: imageName,
                title: title,
                description: description,
                points: points,
                theme: theme
            )
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
        
        var background: Color {
            accent.opacity(0.10)
        }
    }
    
    // MARK: - Properties & State
    
    var kelurahan: Kelurahan = Kelurahan(id: "7760985", kelurahanName: "Benoa", kecamatanName: "Kuta Selatan")
    var initialQuests: [Quest] = []
    var onBack: (() -> Void)? = nil
    var onStartQuest: ((String) -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedImageIndex: Int = 0
    @State private var headerImageUrls: [String] = []
    @State private var quests: [Quest] = []
    @State private var isLoadingQuests: Bool = false
    
    private var isBenoa: Bool {
        kelurahan.kelurahanName.localizedCaseInsensitiveContains("benoa")
    }
    
    private var isUbud: Bool {
        kelurahan.kelurahanName.localizedCaseInsensitiveContains("ubud")
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    imageCarousel
                    content
                }
            }
            .ignoresSafeArea(edges: .top)
            
            // Top Floating Back Button (aligned with HomeScreen toolbar buttons)
            VStack {
                HStack {
                    Button {
                        dismissScreen()
                    } label: {
                        Image(systemName: "arrow.left")
                            .foregroundColor(.black)
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
                    }
                    .padding(.leading, 20)
                    .padding(.top, 6)
                    
                    Spacer()
                }
                
                Spacer()
            }
        }
        .background(Color.white)
        .navigationBarBackButtonHidden(true)
        .task {
            await loadQuests()
        }
    }
    
    private func dismissScreen() {
        if let onBack {
            onBack()
        } else {
            dismiss()
        }
    }
    
    // MARK: - Image Carousel
    private var imageCarousel: some View {
        ZStack(alignment: .bottom) {
            if isLoadingQuests && headerImageUrls.isEmpty {
                // Pure geometric header skeleton placeholder
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 340)
                    .transiumShimmer(
                        baseColor: Color(.systemGray5),
                        highlightColor: Color.white.opacity(0.7)
                    )
            } else {
                TabView(selection: $selectedImageIndex) {
                    if !headerImageUrls.isEmpty {
                        ForEach(Array(headerImageUrls.enumerated()), id: \.offset) { index, urlString in
                            let fullUrl = urlString.hasPrefix("http") ? urlString : "https://transium-api.heryandjaruma.workers.dev\(urlString)"
                            
                            GeometryReader { proxy in
                                AsyncImage(url: URL(string: fullUrl)) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: proxy.size.width, height: proxy.size.height)
                                            .clipped()
                                    case .empty:
                                        Rectangle()
                                            .fill(Color(.systemGray5))
                                            .frame(width: proxy.size.width, height: proxy.size.height)
                                            .transiumShimmer(
                                                baseColor: Color(.systemGray5),
                                                highlightColor: Color.white.opacity(0.7)
                                            )
                                    default:
                                        Rectangle()
                                            .fill(Color(.systemGray4))
                                            .frame(width: proxy.size.width, height: proxy.size.height)
                                    }
                                }
                            }
                            .tag(index)
                        }
                    } else {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 340)
                    }
                }
                .frame(height: 340)
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                if headerImageUrls.count > 1 {
                    PageIndicator(currentPage: selectedImageIndex, totalPages: headerImageUrls.count)
                        .padding(.bottom, 60)
                }
            }
        }
        .frame(height: 340)
        .animation(.easeInOut(duration: 0.35), value: isLoadingQuests)
    }
    
    // MARK: - Content
    
    private var content: some View {
        VStack(alignment: .leading, spacing: 20) {
            dragHandle

            titleSection
            
            if isLoadingQuests && quests.isEmpty {
                // Skeleton loading state with identical spacing structure
                RecommendedQuestCardSkeleton()
                
                VStack(spacing: 14) {
                    QuestRowSkeleton(theme: .blue)
                    QuestRowSkeleton(theme: .red)
                    QuestRowSkeleton(theme: .green)
                }
            } else {
                if let firstQuest = quests.first {
                    RecommendedQuestCard(
                        title: firstQuest.title,
                        subtitle: firstQuest.description,
                        imageUrl: firstQuest.imageUrl,
                        fallbackImageName: firstQuest.fallbackImageName,
                        points: firstQuest.points
                    ) {
                        dismissScreen()
                        onStartQuest?(firstQuest.id)
                    }
                }
                
                VStack(spacing: 14) {
                    ForEach(quests) { quest in
                        QuestRow(quest: quest) {
                            dismissScreen()
                            onStartQuest?(quest.id)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 36)
        .background(
            Color.white
                .clipShape(RoundedCorner(radius: 28, corners: [.topLeft, .topRight]))
        )
        .offset(y: -44)
    }

    private var dragHandle: some View {
        Capsule()
            .fill(Color.gray.opacity(0.35))
            .frame(width: 44, height: 5)
            .padding(.top, 12)
            .frame(maxWidth: .infinity, alignment: .center)
    }
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text("\(kelurahan.kelurahanName) Quests")
                    .font(TransiumFont.display(28, weight: .bold))
                    .foregroundColor(.black)
                
                Spacer()
                
                if isLoadingQuests {
                    HStack(spacing: 8) {
                        TransiumSkeletonBlock(
                            width: 95,
                            height: 30,
                            cornerRadius: 15,
                            color: Color.black.opacity(0.08),
                            shimmerHighlight: Color.white.opacity(0.6)
                        )
                        TransiumSkeletonBlock(
                            width: 95,
                            height: 30,
                            cornerRadius: 15,
                            color: Color.black.opacity(0.08),
                            shimmerHighlight: Color.white.opacity(0.6)
                        )
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(categoryBadgeImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 95, height: 30)
                        
                        Image("BusFee")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 95, height: 30)
                    }
                }
            }
            
            if isLoadingQuests {
                TransiumSkeletonBlock(
                    width: 210,
                    height: 18,
                    cornerRadius: 4,
                    color: Color.black.opacity(0.07),
                    shimmerHighlight: Color.white.opacity(0.55)
                )
            } else {
                Text("\(kelurahan.kecamatanName) • \(kelurahanTagline)")
                    .font(TransiumFont.body(14))
                    .foregroundColor(.gray)
            }
        }
    }
    
    private var categoryBadgeImage: String {
        if isBenoa { return "Beach" }
        if isUbud { return "kintamani" }
        return "Beach"
    }
    
    private var kelurahanTagline: String {
        if isBenoa { return "Where earlybirds relax 🌊" }
        if isUbud { return "Rice fields, art walks & mountain air 🌿" }
        return "Where earlybirds relax 🌊"
    }
    
    // MARK: - Data Loading
    
    private func loadQuests() async {
        if !initialQuests.isEmpty {
            quests = initialQuests
            headerImageUrls = initialQuests.compactMap { $0.imageUrl }
            return
        }
        
        isLoadingQuests = true
        defer { isLoadingQuests = false }
        
        do {
            let detail = try await QuestService.shared.getKelurahanQuests(id: kelurahan.id)
            if !detail.quests.isEmpty {
                // Collect header carousel thumbnails from all quests in this kelurahan
                let allThumbUrls = detail.quests.flatMap { $0.thumbnails.map { $0.url } }
                headerImageUrls = allThumbUrls
                
                var loaded: [Quest] = []
                for (index, q) in detail.quests.enumerated() {
                    let theme: QuestTheme = (index % 3 == 0) ? .blue : ((index % 3 == 1) ? .red : .green)
                    let thumbUrl = q.thumbnails.first?.url
                    let fallbackImg: String = {
                        let cat = q.category.lowercased()
                        if cat.contains("beach") || cat.contains("leisure") { return "Beach" }
                        if cat.contains("nature") { return "kintamani" }
                        if cat.contains("cult") { return "gwk" }
                        return "sanoored"
                    }()
                    
                    loaded.append(Quest(
                        id: q.id,
                        imageUrl: thumbUrl,
                        fallbackImageName: fallbackImg,
                        title: q.name,
                        description: "\(q.category) • \(q.description)",
                        points: 10,
                        theme: theme
                    ))
                }
                
                if !loaded.isEmpty {
                    quests = loaded
                    return
                }
            }
        } catch {
            print("Failed to load kelurahan quests: \(error)")
        }
    }
}

#Preview {
    DetailPlaceScreen()
}
