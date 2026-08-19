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
    
    //    MARK: This is for ticket creating
    
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
    
    @State private var activeJourney: JourneyResult? = nil
    @State private var isFetchingJourney = false
    @State private var showNavigationSheet = false
    private let journeyService = JourneyService()
    
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
                // NAVIGATION MODE OVERLAYS
                
                // Top Action Bar & Floating Go Button Overlay
                VStack {
                    // Top Bar (Back, Bookmark, Share, Locate)
                    HStack {
                        // Back Button
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
                        
                        // Right Action Buttons
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
                    .padding(.top, 48) // Positioned higher up right under Dynamic Island
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
                
                // Docked Bottom Stack: Floating Go Button + Navigation Bottom Sheet
                VStack(spacing: 0) {
                    // Floating Go button resting on top-right of sheet
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
                            .background(Color(red: 0.24, green: 0.65, blue: 0.44)) // Figma green
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
                // EXPLORE MODE (DEFAULT)
                VStack {
                    HStack {
                        Spacer()
                        
                        TransiumIconButton(
                            systemName: "location.fill",
                            accessibilityLabel: "Center map on your location"
                        ) {
                            mapCenterRequestID += 1
                        }
                        .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                    }
                    .padding(.top, 48) // Positioned higher up under notch
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
                
                bottomMapContent
                    .ignoresSafeArea(edges: .bottom)
            }
            
            // Loading Overlay when fetching journey from Workers
            if isFetchingJourney {
                ZStack {
                    Color.black.opacity(0.32)
                        .ignoresSafeArea()
                        .transition(.opacity)
                    
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(TransiumColor.primaryBlue.opacity(0.12))
                                .frame(width: 56, height: 56)
                            
                            ProgressView()
                                .controlSize(.large)
                                .tint(TransiumColor.primaryBlue)
                        }
                        
                        VStack(spacing: 4) {
                            Text("Planning Quest Route")
                                .font(TransiumFont.body(18, weight: .bold))
                                .foregroundColor(TransiumColor.ticketInk)
                            
                            Text("Finding the optimal transit path...")
                                .font(TransiumFont.body(13, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.16), radius: 20, y: 8)
                    )
                    .padding(.horizontal, 40)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .task {
            guard previewLocation == nil else {
                return
            }
            
            locationStore.requestCurrentLocation()
        }
        .preferredColorScheme(.light)
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
                .foregroundStyle(.primary)
            
            Spacer()
            
            Image(systemName: "square.and.pencil")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(TransiumColor.primaryBlue)
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(.white)
        .clipShape(.capsule)
        .shadow(color: .black.opacity(0.14), radius: 14, y: 5)
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
    }
    
    private func distanceText(to destination: TicketDestination) -> String {
        guard let currentLocation = resolvedCurrentLocation else {
            return destination.fallbackDistance
        }
        
        let destinationLocation = CLLocation(
            latitude: destination.coordinate.latitude,
            longitude: destination.coordinate.longitude
        )
        let kilometers = currentLocation.distance(from: destinationLocation) / 1_000
        
        if kilometers < 10 {
            return String(format: "%.1f", kilometers)
        }
        
        return "\(Int(kilometers.rounded()))"
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
    HomeScreen(
        previewLocation: CLLocation(
            latitude: -8.7238,
            longitude: 115.1752
        )
    )
}
