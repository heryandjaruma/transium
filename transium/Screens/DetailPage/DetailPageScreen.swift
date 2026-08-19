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
        let id = UUID()
        let imageName: String
        let title: String
        let description: String
        let points: Int
        let theme: QuestTheme
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
    
    // MARK: - State
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedImageIndex: Int = 0
    
    private let galleryImages = ["gallery-1", "gallery-2", "gallery-3"]
    
    private let quests: [Quest] = [
        Quest(
            imageName: "kintamani",
            title: "Sanoored",
            description: "Enjoy the vibe along the shore of Sanur",
            points: 10,
            theme: .blue
        ),
        Quest(
            imageName: "traveling",
            title: "Gela-tour",
            description: "Gelato + Sanur weather = perfect summer",
            points: 10,
            theme: .red
        ),
        Quest(
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
            RecommendedQuestCard()
            
            VStack(spacing: 14) {
                ForEach(quests) { quest in
                    QuestRow(quest: quest)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
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
                Text("Sanur Street")
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
            
            Text("Where earlybirds relax 🌊")
                .font(TransiumFont.body(15))
                .foregroundColor(.gray)
        }
    }
    
    private func tagPill(icon: String, text: String, color: Color, multiline: Bool = false) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(TransiumFont.body(11, weight: .semibold))
                .multilineTextAlignment(.center)
                .lineLimit(multiline ? 2 : 1)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color)
        .clipShape(Capsule())
    }
    
}



#Preview {
    DetailPlaceScreen()
}
