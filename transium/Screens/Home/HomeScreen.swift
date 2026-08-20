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
    @Environment(\.scenePhase) private var scenePhase
    private let previewLocation: CLLocation?
    private let baliFallbackLocation = CLLocation(latitude: -8.73704, longitude: 115.17570)

    // MARK: - Journey State
    @State private var activeJourney: JourneyResult? = nil
    @State private var activeQuestId: String? = nil
    @State private var isFetchingJourney = false
    @State private var showNavigationSheet = false
    private let journeyService = JourneyService.shared

    // MARK: - Ongoing Trip State
    @State private var ongoingJourneyAttempt: JourneyAttempt? = nil
    @State private var ongoingJourneySteps: [JourneyAttemptStep] = []
    @State private var showOngoingTripCard = false
    @State private var isResumingOngoingTrip = false

    // MARK: - Go Mode State
    @StateObject private var geofenceMonitor = JourneyGeofenceMonitor()
    @State private var isStartingGoMode = false
    @State private var showGoMode = false
    @State private var goJourneyAttempt: JourneyAttempt? = nil
    @State private var goJourneySteps: [JourneyAttemptStep] = []
    @State private var goGeofences: [JourneyGeofence] = []
    @State private var goCurrentSegmentIndex = 0
    @State private var isCancelingJourney = false
    @State private var journeyConflict: JourneyStartConflictError? = nil
    @State private var isJourneyConflictPresented = false
    /// The raw POST /private/journey/go response, kept only when this Go Mode session actually
    /// started that way — nil when it was entered via `resumeOngoingTrip()` instead, since that
    /// path never hits /go. Backs GoTripDetailsPanel's debug "show /go response" button.
    @State private var goStartDebugResult: JourneyGoResult? = nil
    /// Set the instant a geofence fires for a `takePicture` checkpoint (see `handleGeofenceEntered`)
    /// — drives `CameraScreen`'s `.fullScreenCover(item:)` so the camera pops up immediately,
    /// including while the app was backgrounded when the region trigger came in (UIKit defers
    /// the presentation itself until the app is foreground again). `advanceJourney` still fires
    /// independently of this, since these steps are optional and don't require a photo to
    /// count as done.
    @State private var pendingPhotoStep: JourneyAttemptStep? = nil
    
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
            
            if let journey = activeJourney, showGoMode {
                // MARK: - Go Mode (real journey in progress)
                GoComponentMode(
                    journey: journey,
                    currentSegmentIndex: goCurrentSegmentIndex,
                    steps: goJourneySteps,
                    currentLocation: locationStore.currentLocation?.coordinate,
                    geofenceMonitor: geofenceMonitor,
                    goStartResult: goStartDebugResult,
                    onBack: { endGoMode() },
                    onEnd: { endGoMode(cancelAttempt: true) },
                    onLocate: { mapCenterRequestID += 1 },
                    onAdvanceSegment: {
//                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
//                            goCurrentSegmentIndex = min(goCurrentSegmentIndex + 1, journey.segments.count)
//                        }
                    }
                )
                .transition(.opacity)
            } else if let journey = activeJourney, showNavigationSheet {
                // MARK: - Navigation Mode
                VStack {
                    // Top Bar (Back, Bookmark, Share, Locate, Profile)
                    HStack {
                        TransiumIconButton(
                            systemName: "arrow.left",
                            accessibilityLabel: "Back",
                            size: 44
                        ) {
                            exitToExploreMode()
                        }
                        
                        Spacer()

                        HStack(spacing: 12) {
                            if goJourneyAttempt != nil {
                                TransiumIconButton(
                                    systemName: "xmark",
                                    accessibilityLabel: "Cancel journey",
                                    backgroundColor: TransiumColor.lightRed,
                                    foregroundColor: .white,
                                    size: 44
                                ) {
                                    cancelActiveJourneyAttempt()
                                }
                                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                                .disabled(isCancelingJourney)
                            }

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
                                icon: .asset("focus"),
                                accessibilityLabel: "Center map on route",
                                size: 44
                            ) {
                                mapCenterRequestID += 1
                            }
                            .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
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
                        Button(action: { startGoMode() }) {
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
                        .disabled(isStartingGoMode)
                        .padding(.trailing, 20)
                        .padding(.bottom, 16)
                    }
                    
                    NavigationBottomSheet(journey: journey, onBack: {
                        exitToExploreMode()
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

                    if showOngoingTripCard, let attempt = ongoingJourneyAttempt {
                        HStack {
                            OngoingTripCard(questName: attempt.questName ?? "Ongoing Trip") {
                                resumeOngoingTrip()
                            }
                            Spacer()
                        }
                        .padding(.top, 14)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                        .disabled(isResumingOngoingTrip)
                    }

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

            if isStartingGoMode || isFetchingJourney || isResumingOngoingTrip {
                LoadingScreen()
                    .transition(.opacity)
                    .zIndex(300)
            }
        }
        .task {
            locationStore.requestCurrentLocation()
            await fetchKelurahanGroups()
            await checkOngoingJourney()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            guard newPhase == .active, oldPhase == .background else { return }
            Task { await checkOngoingJourney() }
        }
        .preferredColorScheme(.light)
        .alert(
            "Journey Already in Progress",
            isPresented: $isJourneyConflictPresented,
            presenting: journeyConflict
        ) { conflict in
            if canResumeLocally(conflict) {
                Button("Resume Journey") { resumeCachedGoMode() }
            }
            Button("Cancel That Journey & Start This One", role: .destructive) {
                cancelConflictingAttemptAndRetry(conflict)
            }
            Button("Not Now", role: .cancel) { journeyConflict = nil }
        } message: { conflict in
            Text(conflict.message)
        }
        .fullScreenCover(item: $pendingPhotoStep) { step in
            CameraScreen(onCaptured: { image in
                await handlePhotoCaptured(image: image, step: step)
            })
        }
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
    
    private var resolvedCurrentLocation: CLLocation? {
        if let previewLocation {
            return previewLocation
        }
        if let currentLocation = locationStore.currentLocation, currentLocation.coordinate.isWithinBaliRegion {
            return currentLocation
        }
        return baliFallbackLocation
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
            
//            // "Do Quest" Button
//            Button(action: {
//                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
//                doQuest()
//            }) {
//                HStack(spacing: 10) {
//                    Image(systemName: "flag.fill")
//                        .font(.system(size: 16, weight: .bold))
//                    Text("Do Quest")
//                        .font(TransiumFont.body(16, weight: .bold))
//                }
//                .foregroundColor(.white)
//                .frame(maxWidth: .infinity)
//                .frame(height: 52)
//                .background(TransiumColor.primaryBlue)
//                .cornerRadius(26)
//                .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
//            }
//            .disabled(isFetchingJourney)
//            .padding(.horizontal, 20)
            
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
                let originCoordinate = resolvedCurrentLocation?.coordinate ?? CLLocationCoordinate2D(latitude: -8.702105, longitude: 115.176189)
                
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
                        activeQuestId = targetQuestId
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

    // MARK: - Ongoing Trip

    /// Leaves Navigation Mode back to Explore Mode (the actual home screen), then re-checks
    /// for an ongoing trip so the tab is showing again if one is still active — e.g. after
    /// backing all the way out from Go Mode's own "Back" (which only steps out to Navigation
    /// Mode, not Explore) without ending the trip.
    private func exitToExploreMode() {
        withAnimation(.spring()) {
            activeJourney = nil
            showNavigationSheet = false
        }
        Task { await checkOngoingJourney() }
    }

    /// Looks up GET /private/journey/current and shows/hides the ongoing-trip tab accordingly.
    /// Called on cold launch (via `.task`), whenever the app returns from the background
    /// (via `.onChange(of: scenePhase)`), and whenever the user navigates back to Explore Mode
    /// (via `exitToExploreMode`), so a trip started elsewhere (or left running in the
    /// background) is always picked back up. Skipped while already inside Go Mode or
    /// mid-resume, since in both cases the caller already knows about the active attempt.
    private func checkOngoingJourney() async {
        guard !showGoMode, !isResumingOngoingTrip else { return }

        do {
            let current = try await journeyService.getCurrentJourney()
            await MainActor.run {
                guard let attempt = current.journeyAttempt, attempt.status == "started" else {
                    ongoingJourneyAttempt = nil
                    ongoingJourneySteps = []
                    if showOngoingTripCard {
                        withAnimation(.easeInOut(duration: 0.2)) { showOngoingTripCard = false }
                    }
                    return
                }

                ongoingJourneyAttempt = attempt
                ongoingJourneySteps = current.steps
                if !showOngoingTripCard {
                    // Spring the tab in from off-screen left — the motion itself is the cue
                    // that the fetch just resolved and found something worth surfacing.
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                        showOngoingTripCard = true
                    }
                }
            }
        } catch {
            print("Failed to check current journey: \(error)")
        }
    }

    /// Resumes the trip surfaced by the ongoing-trip tab straight into Go Mode: replans the
    /// real path from the user's current position to the quest's destination, then re-registers
    /// geofences for whichever steps are still outstanding (built from the steps' own
    /// lat/lng/radius, since GET /current only returns steps, not the /go geofence list).
    private func resumeOngoingTrip() {
        guard !isResumingOngoingTrip, let attempt = ongoingJourneyAttempt, let questId = attempt.questId else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            isResumingOngoingTrip = true
        }

        Task {
            do {
                let originCoordinate = resolvedCurrentLocation?.coordinate ?? CLLocationCoordinate2D(latitude: -8.702105, longitude: 115.176189)
                let response = try await journeyService.fetchRealJourney(questId: questId, origin: originCoordinate)
                let resolvedJourney = await RoadGeometryResolver.shared.resolveJourneyGeometries(response.best)

                let geofences: [JourneyGeofence] = ongoingJourneySteps.compactMap { step in
                    guard step.status == .waiting, let lat = step.lat, let lng = step.lng, let radius = step.radiusMeters else { return nil }
                    return JourneyGeofence(stepId: step.id, sequence: step.sequence, lat: lat, lng: lng, radiusMeters: radius)
                }

                await MainActor.run {
                    geofenceMonitor.onRegionEntered = { [attemptId = attempt.id] stepId in
                        handleGeofenceEntered(stepId: stepId, attemptId: attemptId)
                    }
                    geofenceMonitor.startMonitoring(geofences: geofences)

                    activeJourney = resolvedJourney
                    activeQuestId = questId
                    goJourneyAttempt = attempt
                    goJourneySteps = ongoingJourneySteps
                    goGeofences = geofences
                    goCurrentSegmentIndex = 0
                    showOngoingTripCard = false
                    goStartDebugResult = nil

                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        showGoMode = true
                        showNavigationSheet = false
                        isResumingOngoingTrip = false
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        isResumingOngoingTrip = false
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    AppToastCenter.shared.showError(
                        title: "Couldn't Resume Trip",
                        message: (error as? TransiumAPIError)?.errorDescription ?? "Please try again."
                    )
                }
            }
        }
    }

    // MARK: - Go Mode

    private func startGoMode() {
        guard !isStartingGoMode, let questId = activeQuestId else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            isStartingGoMode = true
        }

        Task {
            do {
                let result = try await journeyService.startJourney(questId: questId)

                geofenceMonitor.onRegionEntered = { stepId in
                    handleGeofenceEntered(stepId: stepId, attemptId: result.journeyAttempt.id)
                }
                geofenceMonitor.startMonitoring(geofences: result.geofences)

                await MainActor.run {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    goJourneyAttempt = result.journeyAttempt
                    goJourneySteps = result.steps
                    goGeofences = result.geofences
                    goCurrentSegmentIndex = 0
                    goStartDebugResult = result
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        showGoMode = true
                        showNavigationSheet = false
                        isStartingGoMode = false
                    }
                }
            } catch let conflict as JourneyStartConflictError {
                await MainActor.run {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        isStartingGoMode = false
                    }
                    journeyConflict = conflict
                    isJourneyConflictPresented = true
                }
            } catch {
                await MainActor.run {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        isStartingGoMode = false
                    }
                    AppToastCenter.shared.showError(
                        title: "Couldn't Start Journey",
                        message: (error as? TransiumAPIError)?.errorDescription ?? "Please try again."
                    )
                }
            }
        }
    }

    /// True when the conflicting attempt is the one this screen already has cached
    /// (steps + geofences), so "Resume Journey" can re-enter Go Mode without a network call.
    private func canResumeLocally(_ conflict: JourneyStartConflictError) -> Bool {
        activeJourney != nil && goJourneyAttempt?.id == conflict.activeJourneyAttemptId
    }

    private func resumeCachedGoMode() {
        guard let attempt = goJourneyAttempt else { return }
        journeyConflict = nil

        geofenceMonitor.onRegionEntered = { [attemptId = attempt.id] stepId in
            handleGeofenceEntered(stepId: stepId, attemptId: attemptId)
        }
        geofenceMonitor.startMonitoring(geofences: goGeofences)

        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            showGoMode = true
            showNavigationSheet = false
        }
    }

    private func cancelConflictingAttemptAndRetry(_ conflict: JourneyStartConflictError) {
        journeyConflict = nil
        guard let attemptId = conflict.activeJourneyAttemptId else { return }

        Task {
            do {
                _ = try await journeyService.cancelJourney(attemptId: attemptId)
                await MainActor.run {
                    if goJourneyAttempt?.id == attemptId {
                        goJourneyAttempt = nil
                        goJourneySteps = []
                        goGeofences = []
                    }
                }
                startGoMode()
            } catch {
                await MainActor.run {
                    AppToastCenter.shared.showError(
                        title: "Couldn't Cancel",
                        message: (error as? TransiumAPIError)?.errorDescription ?? "Please try again."
                    )
                }
            }
        }
    }

    /// Leaves the live Go Mode UI, returning to the Navigation Mode overview of the same
    /// journey (the attempt keeps running server-side unless `cancelAttempt` is set).
    private func endGoMode(cancelAttempt: Bool = false) {
        geofenceMonitor.stopMonitoring()
        geofenceMonitor.onRegionEntered = nil
        pendingPhotoStep = nil

        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            showGoMode = false
            showNavigationSheet = true
            goCurrentSegmentIndex = 0
        }
        goStartDebugResult = nil

        if cancelAttempt {
            cancelActiveJourneyAttempt()
        }
    }

    /// Cancels the caller's in-progress journey attempt, if any — reachable from Go Mode's
    /// "End" button and from the cancel button in the Navigation Mode bar (e.g. after backing
    /// out of Go Mode without ending the attempt).
    private func cancelActiveJourneyAttempt() {
        guard let attempt = goJourneyAttempt, !isCancelingJourney else { return }
        isCancelingJourney = true

        Task {
            do {
                _ = try await journeyService.cancelJourney(attemptId: attempt.id)
                await MainActor.run {
                    goJourneyAttempt = nil
                    goJourneySteps = []
                    goGeofences = []
                    isCancelingJourney = false
                    AppToastCenter.shared.showSuccess(
                        title: "Journey Canceled",
                        message: "You can start a new quest anytime."
                    )
                }
            } catch {
                await MainActor.run {
                    isCancelingJourney = false
                    AppToastCenter.shared.showError(
                        title: "Couldn't Cancel",
                        message: (error as? TransiumAPIError)?.errorDescription ?? "Please try again."
                    )
                }
            }
        }
    }

    private func handleGeofenceEntered(stepId: String, attemptId: String) {
        guard let coordinate = locationStore.currentLocation?.coordinate ?? resolvedCurrentLocation?.coordinate else { return }

        // Pop the camera immediately, before the network round-trip below — a "takePicture"
        // checkpoint is a moment-in-time prompt, not something that should wait on `advance`.
        // Skip it if this step is already done (a re-firing region, or a previous catch-up
        // advance already covered it) so the user isn't nagged for the same spot twice.
        if let step = goJourneySteps.first(where: { $0.id == stepId }),
           step.isPhotoCheckpoint, step.status != .done {
            pendingPhotoStep = step
        }

        Task {
            guard let result = try? await journeyService.advanceJourney(
                attemptId: attemptId,
                stepId: stepId,
                lat: coordinate.latitude,
                lng: coordinate.longitude
            ) else { return }

            await MainActor.run {
                goJourneyAttempt = result.journeyAttempt
                goJourneySteps = result.steps
                if result.journeyAttempt.status == "completed" {
                    AppToastCenter.shared.showSuccess(
                        title: "Quest Complete!",
                        message: "You've finished every step of this journey."
                    )
                }
            }
        }
    }

    /// `CameraScreen`'s `onCaptured` for a `takePicture` checkpoint — uploads via POST
    /// /private/journey/media and closes the whole camera flow (`pendingPhotoStep = nil` tears
    /// down `CameraScreen` and its nested `PhotoPreviewScreen` cover together). On failure the
    /// flow is left open so the user can retry from the still-visible preview.
    private func handlePhotoCaptured(image: UIImage, step: JourneyAttemptStep) async {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            AppToastCenter.shared.showError(title: "Upload Failed", message: "Couldn't process that photo. Please try again.")
            return
        }

        do {
            _ = try await journeyService.uploadStepMedia(
                stepId: step.id,
                imageData: data,
                filename: "\(step.id).jpg",
                mimeType: "image/jpeg"
            )
            await MainActor.run {
                pendingPhotoStep = nil
                AppToastCenter.shared.showSuccess(
                    title: "Photo Saved",
                    message: "Added to your journey keepsakes."
                )
            }
        } catch {
            await MainActor.run {
                AppToastCenter.shared.showError(
                    title: "Upload Failed",
                    message: (error as? TransiumAPIError)?.errorDescription ?? "Please try again."
                )
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
                                    .padding(.leading, 12)
                                    .padding(.bottom, -1)
                                    .zIndex(1)
                            }
                            
                            TransiumTicketCard(
                                title: group.kelurahan.kelurahanName,
                                subtitle: group.quests.first?.description ?? "\(group.kelurahan.kecamatanName), Bali",
                                distance: "11 km",
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
                                    .padding(.leading, 12)
                                    .padding(.bottom, -1)
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
        if let loc = resolvedCurrentLocation {
            return String(format: "%.4f, %.4f", loc.coordinate.latitude, loc.coordinate.longitude)
        }
        return "Locating..."
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
