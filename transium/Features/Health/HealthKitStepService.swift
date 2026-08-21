//
//  HealthKitStepService.swift
//  transium
//

import Foundation
import HealthKit

/// Reads the device's step count and active energy burned for a finished Go Mode trip, so
/// POST /private/journey/{id}/complete can submit real device measurements instead of the
/// rough distance-based estimate it used before. HealthKit already records steps/energy
/// passively in the background regardless of this app's own authorization state or whether
/// it's foregrounded, so there's no need to run a live query throughout the trip — a single
/// statistics query spanning the trip's start to its completion, run once at `finishJourneyIfNeeded`,
/// captures everything.
@MainActor
final class HealthKitStepService {
    private let healthStore = HKHealthStore()
    private let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    private let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Requests read access to step count and active energy. Called once, early — at Go Mode
    /// start rather than at trip completion — so the system permission prompt doesn't interrupt
    /// the "journey complete" moment. Safe to call repeatedly: HealthKit no-ops once the user
    /// has already answered the prompt, and never reports back whether access was granted or
    /// denied (by design, for privacy) — `stats(from:to:)` is what actually reveals that, by
    /// simply returning nil if it can't get real data.
    func requestAuthorization() async {
        guard isAvailable else { return }
        try? await healthStore.requestAuthorization(toShare: [], read: [stepType, energyType])
    }

    /// Total steps and active-energy calories recorded between `start` and `end`. Returns nil
    /// — not zero — on any failure (HealthKit unavailable, access denied, or a query error), so
    /// the caller can fall back to its own estimate instead of submitting a misleadingly precise
    /// zero for what was actually a real trip.
    func stats(from start: Date, to end: Date) async -> (steps: Int, calories: Double)? {
        guard isAvailable else { return nil }

        async let steps = sum(stepType, unit: .count(), from: start, to: end)
        async let calories = sum(energyType, unit: .kilocalorie(), from: start, to: end)

        guard let steps = await steps, let calories = await calories else { return nil }
        return (Int(steps.rounded()), calories)
    }

    private func sum(_ type: HKQuantityType, unit: HKUnit, from start: Date, to end: Date) async -> Double? {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, error in
                guard error == nil, let sum = statistics?.sumQuantity() else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: sum.doubleValue(for: unit))
            }
            healthStore.execute(query)
        }
    }
}
