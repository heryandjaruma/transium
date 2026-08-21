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
    /// Backs the real step count/calories submitted to POST /private/journey/{id}/complete —
    /// see `finishJourneyIfNeeded`. Held here (rather than constructed inline) so its
    /// `HKHealthStore` is created once per Go Mode session instead of on every view update.
    @State private var healthKitStepService = HealthKitStepService()
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
    /// Set the instant a geofence fires for a photo-capture step (see `handleGeofenceEntered`,
    /// `JourneyAttemptStep.isPhotoCheckpoint`) — drives `CameraScreen`'s
    /// `.fullScreenCover(item:)` so the camera pops up immediately, including while the app was
    /// backgrounded when the region trigger came in (UIKit defers the presentation itself
    /// until the app is foreground again). `advanceJourney` still fires independently of this
    /// — arrival alone marks the step done regardless of whether a photo actually gets taken.
    @State private var pendingPhotoStep: JourneyAttemptStep? = nil
    /// The device's recorded breadcrumb for the current Go Mode session — submitted as `path`
    /// in POST /private/journey/{id}/complete. Appended to on every live location update while
    /// Go Mode is active (LocationStore already throttles those to real ~5m movement), reset at
    /// the start of a fresh/replanned session, left alone across a same-session conflict-resume.
    @State private var goPathBreadcrumb: [JourneyPathPointInput] = []
    /// Guards against submitting POST /private/journey/{id}/complete more than once per attempt
    /// — every step reaching "done" is detected from each /advance response, which can fire
    /// more than once in a row (e.g. two geofences resolving close together).
    @State private var hasSubmittedJourneyCompletion = false
    /// Set once POST /private/journey/{id}/complete succeeds — drives
    /// JourneyCompletionSummaryScreen's `.fullScreenCover(item:)`.
    @State private var journeyCompletionResult: JourneyCompleteResult? = nil
    /// A second, independent geofence layer for `RandomPhotoOpPlanner`'s spontaneous keepsake
    /// points — deliberately separate from `geofenceMonitor` so this purely-cosmetic feature
    /// can never call `advanceJourney` or otherwise touch real quest-step progress.
    @StateObject private var randomPhotoOpMonitor = JourneyGeofenceMonitor()
    @State private var isRandomPhotoOpPresented = false

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
    /// A manually chosen "current location" — from the search sheet's pinning flow — that
    /// `resolvedCurrentLocation` prefers over real GPS everywhere (map display, journey
    /// planning). `nil` means "use real GPS," the default. Deliberately app-wide per product
    /// intent, but Go Mode itself refuses to start while this is set (see `startGoMode`) since
    /// its whole geofence-tracking mechanism assumes the user is actually where they say they
    /// are.
    @State private var manualLocationOverride: CLLocationCoordinate2D?
    @State private var manualLocationOverrideLabel: String?
    /// Drives the "Go requires your real location" alert `startGoMode` shows when
    /// `manualLocationOverride` is set.
    @State private var isLocationOverrideBlockingGoPresented = false
    /// A coordinate to animate the map's pin-drop camera to once — set when entering pinning
    /// mode (a picked search result, or the pinning overlay's own locate button), read by
    /// `LocalBaliMapView.pinFocusCoordinate`.
    @State private var pinFocusCoordinate: CLLocationCoordinate2D?
    /// The map's live center coordinate while pinning, reported by
    /// `LocalBaliMapView.onPinCenterChanged` as the user drags — what "Set Starting Point"
    /// actually captures.
    @State private var pinnedCoordinate: CLLocationCoordinate2D?
    @State private var pinnedAddressLabel = "Locating address..."
    /// Debounces `pinnedCoordinate` changes into a GET /maps/reverse-geocode call — cancelled
    /// and restarted on every drag update rather than firing one per frame.
    @State private var reverseGeocodeTask: Task<Void, Never>?

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
                activeJourney: activeJourney,
                checkpoints: goGeofences,
                isGoMode: showGoMode,
                isPinning: isSearchPresented && sheetState == .pinning,
                pinFocusCoordinate: pinFocusCoordinate,
                onPinCenterChanged: { coordinate in
                    pinnedCoordinate = coordinate
                    scheduleReverseGeocode(for: coordinate)
                }
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
                    onManualAdvance: { stepId in
                        guard let attemptId = goJourneyAttempt?.id else { return }
                        handleGeofenceEntered(stepId: stepId, attemptId: attemptId, isManualConfirmation: true)
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
        .onChange(of: locationStore.currentLocation?.coordinate.latitude) { _, _ in
            recordPathPointIfNeeded()
            advanceGoSegmentIfNeeded()
        }
        .onChange(of: locationStore.currentLocation?.coordinate.longitude) { _, _ in
            recordPathPointIfNeeded()
            advanceGoSegmentIfNeeded()
        }
        // A mission segment only advances once its matched step reaches `.done` (see
        // `advanceGoSegmentIfNeeded`), which happens here — via `handleGeofenceEntered`
        // updating `goJourneySteps` — rather than through a location change.
        .onChange(of: goJourneySteps) { _, _ in advanceGoSegmentIfNeeded() }
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
        .alert(
            "Go Requires Your Real Location",
            isPresented: $isLocationOverrideBlockingGoPresented
        ) {
            Button("Use My Current Location") {
                manualLocationOverride = nil
                manualLocationOverrideLabel = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You're viewing the map from a manually set location. Switch back to your real location to start this journey.")
        }
        .fullScreenCover(item: $pendingPhotoStep) { step in
            CameraScreen(onCaptured: { image in
                await handlePhotoCaptured(image: image, step: step)
            })
        }
        .fullScreenCover(isPresented: $isRandomPhotoOpPresented) {
            CameraScreen(onCaptured: { image in
                await handleRandomPhotoOpCaptured(image: image)
            })
        }
        .fullScreenCover(item: $journeyCompletionResult) { result in
            JourneyCompletionSummaryScreen(result: result, onDismiss: {
                journeyCompletionResult = nil
                endGoMode()
            })
        }
        .sheet(isPresented: $isSearchPresented, onDismiss: resetSheetState) {
            SearchSheetView(
                state: $sheetState,
                searchText: $searchText,
                pinnedAddressLabel: pinnedAddressLabel,
                onSelectLocation: { coordinate, label in
                    beginPinning(at: coordinate, label: label)
                },
                onConfirmStartingPoint: {
                    manualLocationOverride = pinnedCoordinate
                    manualLocationOverrideLabel = pinnedAddressLabel
                    isSearchPresented = false
                },
                onUseCurrentLocation: {
                    manualLocationOverride = nil
                    manualLocationOverrideLabel = nil
                    isSearchPresented = false
                },
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
        if let manualLocationOverride {
            return CLLocation(latitude: manualLocationOverride.latitude, longitude: manualLocationOverride.longitude)
        }
        if let currentLocation = locationStore.currentLocation, currentLocation.coordinate.isWithinBaliRegion {
            return currentLocation
        }
        return baliFallbackLocation
    }

    /// Appends the device's live position to `goPathBreadcrumb` while Go Mode is active —
    /// LocationStore already throttles updates to real ~5m movement, so no extra dedup is
    /// needed here. Submitted as `path` in POST /private/journey/{id}/complete.
    private func recordPathPointIfNeeded() {
        guard showGoMode, let coordinate = locationStore.currentLocation?.coordinate else { return }
        goPathBreadcrumb.append(JourneyPathPointInput(lat: coordinate.latitude, lng: coordinate.longitude, recordedAt: Date()))
        // Defensive cap — a very long or backtracking session shouldn't grow this unboundedly.
        if goPathBreadcrumb.count > 2000 {
            goPathBreadcrumb.removeFirst(goPathBreadcrumb.count - 2000)
        }
    }

    /// How close the live position needs to be to a travel leg's destination before Go Mode
    /// treats it as reached — matches `GoComponentMode.busStopProximityMeters`, which uses the
    /// same distance for the symmetric "still at the boarding stop, or already riding" check
    /// within whichever leg is already current.
    private static let segmentArrivalProximityMeters: Double = 69

    /// Moves `goCurrentSegmentIndex` on to the next segment once the current one is reached —
    /// live-position proximity to `to` for a travel leg (e.g. reaching a bus's alighting stop,
    /// or a walk's endpoint), or the matched `JourneyAttemptStep` reaching `.done` for a mission
    /// (missions have no `to` to arrive at; their own location is instead confirmed via
    /// `GoMissionCard`'s "I'm here" → `handleGeofenceEntered`). This is the only place
    /// `goCurrentSegmentIndex` changes; there used to be a manual tap-to-advance on the
    /// walking-leg card, but it only ever covered walk legs (bus legs were never tappable) and
    /// was disabled outright, leaving the whole itinerary frozen on segment 0 for the rest of
    /// the trip once boarded.
    private func advanceGoSegmentIfNeeded() {
        guard showGoMode, let journey = activeJourney,
              journey.segments.indices.contains(goCurrentSegmentIndex) else { return }

        let segment = journey.segments[goCurrentSegmentIndex]

        if segment.isMission {
            guard goJourneySteps.attemptStep(for: segment)?.status == .done else { return }
            goCurrentSegmentIndex += 1
            return
        }

        guard let coordinate = locationStore.currentLocation?.coordinate,
              let distance = segment.liveRemaining(from: coordinate).distanceMeters,
              distance <= Self.segmentArrivalProximityMeters else { return }
        goCurrentSegmentIndex += 1
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
        VStack(spacing: 12) {
            HStack {
                Button(action: { isSearchPresented = false }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(width: 44, height: 44)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                }

                Spacer()

                Button(action: {
                    guard let coordinate = locationStore.currentLocation?.coordinate else { return }
                    pinFocusCoordinate = coordinate
                }) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(width: 44, height: 44)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                }
            }
            .padding(.horizontal, 20)

            HStack(spacing: 8) {
                Image(systemName: "hand.draw.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text("Drag the point anywhere on the map.")
                    .font(TransiumFont.body(13, weight: .semibold))
            }
            .foregroundColor(TransiumColor.primaryBlue)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.95))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.1), radius: 6, y: 2)

            Spacer()
        }
        .padding(.top, 6)
        .transition(.opacity)
    }
    
    private var centerPinIndicator: some View {
        VStack(spacing: 0) {
            Image("location_red")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)

            Ellipse()
                .fill(Color.black.opacity(0.2))
                .frame(width: 14, height: 4)
                .offset(y: -4)
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
        Task { await healthKitStepService.requestAuthorization() }

        Task {
            do {
                let originCoordinate = resolvedCurrentLocation?.coordinate ?? CLLocationCoordinate2D(latitude: -8.702105, longitude: 115.176189)
                // Authenticated + scoped to this attempt, so mission segments/steps come back
                // with an exact `stepId` join key instead of none at all.
                let response = try await journeyService.fetchRealJourney(questId: questId, origin: originCoordinate, journeyAttemptId: attempt.id)
                let resolvedJourney = await RoadGeometryResolver.shared.resolveJourneyGeometries(response.best)

                let geofences = geofences(from: ongoingJourneySteps)

                await MainActor.run {
                    geofenceMonitor.onRegionEntered = { [attemptId = attempt.id] stepId in
                        handleGeofenceEntered(stepId: stepId, attemptId: attemptId)
                    }
                    geofenceMonitor.startMonitoring(geofences: geofences)
                    setupRandomPhotoOps(for: resolvedJourney)

                    activeJourney = resolvedJourney
                    activeQuestId = questId
                    goJourneyAttempt = attempt
                    goJourneySteps = ongoingJourneySteps
                    goGeofences = geofences
                    goCurrentSegmentIndex = 0
                    showOngoingTripCard = false
                    goStartDebugResult = nil
                    goPathBreadcrumb = []
                    hasSubmittedJourneyCompletion = false

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
        // Go Mode's whole geofence-tracking mechanism assumes the device's real GPS position
        // is where the journey actually is — starting it from a manually overridden "current
        // location" would plan (and try to track) a trip the user was never physically on.
        guard manualLocationOverride == nil else {
            isLocationOverrideBlockingGoPresented = true
            return
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            isStartingGoMode = true
        }
        Task { await healthKitStepService.requestAuthorization() }

        Task {
            do {
                let result = try await journeyService.startJourney(questId: questId)

                geofenceMonitor.onRegionEntered = { stepId in
                    handleGeofenceEntered(stepId: stepId, attemptId: result.journeyAttempt.id)
                }
                geofenceMonitor.startMonitoring(geofences: result.geofences)

                // `activeJourney` so far is from the pre-/go preview fetch (no attempt existed
                // yet, so mission segments/steps came back with no `stepId`). Re-fetch now that
                // an attempt exists, so the rest of the session has the exact join key instead
                // of relying on coordinate-matching. Best-effort — if it fails, Go Mode still
                // works fine off the existing `activeJourney`, just without `stepId` on missions.
                let originCoordinate = resolvedCurrentLocation?.coordinate ?? CLLocationCoordinate2D(latitude: -8.702105, longitude: 115.176189)
                if let response = try? await journeyService.fetchRealJourney(
                    questId: questId,
                    origin: originCoordinate,
                    journeyAttemptId: result.journeyAttempt.id
                ) {
                    let resolvedJourney = await RoadGeometryResolver.shared.resolveJourneyGeometries(response.best)
                    await MainActor.run { activeJourney = resolvedJourney }
                }

                await MainActor.run {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    goJourneyAttempt = result.journeyAttempt
                    goJourneySteps = result.steps
                    goGeofences = result.geofences
                    goCurrentSegmentIndex = 0
                    goStartDebugResult = result
                    goPathBreadcrumb = []
                    hasSubmittedJourneyCompletion = false
                    // Whichever journey ended up in `activeJourney` — the fresh re-fetch above,
                    // or the original pre-/go preview if that failed — has valid route
                    // geometry either way, which is all this needs.
                    if let activeJourney {
                        setupRandomPhotoOps(for: activeJourney)
                    }
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
        Task { await healthKitStepService.requestAuthorization() }

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
        randomPhotoOpMonitor.stopMonitoring()
        randomPhotoOpMonitor.onRegionEntered = nil
        isRandomPhotoOpPresented = false

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
                    goPathBreadcrumb = []
                    hasSubmittedJourneyCompletion = false
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

    /// Grace period before an *automatic* geofence trigger pops the camera — a real region
    /// crossing, or `JourneyGeofenceMonitor`'s "already inside" check firing the instant a
    /// mission gets registered right where the user is already standing (e.g. finishing one
    /// mission puts them inside the next one's radius). Without this, the camera could cover
    /// the screen before the current-step card even has a chance to render what the new
    /// mission is. A manual tap on this exact mission's own "Take a Photo" button skips the
    /// delay entirely — the user already saw the card, that's why they tapped.
    private static let autoCameraGracePeriodSeconds: Double = 5

    /// `isManualConfirmation` is set only when this came from a user tap (the mission "I'm
    /// here" button, or an unlocated step's "I've done it"/"Take a Photo" card) rather than a
    /// real geofence trigger — it shows a small acknowledgement toast so tapping the button
    /// visibly does something, since the step itself may have no other on-screen change (an
    /// unlocated step's card simply disappears once `.done`). Skipped when this call is also
    /// the one that finishes the whole journey — the completion summary screen is
    /// acknowledgement enough there.
    private func handleGeofenceEntered(stepId: String, attemptId: String, isManualConfirmation: Bool = false) {
        guard let coordinate = locationStore.currentLocation?.coordinate ?? resolvedCurrentLocation?.coordinate else { return }

        // A photo-capture step is a moment-in-time prompt, not something that should wait on
        // `advance` below — so the camera pops independently of (and before) that network round
        // trip. Skipped if this step is already done (a re-firing region, or a previous
        // catch-up advance already covered it) so the user isn't nagged for the same spot twice.
        if let step = goJourneySteps.first(where: { $0.id == stepId }),
           step.isPhotoCheckpoint, step.status != .done {
            if isManualConfirmation {
                pendingPhotoStep = step
            } else {
                Task {
                    try? await Task.sleep(for: .seconds(Self.autoCameraGracePeriodSeconds))
                    await MainActor.run {
                        guard showGoMode, goJourneySteps.first(where: { $0.id == stepId })?.status != .done else { return }
                        pendingPhotoStep = step
                    }
                }
            }
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

                // Drop any step that just became done from active monitoring — once its
                // action is fulfilled there's no reason to keep watching that region.
                let remaining = geofences(from: result.steps)
                goGeofences = remaining
                geofenceMonitor.startMonitoring(geofences: remaining)

                let didFinishJourney = finishJourneyIfNeeded(steps: result.steps, attemptId: attemptId)
                if isManualConfirmation, !didFinishJourney {
                    AppToastCenter.shared.showSuccess(title: "Marked as Done", message: "Nice work — logged as complete.")
                }
            }
        }
    }

    /// Geofences for whichever of `steps` are still outstanding — used both to (re)register
    /// monitoring after every /advance response (so a step that just became done drops out)
    /// and when resuming a trip from GET /current, which only returns steps, not the /go
    /// geofence list.
    private func geofences(from steps: [JourneyAttemptStep]) -> [JourneyGeofence] {
        steps.compactMap { step in
            guard step.status == .waiting, let lat = step.lat, let lng = step.lng, let radius = step.radiusMeters else { return nil }
            return JourneyGeofence(stepId: step.id, sequence: step.sequence, lat: lat, lng: lng, radiusMeters: radius)
        }
    }

    /// POST /private/journey/{id}/advance never finalizes an attempt by itself — once every
    /// step reaches "done", POST /private/journey/{id}/complete is what actually awards XP/
    /// badges and records the summary + breadcrumb, so that's called here to make the journey
    /// actually finish. Must be called from a MainActor context (it touches @State directly,
    /// not through `MainActor.run`, since every caller already is one).
    @discardableResult
    private func finishJourneyIfNeeded(steps: [JourneyAttemptStep], attemptId: String) -> Bool {
        guard !hasSubmittedJourneyCompletion, !steps.isEmpty, steps.allSatisfy({ $0.status == .done }) else { return false }
        hasSubmittedJourneyCompletion = true

        let distanceMeters = activeJourney?.summary.distanceMeters ?? 0
        let tripStartedAt = goJourneyAttempt?.startedAt ?? goJourneyAttempt?.createdAt ?? Date()
        let startPoint = activeJourney?.segments.first?.from?.name ?? "Start"
        let finishPoint = activeJourney?.destinationName ?? "Destination"
        let path = goPathBreadcrumb

        Task {
            // HealthKit records steps/energy passively in the background regardless of when
            // this app requested read access, so one statistics query spanning the whole trip
            // at completion time — rather than a live running total kept throughout — is
            // enough to capture everything, including time spent backgrounded. Falls back to
            // the old distance-based estimate (rather than failing the request) if HealthKit
            // is unavailable, unauthorized, or the query errors for any reason.
            let healthKitStats = await healthKitStepService.stats(from: tripStartedAt, to: Date())
            let request = CompleteJourneyRequest(
                stepsTaken: healthKitStats?.steps ?? Int((distanceMeters / 0.75).rounded()),
                distanceMeters: distanceMeters,
                calorie: healthKitStats?.calories ?? distanceMeters * 0.05,
                startPoint: startPoint,
                finishPoint: finishPoint,
                path: path
            )

            do {
                let result = try await journeyService.completeJourney(attemptId: attemptId, request: request)
                await MainActor.run {
                    goJourneyAttempt = result.journeyAttempt
                    geofenceMonitor.stopMonitoring()
                    journeyCompletionResult = result
                }
            } catch {
                await MainActor.run {
                    // Let a retry happen — the next /advance response that still finds every
                    // step done (e.g. a stray re-fired region) will attempt this again.
                    hasSubmittedJourneyCompletion = false
                    AppToastCenter.shared.showError(
                        title: "Couldn't Finish Journey",
                        message: (error as? TransiumAPIError)?.errorDescription ?? "Please try again."
                    )
                }
            }
        }

        return true
    }

    /// `CameraScreen`'s `onCaptured` for a photo-capture step — uploads via POST
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

    /// Registers `RandomPhotoOpPlanner`'s 0-2 spontaneous keepsake points on the dedicated
    /// `randomPhotoOpMonitor` — separate from the real quest geofences so this can never touch
    /// step progress. Called once per fresh/replanned Go Mode session (`startGoMode`,
    /// `resumeOngoingTrip`); a short trip yields no points, which is a no-op here.
    private func setupRandomPhotoOps(for journey: JourneyResult) {
        let points = RandomPhotoOpPlanner.planPoints(for: journey)
        guard !points.isEmpty else {
            randomPhotoOpMonitor.stopMonitoring()
            return
        }

        let geofences = points.map { point in
            JourneyGeofence(
                stepId: "random-photo-\(UUID().uuidString)",
                sequence: 0,
                lat: point.latitude,
                lng: point.longitude,
                radiusMeters: RandomPhotoOpPlanner.radiusMeters
            )
        }

        randomPhotoOpMonitor.onRegionEntered = { markerId in
            handleRandomPhotoOpEntered(markerId: markerId)
        }
        randomPhotoOpMonitor.startMonitoring(geofences: geofences)
    }

    private func handleRandomPhotoOpEntered(markerId: String) {
        // A real quest-action photo prompt always wins — never stack a spontaneous keepsake
        // prompt on top of one, and don't present a second keepsake prompt over itself if the
        // other point (if any) fires again before this one's flow finishes.
        guard pendingPhotoStep == nil, !isRandomPhotoOpPresented else { return }

        // Stop watching just this point so it can't nag again if the user lingers/backtracks
        // nearby — the other point (if any) stays independently active.
        randomPhotoOpMonitor.stopMonitoring(identifier: markerId)
        isRandomPhotoOpPresented = true
    }

    /// `CameraScreen`'s `onCaptured` for a spontaneous keepsake photo — uploads attached to the
    /// attempt itself (not any one step, since it isn't tied to a quest action) and never calls
    /// `advanceJourney`, unlike `handlePhotoCaptured`.
    private func handleRandomPhotoOpCaptured(image: UIImage) async {
        guard let attemptId = goJourneyAttempt?.id else {
            await MainActor.run { isRandomPhotoOpPresented = false }
            return
        }
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            AppToastCenter.shared.showError(title: "Upload Failed", message: "Couldn't process that photo. Please try again.")
            return
        }

        do {
            _ = try await journeyService.uploadAttemptMedia(
                attemptId: attemptId,
                imageData: data,
                filename: "keepsake-\(UUID().uuidString).jpg",
                mimeType: "image/jpeg"
            )
            await MainActor.run {
                isRandomPhotoOpPresented = false
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
        Button(action: { presentSearchSheet(in: .searching) }) {
            HStack(spacing: 10) {
                Image(systemName: "location.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TransiumColor.primaryBlue)

                Text(currentLocationText)
                    .font(TransiumFont.body(14, weight: .semibold))
                    .foregroundStyle(TransiumColor.ticketInk)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "square.and.pencil")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(TransiumColor.primaryBlue)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.92))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
        }
        .buttonStyle(.transiumNoOpacity)
        .padding(.horizontal, 20)
    }

    private var currentLocationText: String {
        if let manualLocationOverrideLabel {
            return manualLocationOverrideLabel
        }
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
        pinFocusCoordinate = nil
        pinnedCoordinate = nil
        pinnedAddressLabel = "Locating address..."
        reverseGeocodeTask?.cancel()
    }

    /// A search result was picked — moves the sheet into pin-drop mode centered on it. Seeds
    /// `pinnedAddressLabel` with the result's own label so there's no blank/loading flash
    /// before the map settles there and the first live reverse-geocode (`onPinCenterChanged` →
    /// `scheduleReverseGeocode`) confirms it.
    private func beginPinning(at coordinate: CLLocationCoordinate2D, label: String) {
        pinFocusCoordinate = coordinate
        pinnedCoordinate = coordinate
        pinnedAddressLabel = label
        sheetDetent = .medium
        sheetState = .pinning
    }

    /// Debounces `pinnedCoordinate` updates (fired on every drag) into a single GET
    /// /maps/reverse-geocode call once the map settles, rather than one request per frame.
    private func scheduleReverseGeocode(for coordinate: CLLocationCoordinate2D) {
        reverseGeocodeTask?.cancel()
        reverseGeocodeTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            guard let result = try? await LocationService.shared.reverseGeocode(lat: coordinate.latitude, lng: coordinate.longitude),
                  let place = result.results.first else { return }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                pinnedAddressLabel = place.label
            }
        }
    }
}

#Preview {
    HomeScreen(previewLocation: CLLocation(latitude: -8.702105, longitude: 115.176189))
}
