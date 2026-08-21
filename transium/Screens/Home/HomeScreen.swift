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
    private let journeyService = JourneyService.shared

    // MARK: - Journey & Navigation State
    @State private var activeJourney: JourneyResult? = nil
    @State private var activeQuestId: String? = nil
    @State private var isFetchingJourney = false
    @State private var showNavigationSheet = false

    // MARK: - Ongoing Trip State
    @State private var ongoingJourneyAttempt: JourneyAttempt? = nil
    @State private var ongoingJourneySteps: [JourneyAttemptStep] = []
    @State private var showOngoingTripCard = false
    @State private var isResumingOngoingTrip = false

    // MARK: - Go Mode State
    @StateObject private var geofenceMonitor = JourneyGeofenceMonitor()
    @StateObject private var randomPhotoOpMonitor = JourneyGeofenceMonitor()
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
    @State private var goStartDebugResult: JourneyGoResult? = nil
    @State private var pendingPhotoStep: JourneyAttemptStep? = nil
    @State private var goPathBreadcrumb: [JourneyPathPointInput] = []
    @State private var hasSubmittedJourneyCompletion = false
    @State private var journeyCompletionResult: JourneyCompleteResult? = nil
    @State private var isRandomPhotoOpPresented = false

    // MARK: - Search, Sheet & Menu State
    @State private var isSearchPresented = false
    @State private var isProfilePresented = false
    @State private var isDetailPresented = false
    @State private var isSettingsPresented = false
    @State private var isSavedQuestPresented = false
    @State private var isMenuExpanded = false
    @State private var sheetState: SearchSheetState = .searching
    @State private var sheetDetent: PresentationDetent = .large
    @State private var searchText = ""

    // MARK: - Pinning & Location Override State
    @State private var manualLocationOverride: CLLocationCoordinate2D?
    @State private var manualLocationOverrideLabel: String?
    @State private var isLocationOverrideBlockingGoPresented = false
    @State private var pinFocusCoordinate: CLLocationCoordinate2D?
    @State private var pinnedCoordinate: CLLocationCoordinate2D?
    @State private var pinnedAddressLabel = "Locating address..."
    @State private var reverseGeocodeTask: Task<Void, Never>?
    @State private var resolvedAddressLabel: String? = nil

    // MARK: - Bookmarks & Quests State
    @State private var bookmarkedQuestIds: Set<String> = []
    @State private var isTogglingBookmark: Bool = false
    @State private var kelurahanGroups: [KelurahanQuestsGroup] = []
    @State private var selectedKelurahan: Kelurahan = Kelurahan(id: "7760985", kelurahanName: "Benoa", kecamatanName: "Kuta Selatan")

    private static let segmentArrivalProximityMeters: Double = 69
    private static let autoCameraGracePeriodSeconds: Double = 5

    init(previewLocation: CLLocation? = nil) {
        self.previewLocation = previewLocation
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            mapLayer
            
            if isMenuExpanded {
                menuDismissBackdrop
            }
            
            if let journey = activeJourney, showGoMode {
                goModeLayer(journey: journey)
            } else if let journey = activeJourney, showNavigationSheet {
                navigationModeLayer(journey: journey)
            } else {
                exploreModeLayer
            }
            
            if isDetailPresented {
                detailOverlay
            }

            if isStartingGoMode || isFetchingJourney || isResumingOngoingTrip {
                LoadingScreen()
                    .transition(.opacity)
                    .zIndex(300)
            }
        }
        .task {
            locationStore.requestCurrentLocation()
            reverseGeocodeCurrentLocation()
            await loadUserBookmarks()
            await fetchKelurahanGroups()
            await checkOngoingJourney()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
        .onChange(of: locationStore.currentLocation?.coordinate.latitude) { _, _ in
            recordPathPointIfNeeded()
            advanceGoSegmentIfNeeded()
            reverseGeocodeCurrentLocation()
        }
        .onChange(of: locationStore.currentLocation?.coordinate.longitude) { _, _ in
            recordPathPointIfNeeded()
            advanceGoSegmentIfNeeded()
            reverseGeocodeCurrentLocation()
        }
        .onChange(of: goJourneySteps) { _, _ in advanceGoSegmentIfNeeded() }
        .preferredColorScheme(.light)
        .alert("Journey Already in Progress", isPresented: $isJourneyConflictPresented, presenting: journeyConflict) { conflict in
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
        .alert("Go Requires Your Real Location", isPresented: $isLocationOverrideBlockingGoPresented) {
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
            SummaryScreen(result: result, onDismiss: {
                journeyCompletionResult = nil
                endGoMode()
            })
        }
        .sheet(isPresented: $isSearchPresented, onDismiss: resetSheetState) {
            searchSheetContent
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

    // MARK: - View Layers

    private var mapLayer: some View {
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
    }

    private var menuDismissBackdrop: some View {
        Color.clear
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isMenuExpanded = false
                }
            }
    }

    private func goModeLayer(journey: JourneyResult) -> some View {
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
    }

    private func navigationModeLayer(journey: JourneyResult) -> some View {
        ZStack(alignment: .bottom) {
            VStack {
                HomeNavigationTopBar(
                    hasActiveAttempt: goJourneyAttempt != nil,
                    isCancelingJourney: isCancelingJourney,
                    isBookmarked: isCurrentJourneyBookmarked,
                    isTogglingBookmark: isTogglingBookmark,
                    onBack: { exitToExploreMode() },
                    onCancelAttempt: { cancelActiveJourneyAttempt() },
                    onToggleBookmark: { toggleBookmarkForCurrentJourney() },
                    onShare: {
                        AppToastCenter.shared.showSuccess(title: "Shared", message: "Route link copied.")
                    },
                    onLocate: { mapCenterRequestID += 1 }
                )
                Spacer()
            }
            
            HomeNavigationBottomStack(
                journey: journey,
                isStartingGoMode: isStartingGoMode,
                onStartGo: { startGoMode() },
                onBack: { exitToExploreMode() }
            )
        }
    }

    private var exploreModeLayer: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                HomeQuickMenuView(
                    isMenuExpanded: $isMenuExpanded,
                    onSettings: { isSettingsPresented = true },
                    onProfile: { isProfilePresented = true },
                    onSavedQuests: { isSavedQuestPresented = true },
                    onLocate: { mapCenterRequestID += 1 }
                )
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
                HomeBottomTicketCarousel(
                    kelurahanGroups: kelurahanGroups,
                    visibleTicketPage: $visibleTicketPage,
                    currentLocationLabel: currentLocationText,
                    currentLocation: resolvedCurrentLocation,
                    onSelectKelurahan: { kelurahan in
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            selectedKelurahan = kelurahan
                            isDetailPresented = true
                        }
                    },
                    onEditLocation: { presentSearchSheet(in: .searching) }
                )
                .ignoresSafeArea(edges: .bottom)
            }
            
            if isSearchPresented && sheetState == .pinning {
                HomePinningOverlayControls(
                    onBack: { isSearchPresented = false },
                    onLocate: {
                        guard let coordinate = locationStore.currentLocation?.coordinate else { return }
                        pinFocusCoordinate = coordinate
                    }
                )
                HomeCenterPinIndicator()
            }
        }
    }

    private var detailOverlay: some View {
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

    private var searchSheetContent: some View {
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
        .presentationDetents([.fraction(0.38), .large], selection: $sheetDetent)
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(false)
        .onChange(of: sheetDetent) { _, newDetent in
            sheetState = (newDetent == .large) ? .searching : .pinning
        }
    }

    // MARK: - Location & Kelurahan Logistics

    private var resolvedCurrentLocation: CLLocation {
        if let previewLocation { return previewLocation }
        if let manualLocationOverride {
            return CLLocation(latitude: manualLocationOverride.latitude, longitude: manualLocationOverride.longitude)
        }
        if let currentLocation = locationStore.currentLocation, currentLocation.coordinate.isWithinBaliRegion {
            return currentLocation
        }
        return HomeLocationHelper.baliFallbackLocation
    }

    private func fetchKelurahanGroups() async {
        do {
            let originParam = "\(resolvedCurrentLocation.coordinate.latitude),\(resolvedCurrentLocation.coordinate.longitude)"
            let groups = try await QuestService.shared.listKelurahanQuests(origin: originParam)
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

    private func reverseGeocodeCurrentLocation() {
        let loc = resolvedCurrentLocation
        Task {
            if let result = try? await LocationService.shared.reverseGeocode(lat: loc.coordinate.latitude, lng: loc.coordinate.longitude),
               let first = result.results.first, !first.label.isEmpty {
                await MainActor.run {
                    self.resolvedAddressLabel = first.label
                }
            }
        }
    }

    private var currentLocationText: String {
        if let manualLocationOverrideLabel { return manualLocationOverrideLabel }
        if let resolvedAddressLabel, !resolvedAddressLabel.isEmpty { return resolvedAddressLabel }
        return "Current Location, Bali"
    }

    // MARK: - Journey Planning Flow

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
                if let targetQuestId {
                    response = try? await journeyService.fetchRealJourney(questId: targetQuestId, origin: originCoordinate)
                }
                if response == nil {
                    let destinationCoordinate = CLLocationCoordinate2D(latitude: -8.67368, longitude: 115.26337)
                    response = try await journeyService.fetchJourneyOverview(origin: originCoordinate, destination: destinationCoordinate)
                }
                
                guard let validResponse = response else {
                    throw TransiumAPIError.serviceUnavailable("Unable to calculate route")
                }
                
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

    private func exitToExploreMode() {
        withAnimation(.spring()) {
            activeJourney = nil
            showNavigationSheet = false
        }
        Task { await checkOngoingJourney() }
    }

    // MARK: - Ongoing Trip Checks

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
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                        showOngoingTripCard = true
                    }
                }
            }
        } catch {
            print("Failed to check current journey: \(error)")
        }
    }

    private func resumeOngoingTrip() {
        guard !isResumingOngoingTrip, let attempt = ongoingJourneyAttempt, let questId = attempt.questId else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            isResumingOngoingTrip = true
        }
        Task { await healthKitStepService.requestAuthorization() }

        Task {
            do {
                let originCoordinate = resolvedCurrentLocation.coordinate
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

    // MARK: - Go Mode Execution

    private func startGoMode() {
        guard !isStartingGoMode, let questId = activeQuestId else { return }
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

                let originCoordinate = resolvedCurrentLocation.coordinate
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

    private func handleGeofenceEntered(stepId: String, attemptId: String, isManualConfirmation: Bool = false) {
        let coordinate = locationStore.currentLocation?.coordinate ?? resolvedCurrentLocation.coordinate

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

    private func geofences(from steps: [JourneyAttemptStep]) -> [JourneyGeofence] {
        steps.compactMap { step in
            guard step.status == .waiting, let lat = step.lat, let lng = step.lng, let radius = step.radiusMeters else { return nil }
            return JourneyGeofence(stepId: step.id, sequence: step.sequence, lat: lat, lng: lng, radiusMeters: radius)
        }
    }

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
        guard pendingPhotoStep == nil, !isRandomPhotoOpPresented else { return }
        randomPhotoOpMonitor.stopMonitoring(identifier: markerId)
        isRandomPhotoOpPresented = true
    }

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

    private func recordPathPointIfNeeded() {
        guard showGoMode, let coordinate = locationStore.currentLocation?.coordinate else { return }
        goPathBreadcrumb.append(JourneyPathPointInput(lat: coordinate.latitude, lng: coordinate.longitude, recordedAt: Date()))
        if goPathBreadcrumb.count > 2000 {
            goPathBreadcrumb.removeFirst(goPathBreadcrumb.count - 2000)
        }
    }

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

    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        guard newPhase == .active && oldPhase == .background else { return }
        Task {
            await loadUserBookmarks()
            await checkOngoingJourney()
        }
    }

    // MARK: - Bookmarking

    private var isCurrentJourneyBookmarked: Bool {
        guard let questId = activeQuestId ?? ongoingJourneyAttempt?.questId else { return false }
        return bookmarkedQuestIds.contains(questId)
    }

    private func loadUserBookmarks() async {
        guard let bookmarks = try? await BookmarkService.shared.listBookmarks() else { return }
        let ids = Set(bookmarks.map { $0.questId })
        await MainActor.run {
            self.bookmarkedQuestIds = ids
        }
    }

    private func toggleBookmarkForCurrentJourney() {
        guard let questId = activeQuestId ?? ongoingJourneyAttempt?.questId, !isTogglingBookmark else {
            AppToastCenter.shared.showWarning(title: "Save Route", message: "Select a quest route first to bookmark.")
            return
        }
        isTogglingBookmark = true
        let isCurrentlyBookmarked = bookmarkedQuestIds.contains(questId)
        
        Task {
            defer { isTogglingBookmark = false }
            do {
                if isCurrentlyBookmarked {
                    try await BookmarkService.shared.removeBookmark(questId: questId)
                    await MainActor.run {
                        bookmarkedQuestIds.remove(questId)
                        AppToastCenter.shared.showSuccess(title: "Removed", message: "Quest removed from bookmarks.")
                    }
                } else {
                    _ = try await BookmarkService.shared.addBookmark(questId: questId)
                    await MainActor.run {
                        bookmarkedQuestIds.insert(questId)
                        AppToastCenter.shared.showSuccess(title: "Saved", message: "Quest bookmarked!")
                    }
                }
            } catch {
                await MainActor.run {
                    AppToastCenter.shared.showError(title: "Bookmark Failed", message: "Could not update bookmark. Please try again.")
                }
            }
        }
    }

    // MARK: - Pinning / Search Helpers

    private func presentSearchSheet(in state: SearchSheetState) {
        sheetState = state
        sheetDetent = (state == .searching) ? .large : .fraction(0.38)
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

    private func beginPinning(at coordinate: CLLocationCoordinate2D, label: String) {
        pinFocusCoordinate = coordinate
        pinnedCoordinate = coordinate
        pinnedAddressLabel = label
        sheetDetent = .fraction(0.38)
        sheetState = .pinning
    }

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
