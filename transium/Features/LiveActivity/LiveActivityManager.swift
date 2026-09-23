//
//  LiveActivityManager.swift
//  transium
//

import ActivityKit
import Foundation

/// Manages the lifecycle and real-time state updates of Transium's Dynamic Island Live Activity.
@MainActor
public final class LiveActivityManager {
    public static let shared = LiveActivityManager()

    private var currentActivity: Activity<TransiumNavigationActivityAttributes>?

    private init() {}

    /// Starts a live activity for an in-progress Go Mode journey attempt.
    public func startNavigationActivity(
        questTitle: String,
        questId: String,
        attemptId: String,
        initialState: TransiumNavigationActivityAttributes.ContentState
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // End any pre-existing activity before starting a fresh one
        endNavigationActivity()

        let attributes = TransiumNavigationActivityAttributes(
            questTitle: questTitle,
            questId: questId,
            attemptId: attemptId
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            self.currentActivity = activity
        } catch {
            #if DEBUG
            print("LiveActivityManager: failed to request activity — \(error.localizedDescription)")
            #endif
        }
    }

    /// Dynamically updates the current Live Activity with updated navigation telemetry.
    public func updateNavigationActivity(state: TransiumNavigationActivityAttributes.ContentState) {
        if currentActivity == nil {
            currentActivity = Activity<TransiumNavigationActivityAttributes>.activities.first(where: { $0.activityState == .active })
        }
        guard let activity = currentActivity else { return }

        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    /// Ends all active Live Activities when the trip completes or is canceled.
    public func endNavigationActivity(dismissalPolicy: ActivityUIDismissalPolicy = .immediate) {
        endAllActivities(dismissalPolicy: dismissalPolicy)
    }

    /// Ends all active Live Activities across the system immediately.
    public func endAllActivities(dismissalPolicy: ActivityUIDismissalPolicy = .immediate) {
        let allActivities = Activity<TransiumNavigationActivityAttributes>.activities
        for activity in allActivities {
            Task {
                await activity.end(nil, dismissalPolicy: dismissalPolicy)
            }
        }
        currentActivity = nil
    }
}
