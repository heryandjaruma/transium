//
//  HomeViewModel.swift
//  transium
//

import ActivityKit
import Combine
import CoreLocation
import MapLibre
import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    // MARK: - Core Services
    let locationStore = LocationStore()
    let geofenceMonitor = JourneyGeofenceMonitor()
    let randomPhotoOpMonitor = JourneyGeofenceMonitor()
    let healthKitStepService = HealthKitStepService()
    let journeyService = JourneyService.shared
    let questService = QuestService.shared

    var previewLocation: CLLocation?

    // MARK: - Journey & Navigation State
    @Published var activeJourney: JourneyResult? = nil
    @Published var activeQuestId: String? = nil
    @Published var activeQuestName: String? = nil
    @Published var activeAreaName: String? = nil
    @Published var activeBadgeImageUrl: String? = nil
    @Published var isFetchingJourney: Bool = false
    @Published var showNavigationSheet: Bool = false

    // MARK: - Ongoing Trip State
    @Published var ongoingJourneyAttempt: JourneyAttempt? = nil
    @Published var ongoingJourneySteps: [JourneyAttemptStep] = []
    @Published var showOngoingTripCard: Bool = false
    @Published var isResumingOngoingTrip: Bool = false

    // MARK: - Go Mode State
    @Published var isStartingGoMode: Bool = false
    @Published var showGoMode: Bool = false
    @Published var goJourneyAttempt: JourneyAttempt? = nil
    @Published var goJourneySteps: [JourneyAttemptStep] = []
    @Published var goGeofences: [JourneyGeofence] = []
    @Published var goCurrentSegmentIndex: Int = 0
    @Published var isCancelingJourney: Bool = false
    @Published var journeyConflict: JourneyStartConflictError? = nil
    @Published var isJourneyConflictPresented: Bool = false
    @Published var goStartDebugResult: JourneyGoResult? = nil
    @Published var pendingPhotoStep: JourneyAttemptStep? = nil
    @Published var goPathBreadcrumb: [JourneyPathPointInput] = []
    @Published var hasSubmittedJourneyCompletion: Bool = false
    @Published var journeyCompletionResult: JourneyCompleteResult? = nil
    @Published var isRandomPhotoOpPresented: Bool = false

    // MARK: - Search, Sheet & Menu State
    @Published var isSearchPresented: Bool = false
    @Published var isProfilePresented: Bool = false
    @Published var isDetailPresented: Bool = false
    @Published var isSettingsPresented: Bool = false
    @Published var isSavedQuestPresented: Bool = false
    @Published var isMenuExpanded: Bool = false
    @Published var sheetState: SearchSheetState = .searching
    @Published var sheetDetent: PresentationDetent = .large
    @Published var searchText: String = ""

    // MARK: - Pinning & Location State
    @Published var mapCenterRequestID: Int = 0
    @Published var manualLocationOverride: CLLocationCoordinate2D?
    @Published var manualLocationOverrideLabel: String?
    @Published var isLocationOverrideBlockingGoPresented: Bool = false
    @Published var pinFocusCoordinate: CLLocationCoordinate2D?
    @Published var pinnedCoordinate: CLLocationCoordinate2D?
    @Published var pinnedAddressLabel: String = "Locating address..."
    @Published var resolvedAddressLabel: String? = nil
    private var reverseGeocodeTask: Task<Void, Never>?

    // MARK: - Bookmarks & Quests State
    @Published var visibleTicketPage: Int? = 0
    @Published var areaGroups: [AreaQuestsGroup] = []
    @Published var selectedArea: Area = Area(id: "7760985", name: "Benoa", lat: -8.73704, lng: 115.17570)
    @Published var bookmarkedQuestIds: Set<String> = []
    @Published var isTogglingBookmark: Bool = false
    @Published var currentHeading: CLLocationDirection = 0
    @Published var currentLocation: CLLocation? = nil
    private var cancellables = Set<AnyCancellable>()

    private static let segmentArrivalProximityMeters: Double = 69
    private static let autoCameraGracePeriodSeconds: Double = 5

    init() {
        locationStore.$currentHeading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] heading in
                self?.currentHeading = heading
            }
            .store(in: &cancellables)

        locationStore.$currentLocation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loc in
                self?.currentLocation = loc
                self?.handleLocationChange()
            }
            .store(in: &cancellables)
    }

    // MARK: - Lifecycle Setup

    func onTask() async {
        locationStore.requestCurrentLocation()
        reverseGeocodeCurrentLocation()
        await loadUserBookmarks()
        await fetchAreaGroups()
        await checkOngoingJourney()
    }

    func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        guard newPhase == .active && oldPhase == .background else { return }
        Task {
            await loadUserBookmarks()
            await checkOngoingJourney()
        }
    }

    func handleLocationChange() {
        recordPathPointIfNeeded()
        advanceGoSegmentIfNeeded()
        reverseGeocodeCurrentLocation()
    }

    // MARK: - Location & Resolution

    var resolvedCurrentLocation: CLLocation {
        if let previewLocation { return previewLocation }
        if let manualLocationOverride {
            return CLLocation(latitude: manualLocationOverride.latitude, longitude: manualLocationOverride.longitude)
        }
        if let currentLocation = locationStore.currentLocation, currentLocation.coordinate.isWithinBaliRegion {
            return currentLocation
        }
        return HomeLocationFormatter.baliFallbackLocation
    }

    var currentLocationText: String {
        if let manualLocationOverrideLabel { return manualLocationOverrideLabel }
        if let resolvedAddressLabel, !resolvedAddressLabel.isEmpty { return resolvedAddressLabel }
        return "Current Location, Bali"
    }

    func centerMapOnUser() {
        mapCenterRequestID += 1
    }

    // MARK: - Area & Quest Discovery

    func fetchAreaGroups() async {
        do {
            let groups = try await QuestService.shared.listAreaQuests()
            let validGroups = groups.filter { !$0.quests.isEmpty }
            if !validGroups.isEmpty {
                areaGroups = validGroups
                if let first = validGroups.first {
                    selectedArea = first.area
                }
            }
        } catch {
            print("Failed to fetch area quests: \(error)")
        }
    }

    func reverseGeocodeCurrentLocation() {
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

    // MARK: - Journey Planning Flow

    func doQuest(questId: String? = nil) {
        guard !isFetchingJourney else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isFetchingJourney = true
        }
        
        Task {
            do {
                let originCoordinate = resolvedCurrentLocation.coordinate
                let (targetQuestId, targetQuestName, targetAreaName, initialBadgeUrl): (String?, String?, String?, String?) = {
                    if let questId {
                        for group in areaGroups {
                            if let matched = group.quests.first(where: { $0.id == questId }) {
                                return (questId, matched.name, group.area.name, matched.thumbnails.first?.url ?? group.area.photoUrl)
                            }
                        }
                        return (questId, nil, selectedArea.name, selectedArea.photoUrl)
                    }
                    let page = visibleTicketPage ?? 0
                    if areaGroups.indices.contains(page) {
                        let group = areaGroups[page]
                        let q = group.quests.first
                        return (q?.id, q?.name, group.area.name, q?.thumbnails.first?.url ?? group.area.photoUrl)
                    }
                    if let firstGroup = areaGroups.first {
                        let q = firstGroup.quests.first
                        return (q?.id, q?.name, firstGroup.area.name, q?.thumbnails.first?.url ?? firstGroup.area.photoUrl)
                    }
                    return (nil, nil, selectedArea.name, selectedArea.photoUrl)
                }()
                
                var resolvedBadgeUrl = initialBadgeUrl
                if let targetQuestId {
                    if let badges = try? await questService.listQuestBadges(id: targetQuestId), let firstBadge = badges.first, let url = firstBadge.badgeImageUrl, !url.isEmpty {
                        resolvedBadgeUrl = url
                    }
                }

                var response: JourneyResponse?
                if let targetQuestId {
                    response = try? await journeyService.fetchRealJourney(questId: targetQuestId, origin: originCoordinate)
                }
                if response == nil {
                    let destinationCoordinate = CLLocationCoordinate2D(
                        latitude: selectedArea.lat != 0 ? selectedArea.lat : -8.67368,
                        longitude: selectedArea.lng != 0 ? selectedArea.lng : 115.26337
                    )
                    response = try await journeyService.fetchJourneyOverview(origin: originCoordinate, destination: destinationCoordinate)
                }
                
                guard let journeyResponse = response else { return }
                let resolvedJourney = await RoadGeometryResolver.shared.resolveJourneyGeometries(journeyResponse.best)
                
                await MainActor.run {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                        activeJourney = resolvedJourney
                        activeQuestId = targetQuestId
                        activeQuestName = targetQuestName
                        activeAreaName = targetAreaName ?? selectedArea.name
                        activeBadgeImageUrl = resolvedBadgeUrl
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

    func exitToExploreMode() {
        withAnimation(.spring()) {
            activeJourney = nil
            showNavigationSheet = false
        }
        Task { await checkOngoingJourney() }
    }

    // MARK: - Ongoing Trip Checks

    func checkOngoingJourney() async {
        guard !showGoMode, !isResumingOngoingTrip else { return }

        do {
            let current = try await journeyService.getCurrentJourney()
            await MainActor.run {
                guard let attempt = current.journeyAttempt, attempt.status == "started" else {
                    ongoingJourneyAttempt = nil
                    ongoingJourneySteps = []
                    if showOngoingTripCard {
                        withAnimation(.easeIn(duration: 0.22)) { showOngoingTripCard = false }
                    }
                    return
                }

                ongoingJourneyAttempt = attempt
                ongoingJourneySteps = current.steps
                if !showOngoingTripCard {
                    withAnimation(.easeOut(duration: 0.35)) {
                        showOngoingTripCard = true
                    }
                }
            }
        } catch {
            print("Failed to check current journey: \(error)")
        }
    }

    func resumeOngoingTrip() {
        guard !isResumingOngoingTrip, let attempt = ongoingJourneyAttempt, let questId = attempt.questId else { return }
        withAnimation(.easeOut(duration: 0.25)) {
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
                    geofenceMonitor.onRegionEntered = { [weak self, attemptId = attempt.id] stepId in
                        self?.handleGeofenceEntered(stepId: stepId, attemptId: attemptId)
                    }
                    geofenceMonitor.startMonitoring(geofences: geofences)
                    setupRandomPhotoOps(for: resolvedJourney)

                    activeJourney = resolvedJourney
                    activeQuestId = questId
                    activeQuestName = attempt.questName
                    activeAreaName = attempt.questCategory
                    goJourneyAttempt = attempt
                    goJourneySteps = ongoingJourneySteps
                    goGeofences = geofences
                    goCurrentSegmentIndex = 0
                    showOngoingTripCard = false
                    goStartDebugResult = nil
                    goPathBreadcrumb = []
                    hasSubmittedJourneyCompletion = false

                    if activeBadgeImageUrl == nil {
                        Task {
                            if let badges = try? await questService.listQuestBadges(id: questId),
                               let firstUrl = badges.first?.badgeImageUrl, !firstUrl.isEmpty {
                                await MainActor.run { [weak self] in
                                    self?.activeBadgeImageUrl = firstUrl
                                }
                            }
                        }
                    }

                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    withAnimation(.easeOut(duration: 0.35)) {
                        showGoMode = true
                        showNavigationSheet = false
                        isResumingOngoingTrip = false
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.25)) {
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

    func startGoMode() {
        guard !isStartingGoMode, let questId = activeQuestId else { return }
        guard manualLocationOverride == nil else {
            isLocationOverrideBlockingGoPresented = true
            return
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            isStartingGoMode = true
        }
        Task { await healthKitStepService.requestAuthorization() }
        Task { await PushNotificationManager.shared.requestAuthorizationAndRegister() }

        Task {
            do {
                let result = try await journeyService.startJourney(questId: questId)

                NavigationAlertService.shared.reset()

                geofenceMonitor.onRegionEntered = { [weak self] stepId in
                    self?.handleGeofenceEntered(stepId: stepId, attemptId: result.journeyAttempt.id)
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
                    NavigationAlertService.shared.dispatchAlert(
                        key: "journey_started_\(result.journeyAttempt.id)",
                        title: "Journey Started",
                        message: "Navigation is active. Follow the highlighted route.",
                        haptic: .arrived
                    )
                    goJourneyAttempt = result.journeyAttempt
                    goJourneySteps = result.steps
                    goGeofences = result.geofences
                    goCurrentSegmentIndex = 0
                    goStartDebugResult = result
                    goPathBreadcrumb = []
                    hasSubmittedJourneyCompletion = false
                    if let activeJourney {
                        setupRandomPhotoOps(for: activeJourney)

                        let initialEta = max(1, Int((activeJourney.summary.walkingDurationSeconds / 60.0).rounded()))
                        let isBus = activeJourney.segments.first?.type == "bus"
                        let initialState = TransiumNavigationActivityAttributes.ContentState(
                            routeName: isBus ? (activeJourney.segments.first?.routeRef?.truncatedAtDash ?? "Bus") : "Walk",
                            destinationName: activeJourney.destinationName,
                            nextStopName: activeJourney.segments.first?.to?.name ?? activeJourney.destinationName,
                            etaText: "\(initialEta) min",
                            stopsRemainingText: nil,
                            transportType: isBus ? "bus" : "walk",
                            progressFraction: 0.05,
                            isApproachingStop: false
                        )
                        LiveActivityManager.shared.startNavigationActivity(
                            questTitle: activeJourney.destinationName,
                            questId: questId,
                            attemptId: result.journeyAttempt.id,
                            initialState: initialState
                        )
                    }
                    if activeBadgeImageUrl == nil {
                        Task {
                            if let badges = try? await questService.listQuestBadges(id: questId),
                               let firstUrl = badges.first?.badgeImageUrl, !firstUrl.isEmpty {
                                await MainActor.run { [weak self] in
                                    self?.activeBadgeImageUrl = firstUrl
                                }
                            }
                        }
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

    func canResumeLocally(_ conflict: JourneyStartConflictError) -> Bool {
        activeJourney != nil && goJourneyAttempt?.id == conflict.activeJourneyAttemptId
    }

    func resumeCachedGoMode() {
        guard let attempt = goJourneyAttempt else { return }
        journeyConflict = nil
        Task { await healthKitStepService.requestAuthorization() }

        geofenceMonitor.onRegionEntered = { [weak self, attemptId = attempt.id] stepId in
            self?.handleGeofenceEntered(stepId: stepId, attemptId: attemptId)
        }
        geofenceMonitor.startMonitoring(geofences: goGeofences)

        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            showGoMode = true
            showNavigationSheet = false
        }
    }

    func cancelConflictingAttemptAndRetry(_ conflict: JourneyStartConflictError) {
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

    func endGoMode(cancelAttempt: Bool = false) {
        geofenceMonitor.stopMonitoring()
        geofenceMonitor.onRegionEntered = nil
        pendingPhotoStep = nil
        randomPhotoOpMonitor.stopMonitoring()
        randomPhotoOpMonitor.onRegionEntered = nil
        isRandomPhotoOpPresented = false

        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            showGoMode = false
            if cancelAttempt {
                activeJourney = nil
                showNavigationSheet = false
            } else {
                showNavigationSheet = true
            }
            goCurrentSegmentIndex = 0
        }
        goStartDebugResult = nil
        LiveActivityManager.shared.endNavigationActivity(dismissalPolicy: .immediate)

        if cancelAttempt {
            cancelActiveJourneyAttempt()
        }
    }

    func cancelActiveJourneyAttempt() {
        guard let attempt = goJourneyAttempt, !isCancelingJourney else { return }
        isCancelingJourney = true
        LiveActivityManager.shared.endNavigationActivity(dismissalPolicy: .immediate)

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

    func handleGeofenceEntered(stepId: String, attemptId: String, isManualConfirmation: Bool = false) {
        let coordinate = locationStore.currentLocation?.coordinate ?? resolvedCurrentLocation.coordinate

        if let step = goJourneySteps.first(where: { $0.id == stepId }) {
            let placeName = step.name.isEmpty ? (step.description.isEmpty ? "Checkpoint" : step.description) : step.name
            let title = step.isPhotoCheckpoint ? "Photo Spot Reached" : "Arrived at Stop"
            let message = step.isPhotoCheckpoint
                ? "You have reached \(placeName). Take a moment to capture a photo."
                : "You have arrived at \(placeName)."

            NavigationAlertService.shared.dispatchAlert(
                key: "geofence_entered_\(stepId)",
                title: title,
                message: message,
                haptic: step.isPhotoCheckpoint ? .photoOp : .arrived
            )

            if step.isPhotoCheckpoint, step.status != .done {
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

    func geofences(from steps: [JourneyAttemptStep]) -> [JourneyGeofence] {
        steps.compactMap { step in
            guard step.status == .waiting, let lat = step.lat, let lng = step.lng, let radius = step.radiusMeters else { return nil }
            return JourneyGeofence(stepId: step.id, sequence: step.sequence, lat: lat, lng: lng, radiusMeters: radius)
        }
    }

    @discardableResult
    func finishJourneyIfNeeded(steps: [JourneyAttemptStep], attemptId: String) -> Bool {
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
                    LiveActivityManager.shared.endNavigationActivity(dismissalPolicy: .default)
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

    /// Developer testing helper: immediately completes the current Go Mode journey and opens SummaryScreen,
    /// attempting real backend completion first and falling back to a rich mock result if offline/sandbox.
    func devFinishActiveJourney() {
        let distanceMeters = activeJourney?.summary.distanceMeters ?? 1850
        let startPoint = activeJourney?.segments.first?.from?.name ?? "Current Location"
        let finishPoint = activeJourney?.destinationName ?? "Destination"
        let pathInput = goPathBreadcrumb.isEmpty ? [
            JourneyPathPointInput(lat: -8.737, lng: 115.175, recordedAt: Date())
        ] : goPathBreadcrumb

        if let attemptId = goJourneyAttempt?.id {
            let request = CompleteJourneyRequest(
                stepsTaken: Int((distanceMeters / 0.75).rounded()),
                distanceMeters: distanceMeters,
                calorie: max(45, distanceMeters * 0.05),
                startPoint: startPoint,
                finishPoint: finishPoint,
                path: pathInput
            )
            Task {
                do {
                    let result = try await journeyService.completeJourney(attemptId: attemptId, request: request)
                    await MainActor.run {
                        goJourneyAttempt = result.journeyAttempt
                        geofenceMonitor.stopMonitoring()
                        LiveActivityManager.shared.endNavigationActivity(dismissalPolicy: .default)
                        journeyCompletionResult = result
                    }
                } catch {
                    await MainActor.run {
                        let resultPath: [JourneyPathPoint] = pathInput.enumerated().map { index, point in
                            JourneyPathPoint(id: UUID().uuidString, journeyAttemptId: attemptId, sequence: index + 1, lat: point.lat, lng: point.lng, recordedAt: point.recordedAt)
                        }
                        fallbackDevCompleteResult(startPoint: startPoint, finishPoint: finishPoint, distanceMeters: distanceMeters, path: resultPath)
                    }
                }
            }
        } else {
            let resultPath: [JourneyPathPoint] = pathInput.enumerated().map { index, point in
                JourneyPathPoint(id: UUID().uuidString, journeyAttemptId: "dev-attempt", sequence: index + 1, lat: point.lat, lng: point.lng, recordedAt: point.recordedAt)
            }
            fallbackDevCompleteResult(startPoint: startPoint, finishPoint: finishPoint, distanceMeters: distanceMeters, path: resultPath)
        }
    }

    private func fallbackDevCompleteResult(startPoint: String, finishPoint: String, distanceMeters: Double, path: [JourneyPathPoint]) {
        let questTitle = activeQuestName ?? (goJourneyAttempt?.questName ?? "PrimaTrip")
        let endLocation = activeAreaName ?? (selectedArea.name.isEmpty ? (finishPoint != "Destination" && !finishPoint.lowercased().contains("monkey") ? finishPoint : "Denpasar Utara") : selectedArea.name)
        let dummyAttempt = goJourneyAttempt ?? JourneyAttempt(
            id: "dev-attempt-\(UUID().uuidString.prefix(6))",
            userQuestId: "dev-user-quest",
            questId: activeQuestId ?? "dev-quest",
            questName: questTitle,
            questCategory: endLocation,
            currentStepSequence: 1,
            status: "completed",
            createdAt: Date().addingTimeInterval(-1200),
            startedAt: Date().addingTimeInterval(-1200),
            endedAt: Date()
        )
        let dummySummary = JourneySummary(
            id: UUID().uuidString,
            journeyAttemptId: dummyAttempt.id,
            stepsTaken: max(450, Int((distanceMeters / 0.75).rounded())),
            distanceMeters: distanceMeters,
            calorie: max(65, distanceMeters * 0.05),
            startPoint: startPoint != "Destination" && !startPoint.lowercased().contains("monkey") ? startPoint : "Current Location",
            finishPoint: endLocation,
            fuelCostSavedIdr: 15000,
            rideHailingMotorcycleSavedIdr: 25000,
            rideHailingCarSavedIdr: 55000
        )
        let badgeUrl = activeBadgeImageUrl ?? "https://transium-api.heryandjaruma.workers.dev/media/system/badge/ae2cf1b2-e536-416b-9db7-d7e76c6f3443/0e1721d8-0858-462e-af84-f78d99a43d5a.png"
        let dummyBadge = EarnedBadge(
            id: UUID().uuidString,
            badgeId: "dev-badge-1",
            badgeName: "\(questTitle) Badge",
            badgeCategory: endLocation,
            badgeType: "stamp",
            badgeImageUrl: badgeUrl,
            earnedAt: Date(),
            questId: dummyAttempt.questId,
            questName: questTitle
        )
        let dummyProfile = Profile(
            id: "dev-profile",
            userId: "dev-user",
            firstName: "Explorer",
            lastName: "Dev",
            level: 3,
            image: nil,
            email: "dev@transium.app"
        )
        let completeResult = JourneyCompleteResult(
            journeyAttempt: dummyAttempt,
            steps: goJourneySteps,
            summary: dummySummary,
            path: path,
            xpAwarded: 150,
            badgesAwarded: [dummyBadge],
            profile: dummyProfile
        )

        geofenceMonitor.stopMonitoring()
        LiveActivityManager.shared.endNavigationActivity(dismissalPolicy: .default)
        journeyCompletionResult = completeResult
    }

    func handlePhotoCaptured(image: UIImage, step: JourneyAttemptStep) async {
        guard let data = await Task.detached(priority: .userInitiated, operation: {
            image.compressedJPEGData()
        }).value else {
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

    func setupRandomPhotoOps(for journey: JourneyResult) {
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

        randomPhotoOpMonitor.onRegionEntered = { [weak self] markerId in
            self?.handleRandomPhotoOpEntered(markerId: markerId)
        }
        randomPhotoOpMonitor.startMonitoring(geofences: geofences)
    }

    func handleRandomPhotoOpEntered(markerId: String) {
        guard pendingPhotoStep == nil, !isRandomPhotoOpPresented else { return }
        randomPhotoOpMonitor.stopMonitoring(identifier: markerId)
        isRandomPhotoOpPresented = true
    }

    func handleRandomPhotoOpCaptured(image: UIImage) async {
        guard let attemptId = goJourneyAttempt?.id else {
            await MainActor.run { isRandomPhotoOpPresented = false }
            return
        }
        guard let data = await Task.detached(priority: .userInitiated, operation: {
            image.compressedJPEGData()
        }).value else {
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

    func recordPathPointIfNeeded() {
        guard showGoMode, let location = locationStore.currentLocation else { return }
        let coordinate = location.coordinate
        goPathBreadcrumb.append(JourneyPathPointInput(lat: coordinate.latitude, lng: coordinate.longitude, recordedAt: Date()))
        if goPathBreadcrumb.count > 2000 {
            goPathBreadcrumb.removeFirst(goPathBreadcrumb.count - 2000)
        }

        NavigationAlertService.shared.evaluateNavigationProximity(
            userLocation: location,
            journey: activeJourney,
            steps: goJourneySteps,
            currentSegmentIndex: goCurrentSegmentIndex
        )

        updateLiveActivityTelemetry()
    }

    func advanceGoSegmentIfNeeded() {
        guard showGoMode, let journey = activeJourney,
              journey.segments.indices.contains(goCurrentSegmentIndex) else { return }

        let segment = journey.segments[goCurrentSegmentIndex]

        if segment.isMission {
            guard goJourneySteps.attemptStep(for: segment)?.status == .done else { return }
            goCurrentSegmentIndex += 1
            updateLiveActivityTelemetry()
            return
        }

        guard let coordinate = locationStore.currentLocation?.coordinate,
              let distance = segment.liveRemaining(from: coordinate).distanceMeters,
              distance <= Self.segmentArrivalProximityMeters else { return }

        goCurrentSegmentIndex += 1
        updateLiveActivityTelemetry()

        if journey.segments.indices.contains(goCurrentSegmentIndex) {
            let nextSegment = journey.segments[goCurrentSegmentIndex]
            let isBus = nextSegment.type == "bus"
            let title = isBus ? "Boarding Transit" : "Next Leg"
            let message = isBus
                ? "Take \(nextSegment.routeRef?.truncatedAtDash ?? "the bus") toward \(nextSegment.to?.name ?? "your destination")."
                : "Walk toward \(nextSegment.to?.name ?? "the next stop")."
            NavigationAlertService.shared.dispatchAlert(
                key: "segment_advanced_\(goCurrentSegmentIndex)",
                title: title,
                message: message,
                haptic: .approaching
            )
        }
    }

    func updateLiveActivityTelemetry() {
        guard showGoMode, let journey = activeJourney else { return }

        let segment = journey.segments.indices.contains(goCurrentSegmentIndex)
            ? journey.segments[goCurrentSegmentIndex]
            : nil

        let userCoord = locationStore.currentLocation?.coordinate ?? resolvedCurrentLocation.coordinate
        let remaining = segment?.liveRemaining(from: userCoord)

        let remainingSeconds = remaining?.durationSeconds ?? 0
        let minutes = max(1, Int((remainingSeconds / 60.0).rounded()))
        let etaText = "\(minutes) min"

        let isBus = segment?.type == "bus"
        let transportType = segment?.isMission == true ? "mission" : (isBus ? "bus" : "walk")
        let routeName = isBus ? (segment?.routeRef?.truncatedAtDash ?? "Bus") : "Walk"
        let destinationName = journey.destinationName
        let nextStopName = segment?.to?.name ?? destinationName

        let totalDuration = max(1.0, journey.summary.walkingDurationSeconds + (journey.summary.distanceMeters / 6.0))
        let progress = min(1.0, max(0.0, 1.0 - (remainingSeconds / totalDuration)))

        var stopsLeft: String? = nil
        if isBus, let intermediate = segment?.stops {
            stopsLeft = "\(intermediate.count + 1) stops"
        }

        let state = TransiumNavigationActivityAttributes.ContentState(
            routeName: routeName,
            destinationName: destinationName,
            nextStopName: nextStopName,
            etaText: etaText,
            stopsRemainingText: stopsLeft,
            transportType: transportType,
            progressFraction: progress,
            isApproachingStop: (remaining?.distanceMeters ?? 100) < 120
        )

        LiveActivityManager.shared.updateNavigationActivity(state: state)
    }

    // MARK: - Bookmarks

    var isCurrentJourneyBookmarked: Bool {
        guard let questId = activeQuestId ?? ongoingJourneyAttempt?.questId else { return false }
        return bookmarkedQuestIds.contains(questId)
    }

    func loadUserBookmarks() async {
        guard let bookmarks = try? await BookmarkService.shared.listBookmarks() else { return }
        let ids = Set(bookmarks.map { $0.questId })
        await MainActor.run {
            self.bookmarkedQuestIds = ids
        }
    }

    func toggleBookmarkForCurrentJourney() {
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

    // MARK: - Pinning / Search State Handlers

    func presentSearchSheet(in state: SearchSheetState) {
        sheetState = state
        sheetDetent = (state == .searching) ? .large : .fraction(0.38)
        isSearchPresented = true
    }

    func resetSheetState() {
        sheetState = .searching
        sheetDetent = .large
        searchText = ""
        pinFocusCoordinate = nil
        pinnedCoordinate = nil
        pinnedAddressLabel = "Locating address..."
        reverseGeocodeTask?.cancel()
    }

    func beginPinning(at coordinate: CLLocationCoordinate2D, label: String) {
        pinFocusCoordinate = coordinate
        pinnedCoordinate = coordinate
        pinnedAddressLabel = label
        sheetDetent = .fraction(0.38)
        sheetState = .pinning
    }

    func scheduleReverseGeocode(for coordinate: CLLocationCoordinate2D) {
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
