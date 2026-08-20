//
//  HomeScreen.swift
//  transium
//

import CoreLocation
import MapLibre
import SwiftUI

struct HomeScreen: View {
    @StateObject private var locationStore = LocationStore()
    @State private var visibleTicketPage: Int? = 0
    @State private var mapCenterRequestID = 0
    private let previewLocation: CLLocation?
    private let baliFallbackLocation = CLLocation(latitude: -8.73704, longitude: 115.17570)
    
    // MARK: - Journey State
    @State private var activeJourney: JourneyResult? = nil
    @State private var isFetchingJourney = false
    @State private var showNavigationSheet = false
    private let journeyService = JourneyService.shared
    
    // MARK: - Search & Profile State
    @State private var isSearchPresented = false
    @State private var isProfilePresented = false
    @State private var isDetailPresented = false
    @State private var isSettingsPresented = false
    @State private var isSavedQuestPresented = false
    @State private var isMenuExpanded = false
    @State private var sheetState: SearchSheetState = .searching
    @State private var sheetDetent: PresentationDetent = .large
    @State private var searchText = ""
    
    // MARK: - Kelurahan Quests State
    @State private var kelurahanGroups: [KelurahanQuestsGroup] = []
    @State private var selectedKelurahan: Kelurahan = Kelurahan(id: "7760985", kelurahanName: "Benoa", kecamatanName: "Kuta Selatan")
    
    init(previewLocation: CLLocation? = nil) {
        self.previewLocation = previewLocation
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            LocalBaliMapView(
                displayLocation: resolvedCurrentLocation,
                markerHeading: previewLocation == nil ? locationStore.currentHeading : 22,
                centerRequestID: mapCenterRequestID,
                activeJourney: activeJourney
            )
            .ignoresSafeArea()
            
            if isMenuExpanded {
                Color.clear
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isMenuExpanded = false
                        }
                    }
            }
            
            if let journey = activeJourney, showNavigationSheet {
                // MARK: - Navigation Mode
                VStack {
                    // Top Bar (Back, Bookmark, Share, Locate, Profile)
                    HStack {
                        TransiumIconButton(
                            systemName: "arrow.left",
                            accessibilityLabel: "Back",
                            size: 44
                        ) {
                            withAnimation(.spring()) {
                                activeJourney = nil
                                showNavigationSheet = false
                            }
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 12) {
                            TransiumIconButton(
                                systemName: "bookmark",
                                accessibilityLabel: "Save route",
                                size: 44
                            ) {
                                AppToastCenter.shared.showSuccess(title: "Saved", message: "Route bookmarked.")
                            }
                            .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                            
                            TransiumIconButton(
                                systemName: "square.and.arrow.up",
                                accessibilityLabel: "Share route",
                                size: 44
                            ) {
                                AppToastCenter.shared.showSuccess(title: "Shared", message: "Route link copied.")
                            }
                            .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                            
                            TransiumIconButton(
                                systemName: "location.fill",
                                accessibilityLabel: "Center on route",
                                size: 44
                            ) {
                                mapCenterRequestID += 1
                            }
                            .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                            
                            Button(action: {
                                isProfilePresented = true
                            }) {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundColor(TransiumColor.primaryBlue)
                                    .frame(width: 44, height: 44)
                                    .background(.white)
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                            }
                        }
                    }
                    .padding(.top, 6)
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
                
                // Docked Bottom Stack: Floating Go Button + Navigation Bottom Sheet
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Button(action: {
                            AppToastCenter.shared.showSuccess(
                                title: "Quest Started!",
                                message: "Follow the route to reach your destination."
                            )
                        }) {
                            HStack(spacing: 8) {
                                Text("Go")
                                    .font(TransiumFont.body(17, weight: .bold))
                                Image(systemName: "chevron.right.2")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(Color(red: 0.24, green: 0.65, blue: 0.44))
                            .cornerRadius(28)
                            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 16)
                    }
                    
                    NavigationBottomSheet(journey: journey, onBack: {
                        withAnimation(.spring()) {
                            activeJourney = nil
                            showNavigationSheet = false
                        }
                    })
                }
                .ignoresSafeArea(edges: .bottom)
                .transition(.move(edge: .bottom))
            } else {
                // MARK: - Explore Mode
                VStack(spacing: 0) {
                    // Top Search Bar, Locate, Quick Menu & Profile Controls
                    HStack(spacing: 10) {
//                        searchBarTrigger
                        quickMenu
                    }
                    .padding(.top, 6)
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    if !isSearchPresented {
                        bottomMapContent
                            .ignoresSafeArea(edges: .bottom)
                    }
                }
                
                // Pinning mode overlay controls
                if isSearchPresented && sheetState == .pinning {
                    pinningOverlayControls
                    centerPinIndicator
                }
            }
            
            if isDetailPresented {
                DetailPlaceScreen(
                    kelurahan: selectedKelurahan,
                    initialQuests: [],
                    onBack: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            isDetailPresented = false
                        }
                    },
                    onStartQuest: { questId in
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            isDetailPresented = false
                        }
                        doQuest(questId: questId)
                    }
                )
                .transition(.move(edge: .trailing))
                .zIndex(100)
            }
        }
        .task {
            locationStore.requestCurrentLocation()
            await fetchKelurahanGroups()
        }
        .preferredColorScheme(.light)
        .sheet(isPresented: $isSearchPresented, onDismiss: resetSheetState) {
            SearchSheetView(
                state: $sheetState,
                searchText: $searchText,
                onCancel: { isSearchPresented = false }
            )
            .presentationDetents([.medium, .large], selection: $sheetDetent)
            .presentationDragIndicator(.hidden)
            .interactiveDismissDisabled(false)
            .onChange(of: sheetDetent) { _, newDetent in
                sheetState = (newDetent == .large) ? .searching : .pinning
            }
        }
        .sheet(isPresented: $isProfilePresented) {
            ProfileScreen()
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsScreen()
        }
        .sheet(isPresented: $isSavedQuestPresented) {
            SavedQuestScreen()
        }
    }
    
    // MARK: - Three Dots
    
    private var quickMenu: some View {
        VStack(alignment: .trailing, spacing: 8) {
            TransiumIconButton(
                systemName: isMenuExpanded ? "xmark" : "ellipsis",
                accessibilityLabel: "Menu",
                size: 44
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    isMenuExpanded.toggle()
                }
            }
            .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
            
            if isMenuExpanded {
                TransiumIconButton(
                    systemName: "gearshape.fill",
                    accessibilityLabel: "Settings",
                    size: 44
                ) {
                    withAnimation { isMenuExpanded = false }
                    isSettingsPresented = true
                }
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                .transition(.scale.combined(with: .opacity))
                
                TransiumIconButton(
                    systemName: "person.crop.circle.fill",
                    accessibilityLabel: "Profile Button",
                    size: 44
                ) {
                    isProfilePresented = true
                }
                
                TransiumIconButton(
                    systemName: "bookmark.fill",
                    accessibilityLabel: "Saved quests",
                    size: 44
                ) {
                    withAnimation { isMenuExpanded = false }
                    isSavedQuestPresented = true
                }
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                .transition(.scale.combined(with: .opacity))
            }
            
            TransiumIconButton(
                icon: .asset("focus"),
                accessibilityLabel: "Center map on your location",
                size: 44
            ) {
                mapCenterRequestID += 1
            }
            .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    
    private func fetchKelurahanGroups() async {
        do {
            let groups = try await QuestService.shared.listKelurahanQuests()
            let validGroups = groups.filter { !$0.quests.isEmpty }
            if !validGroups.isEmpty {
                kelurahanGroups = validGroups
                if let first = validGroups.first {
                    selectedKelurahan = first.kelurahan
                }
            }
        } catch {
            print("Failed to fetch kelurahan quests: \(error)")
        }
    }
    
    private var resolvedCurrentLocation: CLLocation {
        if let previewLocation {
            return previewLocation
        }
        if let currentLocation = locationStore.currentLocation, currentLocation.coordinate.isWithinBaliRegion {
            return currentLocation
        }
        return baliFallbackLocation
    }

    private func coordinateForKelurahan(_ kelurahan: Kelurahan) -> CLLocation {
        switch kelurahan.id {
        case "7760985": // Benoa / Nusa Dua
            return CLLocation(latitude: -8.7981, longitude: 115.2185)
        case "20447626": // Ubud
            return CLLocation(latitude: -8.5069, longitude: 115.2625)
        case "20447290": // Panjer
            return CLLocation(latitude: -8.6783, longitude: 115.2312)
        case "20447300": // Dauh Puri Kaja
            return CLLocation(latitude: -8.6425, longitude: 115.2120)
        case "20447299": // Dauh Puri Kangin
            return CLLocation(latitude: -8.6578, longitude: 115.2185)
        case "20447275": // Sanur Kauh
            return CLLocation(latitude: -8.7050, longitude: 115.2500)
        case "20447277": // Sanur
            return CLLocation(latitude: -8.6882, longitude: 115.2635)
        default:
            let name = kelurahan.kelurahanName.lowercased()
            if name.contains("ubud") {
                return CLLocation(latitude: -8.5069, longitude: 115.2625)
            } else if name.contains("sanur") {
                return CLLocation(latitude: -8.6882, longitude: 115.2635)
            } else if name.contains("benoa") || name.contains("nusa dua") {
                return CLLocation(latitude: -8.7981, longitude: 115.2185)
            } else if name.contains("kuta") {
                return CLLocation(latitude: -8.7210, longitude: 115.1700)
            } else if name.contains("denpasar") || name.contains("panjer") || name.contains("dauh puri") {
                return CLLocation(latitude: -8.6705, longitude: 115.2126)
            }
            return CLLocation(latitude: -8.7021, longitude: 115.1762)
        }
    }

    private func distanceText(for group: KelurahanQuestsGroup) -> String {
        let destination = coordinateForKelurahan(group.kelurahan)
        let distanceInMeters = resolvedCurrentLocation.distance(from: destination)
        let km = distanceInMeters / 1000.0
        
        if km < 1.0 {
            let roundedMeters = max(50, Int(round(distanceInMeters / 50.0)) * 50)
            return "\(roundedMeters) m"
        } else if km < 10.0 {
            return String(format: "%.1f km", km)
        } else {
            return "\(Int(round(km))) km"
        }
    }
    
    // MARK: - Search Trigger
    
//    private var searchBarTrigger: some View {
//        Button(action: {
//            presentSearchSheet(in: .searching)
//        }) {
//            HStack(spacing: 12) {
//                Image(systemName: "magnifyingglass")
//                    .foregroundColor(.gray)
//                    .font(.system(size: 16, weight: .medium))
//                
//                Text(searchText.isEmpty ? "Where to?" : searchText)
//                    .font(TransiumFont.body(15))
//                    .foregroundColor(searchText.isEmpty ? .gray : .black)
//                    .lineLimit(1)
//                
//                Spacer()
//            }
//            .padding(.horizontal, 16)
//            .frame(height: 48)
//            .background(Color.white)
//            .cornerRadius(24)
//            .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
//        }
//        .accessibilityLabel("Search destinations")
//    }
    
    // MARK: - Pinning Overlay
    
    private var pinningOverlayControls: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: {
                    sheetDetent = .large
                    sheetState = .searching
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 14, weight: .bold))
                        Text("List")
                            .font(TransiumFont.body(14, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .background(Color.white)
                    .cornerRadius(22)
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                }
                
                Spacer()
                
                Button(action: {
                    AppToastCenter.shared.showSuccess(
                        title: "Location Pinned",
                        message: "Pinned destination selected."
                    )
                    sheetDetent = .large
                    sheetState = .searching
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                        Text("Confirm Pin")
                            .font(TransiumFont.body(14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .frame(height: 44)
                    .background(TransiumColor.primaryBlue)
                    .cornerRadius(22)
                    .shadow(color: TransiumColor.primaryBlue.opacity(0.4), radius: 6, y: 3)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 360)
        }
        .transition(.opacity)
    }
    
    private var centerPinIndicator: some View {
        VStack(spacing: 0) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 36))
                .foregroundColor(TransiumColor.primaryBlue)
                .background(Circle().fill(Color.white).padding(2))
                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
            
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 10))
                .foregroundColor(TransiumColor.primaryBlue)
                .offset(y: -3)
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }
    
    // MARK: - Bottom Ticket & Action Content
    
    private var bottomMapContent: some View {
        VStack(spacing: 12) {
            ticketRail
            ticketPageIndicator
            
            // "Do Quest" Button
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                doQuest()
            }) {
                HStack(spacing: 10) {
                    if isFetchingJourney {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                        Text("Planning Route...")
                            .font(TransiumFont.body(15, weight: .bold))
                    } else {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("Do Quest")
                            .font(TransiumFont.body(16, weight: .bold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    isFetchingJourney
                        ? TransiumColor.primaryBlue.opacity(0.85)
                        : TransiumColor.primaryBlue
                )
                .cornerRadius(26)
                .shadow(color: isFetchingJourney ? TransiumColor.primaryBlue.opacity(0.35) : .black.opacity(0.12), radius: 8, y: 4)
            }
            .disabled(isFetchingJourney)
            .padding(.horizontal, 20)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isFetchingJourney)
            
            currentLocationPill
        }
        .padding(.bottom, 20)
    }
    
    private func doQuest(questId: String? = nil) {
        guard !isFetchingJourney else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isFetchingJourney = true
        }
        
        Task {
            do {
                let originCoordinate = resolvedCurrentLocation.coordinate
                
                let targetQuestId: String? = {
                    if let questId { return questId }
                    let page = visibleTicketPage ?? 0
                    if kelurahanGroups.indices.contains(page) {
                        return kelurahanGroups[page].quests.first?.id
                    }
                    return kelurahanGroups.first?.quests.first?.id
                }()
                
                var response: JourneyResponse?
                
                // 1. Try real journey by questId if provided or discovered from kelurahan group
                if let targetQuestId {
                    response = try? await journeyService.fetchRealJourney(questId: targetQuestId, origin: originCoordinate)
                }
                
                // 2. Fallback to overview calculation if real journey failed
                if response == nil {
                    let destinationCoordinate = CLLocationCoordinate2D(latitude: -8.67368, longitude: 115.26337)
                    response = try await journeyService.fetchJourneyOverview(
                        origin: originCoordinate,
                        destination: destinationCoordinate
                    )
                }
                
                guard let validResponse = response else {
                    throw TransiumAPIError.serviceUnavailable("Unable to calculate route")
                }
                
                // Pre-resolve all road geometries concurrently before transitioning
                let resolvedJourney = await RoadGeometryResolver.shared.resolveJourneyGeometries(validResponse.best)
                
                await MainActor.run {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                        activeJourney = resolvedJourney
                        showNavigationSheet = true
                        isFetchingJourney = false
                    }
                }
            } catch {
                await MainActor.run {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isFetchingJourney = false
                    }
                    AppToastCenter.shared.showError(
                        title: "Route Calculation Failed",
                        message: "Could not plan a journey to this destination."
                    )
                }
            }
        }
    }
    
    private var ticketRail: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .bottom, spacing: 14) {
                if !kelurahanGroups.isEmpty {
                    ForEach(Array(kelurahanGroups.enumerated()), id: \.offset) { index, group in
                        let variant: TransiumTicketVariant = (index % 3 == 0) ? .blue : ((index % 3 == 1) ? .mint : .coral)
                        let isRecommended = (index == 0)
                        
                        VStack(alignment: .leading, spacing: 0) {
                            if isRecommended {
                                recommendedBadge
                                    .padding(.leading, 10)
                                    .padding(.bottom, -8)
                                    .zIndex(1)
                            }
                            
                            TransiumTicketCard(
                                title: group.kelurahan.kelurahanName,
                                subtitle: group.quests.first?.description ?? "\(group.kelurahan.kecamatanName), Bali",
                                distance: distanceText(for: group),
                                price: "Rp. 4,4k",
                                imageUrl: group.quests.first?.thumbnails.first?.url,
                                fallbackImageName: isRecommended ? "kintamani" : "Beach",
                                variant: variant
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    selectedKelurahan = group.kelurahan
                                    isDetailPresented = true
                                }
                            }
                        }
                        .frame(width: 336)
                        .id(index)
                    }
                } else {
                    // Fluid animated skeleton cards matching the exact layout and height bounds
                    ForEach(0..<2, id: \.self) { index in
                        let isRecommended = (index == 0)
                        let variant: TransiumTicketVariant = isRecommended ? .blue : .mint

                        VStack(alignment: .leading, spacing: 0) {
                            if isRecommended {
                                recommendedBadge
                                    .padding(.leading, 10)
                                    .padding(.bottom, -8)
                                    .zIndex(1)
                            }

                            TransiumTicketSkeletonCard(variant: variant)
                        }
                        .frame(width: 336)
                        .id(index)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.35), value: kelurahanGroups.isEmpty)
            .scrollTargetLayout()
            .padding(.horizontal, 20)
        }
        .frame(height: 190)
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $visibleTicketPage)
        .accessibilityLabel("Recommended destinations")
    }
    
    private var ticketPageIndicator: some View {
        PageIndicator(
            currentPage: visibleTicketPage ?? 0,
            totalPages: max(kelurahanGroups.count, 2),
            activeColor: TransiumColor.primaryBlue,
            inactiveColor: TransiumColor.ticketInk.opacity(0.26)
        )
        .accessibilityLabel("Ticket \(min((visibleTicketPage ?? 0) + 1, max(kelurahanGroups.count, 2))) of \(max(kelurahanGroups.count, 2))")
    }
    
    private var recommendedBadge: some View {
        TransiumRecommendedSeal(style: .ticketTab)
    }
    
    private var currentLocationPill: some View {
        HStack(spacing: 10) {
            Image(systemName: "location.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(TransiumColor.primaryBlue)
            
            Text("Your Current Location")
                .font(TransiumFont.body(14, weight: .semibold))
                .foregroundStyle(TransiumColor.ticketInk)
            
            Spacer()
            
            Text(currentLocationText)
                .font(TransiumFont.body(12, weight: .medium))
                .foregroundStyle(TransiumColor.ticketInk.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.92))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
        .padding(.horizontal, 20)
    }
    
    private var currentLocationText: String {
        String(format: "%.4f, %.4f", resolvedCurrentLocation.coordinate.latitude, resolvedCurrentLocation.coordinate.longitude)
    }
    
    private func presentSearchSheet(in state: SearchSheetState) {
        sheetState = state
        sheetDetent = (state == .searching) ? .large : .medium
        isSearchPresented = true
    }
    
    private func resetSheetState() {
        sheetState = .searching
        sheetDetent = .large
        searchText = ""
    }
}

#Preview {
    HomeScreen(previewLocation: CLLocation(latitude: -8.702105, longitude: 115.176189))
}
