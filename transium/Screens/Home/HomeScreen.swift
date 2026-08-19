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
    
    // MARK: - Ticket Destinations
    
    private let sanurDestination = TicketDestination(
        name: "Sanur",
        subtitle: "A laid-back coastal escape. Where earlybirds relax.",
        fallbackDistance: "11",
        price: "Rp. 4,4k",
        imageName: TransiumAsset.Illustration.onboardingExplore,
        coordinate: CLLocationCoordinate2D(latitude: -8.6937, longitude: 115.2625)
    )
    private let ubudDestination = TicketDestination(
        name: "Ubud",
        subtitle: "Rice fields, art walks, and calmer mountain air.",
        fallbackDistance: "24",
        price: "Rp. 8,8k",
        imageName: TransiumAsset.Illustration.onboardingAdventure,
        coordinate: CLLocationCoordinate2D(latitude: -8.5069, longitude: 115.2625)
    )
    
    // MARK: - Journey State
    @State private var activeJourney: JourneyResult? = nil
    @State private var isFetchingJourney = false
    @State private var showNavigationSheet = false
    private let journeyService = JourneyService.shared
    
    // MARK: - Search Sheet State
    @State private var isSearchPresented = false
    @State private var sheetState: SearchSheetState = .searching
    @State private var sheetDetent: PresentationDetent = .large
    @State private var searchText = ""
    
    init(previewLocation: CLLocation? = nil) {
        self.previewLocation = previewLocation
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            LocalBaliMapView(
                displayLocation: resolvedCurrentLocation,
                markerHeading: previewLocation == nil ? 0 : 22,
                centerRequestID: mapCenterRequestID,
                activeJourney: activeJourney
            )
            .ignoresSafeArea()
            
            if let journey = activeJourney, showNavigationSheet {
                // MARK: - Navigation Mode
                VStack {
                    // Top Bar (Back, Bookmark, Share, Locate)
                    HStack {
                        Button(action: {
                            withAnimation(.spring()) {
                                activeJourney = nil
                                showNavigationSheet = false
                            }
                        }) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.black)
                                .frame(width: 44, height: 44)
                                .background(.white)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 12) {
                            Button(action: {
                                AppToastCenter.shared.showSuccess(title: "Saved", message: "Quest path saved to bookmarks.")
                            }) {
                                Image(systemName: "bookmark")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.black)
                                    .frame(width: 44, height: 44)
                                    .background(.white)
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                            }
                            
                            Button(action: {
                                AppToastCenter.shared.showSuccess(title: "Share", message: "Sharing option selected.")
                            }) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.black)
                                    .frame(width: 44, height: 44)
                                    .background(.white)
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                            }
                            
                            Button(action: {
                                mapCenterRequestID += 1
                            }) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(TransiumColor.primaryBlue)
                                    .frame(width: 44, height: 44)
                                    .background(.white)
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                            }
                        }
                    }
                    .padding(.top, 48)
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
                                message: "Follow the green path to reach your destination."
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
                        .padding(.bottom, 12)
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
                    // Top Search Bar & Locate Controls
                    HStack(spacing: 10) {
                        searchBarTrigger
                        
                        TransiumIconButton(
                            systemName: "location.fill",
                            accessibilityLabel: "Center map on your location"
                        ) {
                            mapCenterRequestID += 1
                        }
                        .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                    }
                    .padding(.top, 48)
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
                
                bottomMapContent
                    .ignoresSafeArea(edges: .bottom)
            }
            
            // Pinning mode overlay controls
            if isSearchPresented && sheetState == .pinning {
                pinningOverlayControls
                centerPinIndicator
            }
        }
        .task {
            guard previewLocation == nil else { return }
            locationStore.requestCurrentLocation()
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
    
    // MARK: - Search Bar Trigger
    
    private var searchBarTrigger: some View {
        Button(action: { presentSearchSheet(in: .searching) }) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(TransiumColor.primaryBlue)

                Text("Search destination or stops...")
                    .font(TransiumFont.body(14))
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(Color.white.opacity(0.95))
            .clipShape(.capsule)
            .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Pinning Overlay Controls
    
    private var pinningOverlayControls: some View {
        VStack {
            HStack {
                Button(action: { isSearchPresented = false }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .background(.white)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                }

                Spacer()

                Button(action: {
                    mapCenterRequestID += 1
                }) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(TransiumColor.primaryBlue)
                        .frame(width: 44, height: 44)
                        .background(.white)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 48)
            
            Spacer()
        }
        .transition(.opacity)
    }
    
    private var centerPinIndicator: some View {
        GeometryReader { proxy in
            Image(systemName: "mappin")
                .font(.system(size: 36))
                .foregroundStyle(Color(red: 0.94, green: 0.27, blue: 0.27))
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                .position(
                    x: proxy.size.width / 2,
                    y: proxy.size.height * 0.44
                )
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
    
    private func doQuest() {
        guard !isFetchingJourney else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isFetchingJourney = true
        }
        
        Task {
            do {
                let originCoordinate = resolvedCurrentLocation?.coordinate ?? CLLocationCoordinate2D(latitude: -8.702105, longitude: 115.176189)
                let destinationCoordinate = CLLocationCoordinate2D(latitude: -8.708812, longitude: 115.252362)
                
                let response = try await journeyService.fetchJourneyOverview(
                    origin: originCoordinate,
                    destination: destinationCoordinate
                )
                
                await MainActor.run {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                        activeJourney = response.best
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
                        message: "Could not plan a journey between your location and the destination."
                    )
                }
            }
        }
    }
    
    private var ticketRail: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .bottom, spacing: 14) {
                recommendedTicket
                    .frame(width: 336)
                    .id(0)
                
                TransiumTicketCard(
                    title: ubudDestination.name,
                    subtitle: ubudDestination.subtitle,
                    distance: distanceText(to: ubudDestination),
                    price: ubudDestination.price,
                    imageName: ubudDestination.imageName,
                    variant: .mint
                )
                .frame(width: 336)
                .id(1)
            }
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
            totalPages: 2,
            activeColor: TransiumColor.primaryBlue,
            inactiveColor: TransiumColor.ticketInk.opacity(0.26)
        )
        .accessibilityLabel("Ticket \(min((visibleTicketPage ?? 0) + 1, 2)) of 2")
    }
    
    private var recommendedTicket: some View {
        VStack(alignment: .leading, spacing: 0) {
            recommendedBadge
                .padding(.leading, 12)
                .padding(.bottom, -1)
                .zIndex(1)
            
            TransiumTicketCard(
                title: sanurDestination.name,
                subtitle: sanurDestination.subtitle,
                distance: distanceText(to: sanurDestination),
                price: sanurDestination.price,
                imageName: sanurDestination.imageName
            )
        }
    }
    
    private var recommendedBadge: some View {
        HStack(spacing: 7) {
            Image(systemName: "sparkle")
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(TransiumColor.primaryYellow)
            
            Text("Recommended")
                .font(TransiumFont.body(11, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(TransiumColor.ticketBlue)
        .clipShape(.rect(topLeadingRadius: 9, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 9, style: .continuous))
        .accessibilityElement(children: .combine)
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
    
    private func distanceText(to destination: TicketDestination) -> String {
        guard let resolvedCurrentLocation else {
            return "\(destination.fallbackDistance) km"
        }
        
        let destinationLocation = CLLocation(
            latitude: destination.coordinate.latitude,
            longitude: destination.coordinate.longitude
        )
        
        let meters = resolvedCurrentLocation.distance(from: destinationLocation)
        let kilometers = meters / 1000
        
        if kilometers < 1 {
            return "\(Int(meters)) m"
        }
        
        return "\(Int(round(kilometers))) km"
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

private struct TicketDestination {
    let name: String
    let subtitle: String
    let fallbackDistance: String
    let price: String
    let imageName: String
    let coordinate: CLLocationCoordinate2D
}

#Preview {
    HomeScreen(previewLocation: CLLocation(latitude: -8.702105, longitude: 115.176189))
}
