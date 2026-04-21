//
//  HealthKitManager.swift
//  runboard
//
//  Created by Paul Goldschmidt on 03.04.26.
//

import Foundation
import HealthKit
import Observation
import os

@Observable
final class HealthKitManager {
    enum Status {
        case notDetermined
        case authorized
        case denied
        case unavailable
    }

    var status: Status = .notDetermined
    var vo2Max: Double?
    var weeklyRunningKilometers: Double = 0.0

    private let store = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async {
        guard status == .notDetermined else { return }
        guard isAvailable else {
            status = .unavailable
            return
        }

        let typesToRead: Set<HKObjectType> = [
            HKQuantityType(.vo2Max),
            HKObjectType.workoutType()
        ]

        do {
            try await store.requestAuthorization(toShare: [], read: typesToRead)
            status = .authorized
        } catch {
            status = .denied
        }
    }

    func fetchLatestVO2Max() async {
        guard isAvailable else { return }

        let vo2MaxType = HKQuantityType(.vo2Max)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let sample: HKQuantitySample? = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: vo2MaxType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, results, _ in
                continuation.resume(returning: results?.first as? HKQuantitySample)
            }
            store.execute(query)
        }

        if let sample {
            let unit = HKUnit.literUnit(with: .milli).unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: HKUnit.minute()))
            vo2Max = sample.quantity.doubleValue(for: unit)
        } else {
            vo2Max = nil
        }
    }

    func fetchWeeklyRunningDistance() async {
        guard isAvailable else { return }

        guard let weekInterval = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) else {
            weeklyRunningKilometers = 0.0
            return
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: weekInterval.start,
            end: weekInterval.end,
            options: .strictStartDate
        )
        let workoutPredicate = HKQuery.predicateForWorkouts(with: .running)
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, workoutPredicate])

        let workouts: [HKWorkout] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: compoundPredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, results, _ in
                continuation.resume(returning: (results as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }

        let totalMeters = workouts.compactMap { workout in
            workout.totalDistance?.doubleValue(for: .meter())
        }.reduce(0, +)

        weeklyRunningKilometers = totalMeters / 1000.0
    }

    func refreshAll() async {
        async let vo2 = fetchLatestVO2Max()
        async let distance = fetchWeeklyRunningDistance()
        _ = await (vo2, distance)
    }

    // MARK: - Background delivery & anchored queries

    static let vo2MaxUnit: HKUnit = HKUnit.literUnit(with: .milli)
        .unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: HKUnit.minute()))

    static let observedTypes: [HKSampleType] = [
        HKQuantityType(.vo2Max),
        HKObjectType.workoutType()
    ]

    /// Registers the two observed sample types for iOS background delivery.
    /// Must be called after `requestAuthorization()` has resolved to `.authorized`.
    func enableBackgroundDelivery() async {
        guard isAvailable else { return }
        for type in Self.observedTypes {
            do {
                try await store.enableBackgroundDelivery(for: type, frequency: .hourly)
                SyncLog.hk.info("background delivery enabled for \(type.identifier, privacy: .public)")
            } catch {
                SyncLog.hk.error("background delivery failed for \(type.identifier, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Runs an anchored query against the given sample type. Returns the new anchor.
    /// Used by the background coordinator — we don't need the sample payloads, just
    /// the anchor advance. The UI-facing weekly sum is re-aggregated separately.
    func advanceAnchor(for type: HKSampleType, from anchorData: Data?) async throws -> Data {
        guard isAvailable else { return anchorData ?? Data() }

        let previousAnchor: HKQueryAnchor? = anchorData.flatMap {
            try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: $0)
        }

        let newAnchor: HKQueryAnchor = try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: type,
                predicate: nil,
                anchor: previousAnchor,
                limit: HKObjectQueryNoLimit
            ) { _, _, _, returnedAnchor, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: returnedAnchor ?? HKQueryAnchor(fromValue: 0))
                }
            }
            store.execute(query)
        }

        return try NSKeyedArchiver.archivedData(withRootObject: newAnchor, requiringSecureCoding: true)
    }

    /// Attaches an observer query for each observed type. The `handler` is invoked on a
    /// background queue when iOS wakes the app with new samples; it must call `completion`
    /// within ~30 seconds or iOS will throttle future deliveries. Retain the returned
    /// queries for the lifetime of observation.
    func attachObservers(handler: @escaping @Sendable (HKSampleType, @escaping @Sendable () -> Void) -> Void) -> [HKObserverQuery] {
        guard isAvailable else { return [] }
        var queries: [HKObserverQuery] = []
        for type in Self.observedTypes {
            let query = HKObserverQuery(sampleType: type, predicate: nil) { _, rawCompletion, error in
                // HealthKit's completion handler isn't Sendable by default; wrap it
                // in an UncheckedSendable box so we can forward it across a Task boundary.
                let completion: @Sendable () -> Void = {
                    rawCompletion()
                }
                if let error {
                    SyncLog.observer.error("observer error for \(type.identifier, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    completion()
                    return
                }
                handler(type, completion)
            }
            store.execute(query)
            queries.append(query)
        }
        return queries
    }
}
