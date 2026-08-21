//
//  HomeScreen.swift
//  transium
//

import CoreLocation
import MapLibre
import SwiftUI

struct HomeScreen: View {
    @StateObject private var vm = HomeViewModel()
    @Environment(\.scenePhase) private var scenePhase

    init(previewLocation: CLLocation? = nil) {
        _vm = StateObject(wrappedValue: {
            let model = HomeViewModel()
            model.previewLocation = previewLocation
            return model
        }())
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            mapLayer
            
            if vm.isMenuExpanded {
                menuDismissBackdrop
            }
            
            if let journey = vm.activeJourney, vm.showGoMode {
                goModeLayer(journey: journey)
            } else if let journey = vm.activeJourney, vm.showNavigationSheet {
                navigationModeLayer(journey: journey)
            } else {
                exploreModeLayer
            }
            
            if vm.isDetailPresented {
                detailOverlay
            }

            if vm.isStartingGoMode || vm.isFetchingJourney || vm.isResumingOngoingTrip {
                LoadingScreen()
                    .transition(.opacity)
                    .zIndex(300)
            }
        }
        .task {
            await vm.onTask()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            vm.handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
        .onChange(of: vm.locationStore.currentLocation?.coordinate.latitude) { _, _ in
            vm.handleLocationChange()
        }
        .onChange(of: vm.locationStore.currentLocation?.coordinate.longitude) { _, _ in
            vm.handleLocationChange()
        }
        .onChange(of: vm.goJourneySteps) { _, _ in
            vm.advanceGoSegmentIfNeeded()
        }
        .preferredColorScheme(.light)
        .alert("Journey Already in Progress", isPresented: $vm.isJourneyConflictPresented, presenting: vm.journeyConflict) { conflict in
            if vm.canResumeLocally(conflict) {
                Button("Resume Journey") { vm.resumeCachedGoMode() }
            }
            Button("Cancel That Journey & Start This One", role: .destructive) {
                vm.cancelConflictingAttemptAndRetry(conflict)
            }
            Button("Not Now", role: .cancel) { vm.journeyConflict = nil }
        } message: { conflict in
            Text(conflict.message)
        }
        .alert("Go Requires Your Real Location", isPresented: $vm.isLocationOverrideBlockingGoPresented) {
            Button("Use My Current Location") {
                vm.manualLocationOverride = nil
                vm.manualLocationOverrideLabel = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You're viewing the map from a manually set location. Switch back to your real location to start this journey.")
        }
        .fullScreenCover(item: $vm.pendingPhotoStep) { step in
            CameraScreen(onCaptured: { image in
                await vm.handlePhotoCaptured(image: image, step: step)
            })
        }
        .fullScreenCover(isPresented: $vm.isRandomPhotoOpPresented) {
            CameraScreen(onCaptured: { image in
                await vm.handleRandomPhotoOpCaptured(image: image)
            })
        }
        .fullScreenCover(item: $vm.journeyCompletionResult) { result in
            SummaryScreen(result: result, onDismiss: {
                vm.journeyCompletionResult = nil
                vm.endGoMode()
            })
        }
        .sheet(isPresented: $vm.isSearchPresented, onDismiss: vm.resetSheetState) {
            searchSheetContent
        }
        .sheet(isPresented: $vm.isProfilePresented) {
            ProfileScreen()
        }
        .sheet(isPresented: $vm.isSettingsPresented) {
            SettingsScreen()
        }
        .sheet(isPresented: $vm.isSavedQuestPresented) {
            SavedQuestScreen()
        }
    }

    // MARK: - View Layers

    private var mapLayer: some View {
        LocalBaliMapView(
            displayLocation: vm.resolvedCurrentLocation,
            markerHeading: vm.previewLocation == nil ? vm.locationStore.currentHeading : 22,
            centerRequestID: vm.mapCenterRequestID,
            activeJourney: vm.activeJourney,
            checkpoints: vm.goGeofences,
            isGoMode: vm.showGoMode,
            isPinning: vm.isSearchPresented && vm.sheetState == .pinning,
            pinFocusCoordinate: vm.pinFocusCoordinate,
            onPinCenterChanged: { coordinate in
                vm.pinnedCoordinate = coordinate
                vm.scheduleReverseGeocode(for: coordinate)
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
                    vm.isMenuExpanded = false
                }
            }
    }

    private func goModeLayer(journey: JourneyResult) -> some View {
        GoComponentMode(
            journey: journey,
            currentSegmentIndex: vm.goCurrentSegmentIndex,
            steps: vm.goJourneySteps,
            currentLocation: vm.locationStore.currentLocation?.coordinate,
            geofenceMonitor: vm.geofenceMonitor,
            goStartResult: vm.goStartDebugResult,
            onBack: { vm.endGoMode() },
            onEnd: { vm.endGoMode(cancelAttempt: true) },
            onLocate: { vm.centerMapOnUser() },
            onManualAdvance: { stepId in
                guard let attemptId = vm.goJourneyAttempt?.id else { return }
                vm.handleGeofenceEntered(stepId: stepId, attemptId: attemptId, isManualConfirmation: true)
            }
        )
        .transition(.opacity)
    }

    private func navigationModeLayer(journey: JourneyResult) -> some View {
        ZStack(alignment: .bottom) {
            VStack {
                HomeNavigationTopBar(
                    hasActiveAttempt: vm.goJourneyAttempt != nil,
                    isCancelingJourney: vm.isCancelingJourney,
                    isBookmarked: vm.isCurrentJourneyBookmarked,
                    isTogglingBookmark: vm.isTogglingBookmark,
                    onBack: { vm.exitToExploreMode() },
                    onCancelAttempt: { vm.cancelActiveJourneyAttempt() },
                    onToggleBookmark: { vm.toggleBookmarkForCurrentJourney() },
                    onShare: {
                        AppToastCenter.shared.showSuccess(title: "Shared", message: "Route link copied.")
                    },
                    onLocate: { vm.centerMapOnUser() }
                )
                Spacer()
            }
            
            HomeNavigationActionSheet(
                journey: journey,
                isStartingGoMode: vm.isStartingGoMode,
                onStartGo: { vm.startGoMode() },
                onBack: { vm.exitToExploreMode() }
            )
        }
    }

    private var exploreModeLayer: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                HomeFloatingMenu(
                    isExpanded: $vm.isMenuExpanded,
                    onSettings: { vm.isSettingsPresented = true },
                    onProfile: { vm.isProfilePresented = true },
                    onSavedQuests: { vm.isSavedQuestPresented = true },
                    onCenterMap: { vm.centerMapOnUser() }
                )
            }
            .padding(.top, 6)
            .padding(.horizontal, 20)

            if vm.showOngoingTripCard, let attempt = vm.ongoingJourneyAttempt {
                HStack {
                    OngoingTripCard(questName: attempt.questName ?? "Ongoing Trip") {
                        vm.resumeOngoingTrip()
                    }
                    Spacer()
                }
                .padding(.top, 14)
                .transition(.move(edge: .leading).combined(with: .opacity))
                .disabled(vm.isResumingOngoingTrip)
            }

            Spacer()
            
            if !vm.isSearchPresented {
                HomeTicketSection(
                    kelurahanGroups: vm.kelurahanGroups,
                    visibleTicketPage: $vm.visibleTicketPage,
                    currentLocationLabel: vm.currentLocationText,
                    currentLocation: vm.resolvedCurrentLocation,
                    onSelectKelurahan: { kelurahan in
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            vm.selectedKelurahan = kelurahan
                            vm.isDetailPresented = true
                        }
                    },
                    onEditLocation: { vm.presentSearchSheet(in: .searching) }
                )
                .ignoresSafeArea(edges: .bottom)
            }
            
            if vm.isSearchPresented && vm.sheetState == .pinning {
                HomePinningControls(
                    onBack: { vm.isSearchPresented = false },
                    onLocate: {
                        guard let coordinate = vm.locationStore.currentLocation?.coordinate else { return }
                        vm.pinFocusCoordinate = coordinate
                    }
                )
                HomeCenterPinMarker()
            }
        }
    }

    private var detailOverlay: some View {
        DetailPlaceScreen(
            kelurahan: vm.selectedKelurahan,
            initialQuests: [],
            onBack: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    vm.isDetailPresented = false
                }
            },
            onStartQuest: { questId in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    vm.isDetailPresented = false
                }
                vm.doQuest(questId: questId)
            }
        )
        .transition(.move(edge: .trailing))
        .zIndex(100)
    }

    private var searchSheetContent: some View {
        SearchSheetView(
            state: $vm.sheetState,
            searchText: $vm.searchText,
            pinnedAddressLabel: vm.pinnedAddressLabel,
            onSelectLocation: { coordinate, label in
                vm.beginPinning(at: coordinate, label: label)
            },
            onConfirmStartingPoint: {
                vm.manualLocationOverride = vm.pinnedCoordinate
                vm.manualLocationOverrideLabel = vm.pinnedAddressLabel
                vm.isSearchPresented = false
            },
            onUseCurrentLocation: {
                vm.manualLocationOverride = nil
                vm.manualLocationOverrideLabel = nil
                vm.isSearchPresented = false
            },
            onCancel: { vm.isSearchPresented = false }
        )
        .presentationDetents([.fraction(0.38), .large], selection: $vm.sheetDetent)
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(false)
        .onChange(of: vm.sheetDetent) { _, newDetent in
            vm.sheetState = (newDetent == .large) ? .searching : .pinning
        }
    }
}

#Preview {
    HomeScreen(previewLocation: CLLocation(latitude: -8.702105, longitude: 115.176189))
}
