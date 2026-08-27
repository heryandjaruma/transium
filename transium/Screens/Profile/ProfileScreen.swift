//
//  Profile.swift
//  transium
//
//  Created by Abigail Metanoia Melody on 18/08/26.
//

import SwiftUI
import UIKit

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

    var onBack: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionController.self) private var session

    @State private var selectedTab: ProfileTab = .gallery

    // Remote profile
    @State private var profile: Profile?

    // Name editing
    @State private var userName: String = ""

    // Account editing
    @State private var email: String = ""
    @State private var isEditingAccount: Bool = false
    @State private var editedFirstName: String = ""
    @State private var editedLastName: String = ""
    @State private var isSavingAccount: Bool = false
    @State private var accountSaveError: String?
    @State private var showDeleteAccountConfirmation: Bool = false
    @State private var isDeletingAccount: Bool = false

    // Gallery
    @State private var galleryPhotos: [GalleryItem] = []
    @State private var galleryPagination: GalleryPagination?
    @State private var isLoadingGallery: Bool = false
    @State private var isLoadingMoreGallery: Bool = false
//    @State private var photoPendingDelete: GalleryItem? = nil
//    @State private var showDeleteConfirmation: Bool = false
    @State private var viewingPhoto: GalleryItem? = nil

    // Photo download (save to Photos library)
    @State private var isSavingPhoto: Bool = false
    @State private var showSaveResultAlert: Bool = false
    @State private var saveResultMessage: String = ""

    @State private var showPhotoSourceDialog = false
    @State private var activePickerSource: UIImagePickerController.SourceType?
    @State private var avatarImage: UIImage? = nil
    @State private var isUploadingAvatar: Bool = false
    @State private var isSettingsPresented: Bool = false

    // Badges
    @State private var earnedBadges: [EarnedBadge] = []
    @State private var isLoadingBadges: Bool = false

    private static let badgeDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()

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
                .safeAreaInset(edge: .bottom) {
                    if selectedTab == .account {
                        editAccountButton
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                            .background(Color(.systemGray6))
                    }
                }
            }

            if isSettingsPresented {
                SettingsScreen(onBack: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        isSettingsPresented = false
                    }
                })
                .transition(.move(edge: .trailing))
                .zIndex(200)
            }
        }
        .navigationBarBackButtonHidden(true)
        .task {
            await loadProfile()
        }
        .task {
            await loadGallery()
        }
        .task {
            await loadBadges()
        }
        .sheet(isPresented: $isEditingAccount) {
            editAccountSheet
        }
        .fullScreenCover(item: $viewingPhoto) { photo in
            PhotoViewer(
                imageURL: resolvedImageURL(photo.url),
                isSaving: isSavingPhoto,
                onClose: { viewingPhoto = nil },
                onDownload: { Task { await downloadPhoto(photo) } }
            )
        }
        .alert("Save Photo", isPresented: $showSaveResultAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveResultMessage)
        }
    }

    // MARK: - Remote Profile

    private func loadProfile() async {
        // Seed from the already-loaded session profile so the name isn't
        // blank while the network request for the full profile is in flight.
        if let sessionProfile = session.profile {
            userName = [sessionProfile.firstName, sessionProfile.lastName]
                .compactMap { $0 }
                .joined(separator: " ")
        }

        guard let userId = session.profile?.id else { return }

        do {
            let fetched = try await ProfileService.shared.getProfile(userId: userId)
            profile = fetched
            userName = fetched.fullName
            email = fetched.email ?? ""
        } catch {
            // Keep the placeholder values if the fetch fails; the user can
            // still browse the rest of the screen.
        }
    }

    // MARK: - Remote Gallery

    private func loadGallery() async {
        guard galleryPhotos.isEmpty else { return }
        isLoadingGallery = true
        defer { isLoadingGallery = false }

        do {
            let page = try await GalleryService.shared.listGallery(page: 1, limit: 30)
            galleryPhotos = page.media
            galleryPagination = page.pagination
        } catch {
            AppToastCenter.shared.showError(
                title: "Couldn't load gallery",
                message: "Please try again in a moment."
            )
        }
    }

    private func loadMoreGalleryIfNeeded() async {
        guard let pagination = galleryPagination, pagination.hasNextPage, !isLoadingMoreGallery else { return }
        isLoadingMoreGallery = true
        defer { isLoadingMoreGallery = false }

        do {
            let nextPage = try await GalleryService.shared.listGallery(page: pagination.page + 1, limit: pagination.limit)
            galleryPhotos.append(contentsOf: nextPage.media)
            galleryPagination = nextPage.pagination
        } catch {
            AppToastCenter.shared.showError(
                title: "Couldn't load more photos",
                message: "Please try again in a moment."
            )
        }
    }

    // MARK: - Remote Badges

    private func loadBadges() async {
        guard earnedBadges.isEmpty else { return }
        isLoadingBadges = true
        defer { isLoadingBadges = false }

        do {
            earnedBadges = try await BadgeService.shared.listEarnedBadges()
        } catch {
            AppToastCenter.shared.showError(
                title: "Couldn't load badges",
                message: "Please try again in a moment."
            )
        }
    }

    private func resolvedImageURL(_ raw: String) -> URL? {
        APIConfiguration.resolveURL(raw)
    }

    /// `earnedBadges` arrives most-recently-earned first, so this interpolates each badge's
    /// postage-frame from a faded, vintage sepia tone at the oldest end of the list to a vivid
    /// fresh blue at the newest — a color gradient across the whole collection rather than one
    /// fixed look, since the frame art is a template SVG that takes any tint.
    private func stampVariant(forBadgeAt index: Int) -> TransiumStampVariant {
        guard earnedBadges.count > 1 else { return .blue }
        let recency = 1 - (CGFloat(index) / CGFloat(earnedBadges.count - 1)) // 1 = most recent, 0 = oldest

        return TransiumStampVariant(
            frameColor: Self.vintageFrame.interpolated(to: Self.freshFrame, fraction: recency),
            paperColor: Self.vintagePaper.interpolated(to: Self.freshPaper, fraction: recency),
            shadowColor: Self.vintageShadow.interpolated(to: Self.freshShadow, fraction: recency),
            imageBackground: Self.vintageImageBackground.interpolated(to: Self.freshImageBackground, fraction: recency)
        )
    }

    private static let vintageFrame = Color(red: 0.93, green: 0.86, blue: 0.72)
    private static let freshFrame = Color(red: 0.74, green: 0.88, blue: 1.0)
    private static let vintagePaper = Color(red: 0.98, green: 0.95, blue: 0.87)
    private static let freshPaper = Color(red: 0.95, green: 0.98, blue: 1.0)
    private static let vintageImageBackground = Color(red: 0.87, green: 0.74, blue: 0.52)
    private static let freshImageBackground = Color(red: 0.74, green: 0.88, blue: 1.0)
    private static let vintageShadow = Color(red: 0.45, green: 0.32, blue: 0.12).opacity(0.22)
    private static let freshShadow = TransiumColor.ticketInk.opacity(0.18)

    private func presentEditAccount() {
        editedFirstName = profile?.firstName ?? ""
        editedLastName = profile?.lastName ?? ""
        accountSaveError = nil
        isEditingAccount = true
    }

    private func saveAccountChanges() async {
        guard let userId = session.profile?.id else { return }

        let trimmedFirstName = editedFirstName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFirstName.isEmpty else {
            accountSaveError = "First name can't be empty."
            return
        }

        let trimmedLastName = editedLastName.trimmingCharacters(in: .whitespacesAndNewlines)

        isSavingAccount = true
        accountSaveError = nil
        defer { isSavingAccount = false }

        do {
            let updated = try await ProfileService.shared.updateProfile(
                userId: userId,
                firstName: trimmedFirstName,
                lastName: trimmedLastName.isEmpty ? nil : trimmedLastName
            )
            profile = updated
            userName = updated.fullName
            isEditingAccount = false
        } catch {
            accountSaveError = "Couldn't save your changes. Please try again."
        }
    }

    // MARK: - Avatar

    private var hasAvatar: Bool {
        avatarImage != nil || profile?.image != nil
    }

    @ViewBuilder
    private var avatarView: some View {
        if let avatarImage {
            Image(uiImage: avatarImage)
                .resizable()
                .scaledToFill()
        } else if let imageURL = profile?.image.flatMap(resolvedImageURL) {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    avatarPlaceholder
                }
            }
        } else {
            avatarPlaceholder
        }
    }

    private var avatarPlaceholder: some View {
        ZStack {
            Color.white.opacity(0.25)
            Image(systemName: "person.fill")
                .font(.system(size: 64, weight: .medium))
                .foregroundColor(.white)
        }
    }

    private func uploadAvatar(_ image: UIImage) async {
        guard let imageData = await Task.detached(priority: .userInitiated, operation: {
            image.compressedJPEGData()
        }).value else {
            AppToastCenter.shared.showError(
                title: "Couldn't update photo",
                message: "That image couldn't be processed."
            )
            return
        }

        // Show the picked photo immediately; only revert if the upload fails.
        avatarImage = image
        isUploadingAvatar = true
        defer { isUploadingAvatar = false }

        do {
            let imagePath = try await ProfileService.shared.uploadAvatar(
                imageData: imageData,
                filename: "avatar.jpg",
                mimeType: "image/jpeg"
            )
            profile = updatingImage(on: profile, to: imagePath)
        } catch {
            avatarImage = nil
            AppToastCenter.shared.showError(
                title: "Couldn't update photo",
                message: "Please try again in a moment."
            )
        }
    }

    private func removeAvatar() async {
        isUploadingAvatar = true
        defer { isUploadingAvatar = false }

        do {
            try await ProfileService.shared.deleteAvatar()
            avatarImage = nil
            profile = updatingImage(on: profile, to: nil)
        } catch {
            AppToastCenter.shared.showError(
                title: "Couldn't remove photo",
                message: "Please try again in a moment."
            )
        }
    }

    private func updatingImage(on profile: Profile?, to image: String?) -> Profile? {
        guard let profile else { return nil }
        return Profile(
            id: profile.id,
            userId: profile.userId,
            firstName: profile.firstName,
            lastName: profile.lastName,
            level: profile.level,
            image: image,
            email: profile.email
        )
    }

    // MARK: - Header
    private var header: some View {
        VStack(spacing: 16) {
            ZStack {
                Text("Profile")
                    .font(TransiumFont.display(32, weight: .bold))
                    .foregroundColor(.white)

                HStack {
                    Button {
                        if let onBack {
                            onBack()
                        } else {
                            dismiss()
                        }
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

            ZStack(alignment: .bottomTrailing) {
                avatarView
                    .frame(width: 160, height: 160)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 6))

                Button {
                    showPhotoSourceDialog = true
                } label: {
                    Group {
                        if isUploadingAvatar {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundColor(.black)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .background(Color.white)
                    .clipShape(Circle())
                }
                .disabled(isUploadingAvatar)
                .offset(x: -4, y: -4)
                .confirmationDialog("Change profile photo", isPresented: $showPhotoSourceDialog, titleVisibility: .visible) {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button("Take Photo") {
                            activePickerSource = .camera
                        }
                    }
                    Button("Choose from Library") {
                        activePickerSource = .photoLibrary
                    }
                    if hasAvatar {
                        Button("Remove Photo", role: .destructive) {
                            Task {
                                await removeAvatar()
                            }
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                }
            }

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Text(userName)
                        .font(TransiumFont.body(20, weight: .semibold))
                        .foregroundColor(.white)
                }

                Label("Explorer", systemImage: "star.fill")
                    .font(TransiumFont.body(14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(TransiumColor.darkBlue.opacity(0.9))
                    .clipShape(Capsule())
            }
            .padding(.bottom, 20)
            .sheet(item: $activePickerSource) { source in
                ImagePicker(sourceType: source) { image in
                    Task {
                        await uploadAvatar(image)
                    }
                }
                .ignoresSafeArea()
            }
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
                                .font(.system(size: 17))
                            Text(tab.rawValue)
                                .font(TransiumFont.body(17, weight: .medium))
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
        VStack(spacing: 10) {
            accountRow(icon: "envelope", label: "Email", value: email)
        }
    }

    private var editAccountButton: some View {
        Button {
            presentEditAccount()
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
                    .font(TransiumFont.body(17, weight: .bold))
                    .foregroundColor(.black)
                Spacer()
                Text("\(earnedBadges.count) Badges")
                    .font(TransiumFont.body(17, weight: .bold))
                    .foregroundColor(TransiumColor.primaryBlue)
            }

            if isLoadingBadges && earnedBadges.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else if earnedBadges.isEmpty {
                Text("No badges yet — complete a quest to earn your first one.")
                    .font(TransiumFont.body(14))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 10
                ) {
                    ForEach(Array(earnedBadges.enumerated()), id: \.element.id) { index, badge in
                        VStack(spacing: 8) {
                            TransiumStampCard(
                                size: 92,
                                tilt: .degrees(index.isMultiple(of: 2) ? -3 : 3),
                                variant: stampVariant(forBadgeAt: index)
                            ) {
                                AsyncImage(url: badge.badgeImageUrl.flatMap(resolvedImageURL)) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    default:
                                        Image(systemName: "rosette")
                                            .resizable()
                                            .scaledToFit()
                                            .padding(10)
                                            .foregroundColor(.white.opacity(0.85))
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)

                            VStack(spacing: 0) {
                                Text(badge.badgeName)
                                    .font(TransiumFont.body(14, weight: .semibold))
                                    .foregroundColor(.black)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)

                                Text(Self.badgeDateFormatter.string(from: badge.earnedAt))
                                    .font(TransiumFont.body(11).weight(.medium))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Gallery Tab
    private var galleryTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Adventure Moments")
                .font(TransiumFont.body(17, weight: .semibold))
                .foregroundColor(.black)

            if isLoadingGallery && galleryPhotos.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else if galleryPhotos.isEmpty {
                Text("No photos yet — they'll show up here once you snap some on a quest.")
                    .font(TransiumFont.body(14))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 10
                ) {
                    ForEach(galleryPhotos) { photo in
                        ZStack(alignment: .bottomTrailing) {
                            AsyncImage(url: resolvedImageURL(photo.url)) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                case .empty:
                                    Rectangle().fill(Color(.systemGray5))
                                default:
                                    Rectangle().fill(Color(.systemGray4))
                                }
                            }
                            .frame(height: 145)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .clipped()
                            .onTapGesture {
                                viewingPhoto = photo
                            }

                            Button {
                                Task { await downloadPhoto(photo) }
                            } label: {
                                Image(systemName: "arrow.down.to.line")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(Color.black.opacity(0.35))
                                    .clipShape(Circle())
                            }
                            .padding(6)
                        }
                    }
                }

                if galleryPagination?.hasNextPage == true {
                    Button {
                        Task { await loadMoreGalleryIfNeeded() }
                    } label: {
                        HStack {
                            Spacer()
                            if isLoadingMoreGallery {
                                ProgressView()
                            } else {
                                Text("Load More")
                                    .font(TransiumFont.body(14, weight: .semibold))
                            }
                            Spacer()
                        }
                        .padding(.vertical, 12)
                    }
                    .disabled(isLoadingMoreGallery)
                }
            }
        }
    }

    // MARK: - Photo Download

    /// Downloads a gallery photo's raw bytes via `GET /private/gallery/{id}` and saves it into
    /// the user's Photos library.
    private func downloadPhoto(_ photo: GalleryItem) async {
        isSavingPhoto = true
        defer { isSavingPhoto = false }

        do {
            let data = try await GalleryService.shared.downloadPhoto(id: photo.id)
            guard let uiImage = UIImage(data: data) else {
                saveResultMessage = "Couldn't process that photo."
                showSaveResultAlert = true
                return
            }

            ImageSaver { success, error in
                if success {
                    saveResultMessage = "Saved to your Photos."
                } else if let error {
                    saveResultMessage = "Couldn't save the photo: \(error.localizedDescription)"
                } else {
                    saveResultMessage = "Couldn't save the photo. Check that Transium has permission to add photos in Settings."
                }
                showSaveResultAlert = true
            }.save(uiImage)
        } catch {
            saveResultMessage = "Couldn't download that photo. Please try again."
            showSaveResultAlert = true
        }
    }

    // MARK: - Edit Account Sheet
    private var editAccountSheet: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("First name", text: $editedFirstName)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)

                    TextField("Last name", text: $editedLastName)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)

                    if let accountSaveError {
                        Text(accountSaveError)
                            .font(TransiumFont.body(12))
                            .foregroundColor(.red)
                    }
                }

                Section("Email") {
                    Text(email)
                        .foregroundColor(.gray)
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteAccountConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            if isDeletingAccount {
                                ProgressView()
                            } else {
                                Text("Delete Account")
                            }
                            Spacer()
                        }
                    }
                    .disabled(isDeletingAccount)
                }
            }
            .navigationTitle("Edit Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        isEditingAccount = false
                    }
                    .disabled(isDeletingAccount)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await saveAccountChanges()
                        }
                    } label: {
                        if isSavingAccount {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(isSavingAccount || editedFirstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .confirmationDialog(
                "Delete Account?",
                isPresented: $showDeleteAccountConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Account", role: .destructive) {
                    deleteAccount()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action can't be undone. All your account data will be permanently deleted.")
            }
        }
    }

    private func deleteAccount() {
        Task {
            await performAccountDeletion()
        }
    }

    private func performAccountDeletion() async {
        isDeletingAccount = true
        defer { isDeletingAccount = false }

        do {
            try await AccountService.shared.deleteAccount()
            isEditingAccount = false
            // Clears the local token, unregisters the device's push token,
            // and flips the app back to signed-out — the account and all
            // its server-side data are already gone at this point.
            await session.signOut()
        } catch {
            AppToastCenter.shared.showError(
                title: "Couldn't delete account",
                message: "Please try again in a moment."
            )
        }
    }
}

// MARK: - Photo Viewer

private struct PhotoViewer: View {
    let imageURL: URL?
    let isSaving: Bool
    let onClose: () -> Void
    let onDownload: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                case .empty:
                    ProgressView()
                        .tint(.white)
                default:
                    Image(systemName: "photo")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                Button(action: onDownload) {
                    Group {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.down.to.line")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
                }
                .disabled(isSaving)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
            }
            .padding(.top, 50)
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Image Saver

/// Small helper that saves a UIImage into the user's Photos library and reports the result.
/// Requires an `NSPhotoLibraryAddUsageDescription` entry in Info.plist.
final class ImageSaver: NSObject {
    private let completion: (Bool, Error?) -> Void

    init(completion: @escaping (Bool, Error?) -> Void) {
        self.completion = completion
    }

    func save(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(didFinishSaving(_:didFinishSavingWithError:contextInfo:)), nil)
    }

    @objc private func didFinishSaving(
        _ image: UIImage,
        didFinishSavingWithError error: Error?,
        contextInfo: UnsafeRawPointer
    ) {
        completion(error == nil, error)
    }
}

// MARK: - Image Resize Helper

extension UIImage {
    nonisolated func resized(to targetSize: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

// MARK: - Color Interpolation Helper

extension Color {
    /// Linear RGBA interpolation toward `other`, `fraction` clamped to 0...1 — used to build a
    /// smooth color gradient across a collection (e.g. the badges grid's oldest-to-newest
    /// postage frame tint) rather than picking from a fixed palette.
    func interpolated(to other: Color, fraction: CGFloat) -> Color {
        let t = min(max(fraction, 0), 1)
        var (r1, g1, b1, a1): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var (r2, g2, b2, a2): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        UIColor(self).getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        UIColor(other).getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return Color(
            red: r1 + (r2 - r1) * t,
            green: g1 + (g2 - g1) * t,
            blue: b1 + (b2 - b1) * t,
            opacity: a1 + (a2 - a1) * t
        )
    }
}

// MARK: - Rounded Corner Helper

struct RoundedCorner: Shape {
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


extension UIImagePickerController.SourceType: @retroactive Identifiable {
    public var id: Int { rawValue }
}

struct ImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType
    var onImagePicked: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    ProfileScreen()
        .environment(SessionController())
}
