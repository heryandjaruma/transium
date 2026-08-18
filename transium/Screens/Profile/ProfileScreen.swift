//
//  Profile.swift
//  transium
//
//  Created by Abigail Metanoia Melody on 18/08/26.
//

import SwiftUI

struct ProfileScreen: View {
    enum ProfileTab: String, CaseIterable {
        case account = "Account"
        case badges = "Badges"
        case gallery = "Gallery"

        var icon: String {
            switch self {
            case .account: return "person.fill"
            case .badges: return "rosette"
            case .gallery: return "photo.on.rectangle"
            }
        }
    }

    struct GalleryPhoto: Identifiable, Equatable {
        let id = UUID()
        let imageName: String
    }

    struct Badge: Identifiable {
        let id = UUID()
        let imageName: String
        let title: String
        let date: String
        let borderColor: Color
    }

    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: ProfileTab = .gallery

    // Name editing
    @State private var userName: String = "IMDK"
    @State private var isEditingName: Bool = false
    @State private var editedName: String = ""

    // Account editing
    @State private var email: String = "imdk1827319@gmail.com"
    @State private var password: String = "123456"
    @State private var isEditingAccount: Bool = false
    @State private var editedEmail: String = ""
    @State private var editedPassword: String = ""

    // Gallery
    @State private var galleryPhotos: [GalleryPhoto] = [
        GalleryPhoto(imageName: "gallery-1"),
        GalleryPhoto(imageName: "gallery-2"),
        GalleryPhoto(imageName: "gallery-3"),
        GalleryPhoto(imageName: "gallery-4"),
        GalleryPhoto(imageName: "gallery-5"),
        GalleryPhoto(imageName: "gallery-6"),
        GalleryPhoto(imageName: "gallery-7"),
        GalleryPhoto(imageName: "gallery-8"),
        GalleryPhoto(imageName: "gallery-9")
    ]
    @State private var photoPendingDelete: GalleryPhoto? = nil
    @State private var showDeleteConfirmation: Bool = false
    @State private var viewingPhoto: GalleryPhoto? = nil

    // Badges
    private let badges: [Badge] = [
        Badge(imageName: "badge-sanoored", title: "Sanoored", date: "27 Aug 2026", borderColor: .black),
        Badge(imageName: "badge-meandu", title: "Me and U", date: "27 Aug 2026", borderColor: .red),
        Badge(imageName: "badge-uluwatu", title: "Uluwatu", date: "27 Aug 2026", borderColor: TransiumColor.primaryYellow),
        Badge(imageName: "badge-kintamani", title: "Kintamani", date: "27 Aug 2026", borderColor: .blue),
        Badge(imageName: "badge-gwk", title: "GWK", date: "27 Aug 2026", borderColor: .green),
        Badge(imageName: "badge-traveling", title: "Traveling", date: "27 Aug 2026", borderColor: .red)
    ]

    var body: some View {
        ZStack(alignment: .top) {
            TransiumColor.primaryBlue
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                tabBar

                ScrollView(showsIndicators: false) {
                    Group {
                        switch selectedTab {
                        case .account:
                            accountTab
                        case .badges:
                            badgesTab
                        case .gallery:
                            galleryTab
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
                .background(Color(.systemGray6))
            }
        }
        .navigationBarBackButtonHidden(true)
        .alert("Edit Name", isPresented: $isEditingName) {
            TextField("Name", text: $editedName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    userName = trimmed
                }
            }
        }
        .alert(
            "Delete Photo?",
            isPresented: $showDeleteConfirmation,
            presenting: photoPendingDelete
        ) { photo in
            Button("Delete", role: .destructive) {
                deletePhoto(photo)
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This photo will be removed from your gallery. This action can't be undone.")
        }
        .sheet(isPresented: $isEditingAccount) {
            editAccountSheet
        }
        .fullScreenCover(item: $viewingPhoto) { photo in
            PhotoViewer(imageName: photo.imageName) {
                viewingPhoto = nil
            }
        }
    }

    // MARK: - Header
    private var header: some View {
        VStack(spacing: 16) {
            ZStack {
                Text("Profile")
                    .font(TransiumFont.display(24, weight: .bold))
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
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            ZStack(alignment: .bottomTrailing) {
                Image("profile-avatar")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 130, height: 130)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 4))

                Button {
                    // hook up photo picker here later
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(width: 36, height: 36)
                        .background(Color.white)
                        .clipShape(Circle())
                }
                .offset(x: -4, y: -4)
            }

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Text(userName)
                        .font(TransiumFont.body(20, weight: .semibold))
                        .foregroundColor(.white)

                    Button {
                        editedName = userName
                        isEditingName = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }

                Label("Explorer", systemImage: "star.fill")
                    .font(TransiumFont.body(12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Capsule())
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: - Tab Bar
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(ProfileTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 14))
                            Text(tab.rawValue)
                                .font(TransiumFont.body(14, weight: .medium))
                        }
                        .foregroundColor(selectedTab == tab ? TransiumColor.primaryBlue : .gray)

                        Rectangle()
                            .fill(selectedTab == tab ? TransiumColor.primaryBlue : .clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 16)
        .background(
            Color(.systemGray6)
                .clipShape(RoundedCorner(radius: 28, corners: [.topLeft, .topRight]))
        )
    }

    // MARK: - Account Tab
    private var accountTab: some View {
        VStack(spacing: 0) {
            accountRow(icon: "envelope", label: "Email", value: email)
            Divider()
            accountRow(icon: "lock", label: "Password", value: String(repeating: "•", count: max(password.count, 6)))

            Spacer(minLength: 40)

            Button {
                editedEmail = email
                editedPassword = ""
                isEditingAccount = true
            } label: {
                Text("Edit Account")
                    .font(TransiumFont.body(16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.black)
                    .clipShape(Capsule())
            }
        }
    }

    private func accountRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 24)
            Text(label)
                .font(TransiumFont.body(14))
                .foregroundColor(.black)
            Spacer()
            Text(value)
                .font(TransiumFont.body(14, weight: .semibold))
                .foregroundColor(.black)
        }
        .padding(.vertical, 14)
    }

    // MARK: - Badges Tab
    private var badgesTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Your Badges")
                    .font(TransiumFont.body(16, weight: .semibold))
                    .foregroundColor(.black)
                Spacer()
                Text("\(badges.count) Badges")
                    .font(TransiumFont.body(13, weight: .medium))
                    .foregroundColor(TransiumColor.primaryBlue)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(badges) { badge in
                    VStack(spacing: 8) {
                        Image(badge.imageName)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 130)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(badge.borderColor, lineWidth: 3)
                            )
                            .onTapGesture {
                                // optional: open badge detail
                            }

                        Text(badge.title)
                            .font(TransiumFont.body(13, weight: .semibold))
                            .foregroundColor(.black)

                        Text(badge.date)
                            .font(TransiumFont.body(11))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }

    // MARK: - Gallery Tab
    private var galleryTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Adventure Moments")
                .font(TransiumFont.body(16, weight: .semibold))
                .foregroundColor(.black)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                spacing: 10
            ) {
                ForEach(galleryPhotos) { photo in
                    ZStack(alignment: .bottomTrailing) {
                        Image(photo.imageName)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 110)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .onTapGesture {
                                viewingPhoto = photo
                            }

                        Button {
                            photoPendingDelete = photo
                            showDeleteConfirmation = true
                        } label: {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                                .padding(6)
                                .background(Color.black.opacity(0.35))
                                .clipShape(Circle())
                        }
                        .padding(6)
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            photoPendingDelete = photo
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete Photo", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Edit Account Sheet
    private var editAccountSheet: some View {
        NavigationStack {
            Form {
                Section("Email") {
                    TextField("Email", text: $editedEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
                Section("New Password") {
                    SecureField("Leave blank to keep current password", text: $editedPassword)
                }
            }
            .navigationTitle("Edit Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isEditingAccount = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAccountChanges()
                    }
                }
            }
        }
    }

    // MARK: - Actions
    private func deletePhoto(_ photo: GalleryPhoto) {
        withAnimation {
            galleryPhotos.removeAll { $0.id == photo.id }
        }
        photoPendingDelete = nil
    }

    private func saveAccountChanges() {
        let trimmedEmail = editedEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedEmail.isEmpty {
            email = trimmedEmail
        }
        if !editedPassword.isEmpty {
            password = editedPassword
        }
        isEditingAccount = false
    }
}

// MARK: - Photo Viewer

private struct PhotoViewer: View {
    let imageName: String
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
            }
            .padding(.top, 50)
            .padding(.trailing, 20)
        }
    }
}

// MARK: - Rounded Corner Helper

private struct RoundedCorner: Shape {
    var radius: CGFloat = 25
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    ProfileScreen()
}
