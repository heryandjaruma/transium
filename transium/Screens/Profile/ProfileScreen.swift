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
    @State private var isEditingAccount: Bool = false
    @State private var showDeleteAccountConfirmation: Bool = false

    // Gallery
    @State private var galleryPhotos: [GalleryPhoto] = [
        GalleryPhoto(imageName: "gallery-1"),
        GalleryPhoto(imageName: "gallery-2"),
        GalleryPhoto(imageName: "gallery-3"),
    ]
//    @State private var photoPendingDelete: GalleryPhoto? = nil
//    @State private var showDeleteConfirmation: Bool = false
    @State private var likedPhotoIDs: Set<UUID> = []
    @State private var viewingPhoto: GalleryPhoto? = nil

    // Photo download (save to Photos library)
    @State private var isSavingPhoto: Bool = false
    @State private var showSaveResultAlert: Bool = false
    @State private var saveResultMessage: String = ""

    @State private var showPhotoSourceDialog = false
    @State private var activePickerSource: UIImagePickerController.SourceType?
    @State private var avatarImage: UIImage? = nil

    // Badges
    private let badges: [Badge] = [
        Badge(imageName: "sanoored", title: "Sanoored", date: "27 Aug 2026", borderColor: .black),
        Badge(imageName: "kintamani", title: "Kintamani", date: "27 Aug 2026", borderColor: .blue),
        Badge(imageName: "gwk", title: "GWK", date: "27 Aug 2026", borderColor: .green),
        Badge(imageName: "traveling", title: "Traveling", date: "27 Aug 2026", borderColor: .red)
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
                .safeAreaInset(edge: .bottom) {
                    if selectedTab == .account {
                        editAccountButton
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                            .background(Color(.systemGray6))
                    }
                }
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
        .sheet(isPresented: $isEditingAccount) {
            editAccountSheet
        }
        .fullScreenCover(item: $viewingPhoto) { photo in
            PhotoViewer(
                imageName: photo.imageName,
                isSaving: isSavingPhoto,
                onClose: { viewingPhoto = nil },
                onDownload: { downloadPhoto(photo) }
            )
        }
        .alert("Save Photo", isPresented: $showSaveResultAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveResultMessage)
        }
    }

    // MARK: - Header
    private var header: some View {
        VStack(spacing: 16) {
            ZStack {
                Text("Profile")
                    .font(TransiumFont.display(27, weight: .bold))
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
                Group {
                    if let avatarImage {
                        Image(uiImage: avatarImage)
                            .resizable()
                    } else {
                        Image("profile_avatar")
                            .resizable()
                    }
                }
                .scaledToFill()
                .frame(width: 160, height: 160)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 6))

                Button {
                    showPhotoSourceDialog = true
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(width: 44, height: 44)
                        .background(Color.white)
                        .clipShape(Circle())
                }
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
                    Button("Cancel", role: .cancel) {}
                }
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
                    .font(TransiumFont.body(14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.darkBlue.opacity(0.9))
                    .clipShape(Capsule())
            }
            .padding(.bottom, 20)
            .sheet(item: $activePickerSource) { source in
                ImagePicker(sourceType: source) { image in
                    avatarImage = image
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
                Text("\(badges.count) Badges")
                    .font(TransiumFont.body(17, weight: .bold))
                    .foregroundColor(TransiumColor.primaryBlue)
            }

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                spacing: 10
            ) {
                ForEach(badges) { badge in
                    VStack(spacing: 8) {
                        Image(badge.imageName)
                            .resizable()
                            .scaledToFill()
                            .aspectRatio(1, contentMode: .fill)   // square, bukan .infinity
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .clipped()
                            .onTapGesture {
                                // optional: open badge detail
                            }

                        VStack(spacing: 0) {
                            Text(badge.title)
                                .font(TransiumFont.body(14, weight: .semibold))
                                .foregroundColor(.black)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)

                            Text(badge.date)
                                .font(TransiumFont.body(11).weight(.medium))
                                .foregroundColor(.gray)
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

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                spacing: 10
            ) {
                ForEach(galleryPhotos) { photo in
                    ZStack(alignment: .bottomTrailing) {
                        Image(photo.imageName)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 145)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .onTapGesture {
                                viewingPhoto = photo
                            }

                        Button {
                            downloadPhoto(photo)
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
        }
    }

    private func toggleLike(for photo: GalleryPhoto) {
        if likedPhotoIDs.contains(photo.id) {
            likedPhotoIDs.remove(photo.id)
        } else {
            likedPhotoIDs.insert(photo.id)
        }
    }

    // MARK: - Photo Download

    /// Saves a gallery photo (by asset name) into the user's Photos library.
    private func downloadPhoto(_ photo: GalleryPhoto) {
        guard let uiImage = UIImage(named: photo.imageName) else {
            saveResultMessage = "Couldn't find that photo to download."
            showSaveResultAlert = true
            return
        }

        isSavingPhoto = true
        ImageSaver { success, error in
            isSavingPhoto = false
            if success {
                saveResultMessage = "Saved to your Photos."
            } else if let error {
                saveResultMessage = "Couldn't save the photo: \(error.localizedDescription)"
            } else {
                saveResultMessage = "Couldn't save the photo. Check that Transium has permission to add photos in Settings."
            }
            showSaveResultAlert = true
        }.save(uiImage)
    }

    // MARK: - Edit Account Sheet
    private var editAccountSheet: some View {
        NavigationStack {
            Form {
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
                            Text("Delete Account")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        isEditingAccount = false
                    }
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
        // TODO: hook this up to the real account-deletion API call.
        isEditingAccount = false
        dismiss()
    }
}

// MARK: - Photo Viewer

private struct PhotoViewer: View {
    let imageName: String
    let isSaving: Bool
    let onClose: () -> Void
    let onDownload: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            Image(imageName)
                .resizable()
                .scaledToFit()
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
}
