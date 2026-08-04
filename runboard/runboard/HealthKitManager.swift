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
    /// Start of the week `weeklyRunningKilometers` was last summed over, so the
    /// sync layer can stamp a push with the week the data belongs to even if
    /// the push itself lands after a week rollover.
    private(set) var lastDistanceWeekStart: Date?

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

    /// Outcome of a refreshAll pass. A `false` flag means the read FAILED
    /// (device locked, authorization not determined, transient HK error) and the
    /// corresponding stored value was left untouched — callers must not treat it
    /// as "user has no data" or publish it anywhere.
    struct RefreshOutcome {
        let vo2Succeeded: Bool
        let distanceSucceeded: Bool
    }

    @discardableResult
    func fetchLatestVO2Max() async -> Bool {
        guard isAvailable else { return false }

        let vo2MaxType = HKQuantityType(.vo2Max)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let result: Result<HKQuantitySample?, Error> = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: vo2MaxType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, results, error in
                if let error {
                    continuation.resume(returning: .failure(error))
                } else {
                    continuation.resume(returning: .success(results?.first as? HKQuantitySample))
                }
            }
            store.execute(query)
        }

        switch result {
        case .failure(let error):
            SyncLog.hk.error("vo2Max query failed — keeping previous value: \(error.localizedDescription, privacy: .public)")
            return false
        case .success(let sample):
            if let sample {
                let unit = HKUnit.literUnit(with: .milli).unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: HKUnit.minute()))
                vo2Max = sample.quantity.doubleValue(for: unit)
            } else {
                // An error-free empty result: either genuinely no samples or
                // read access denied (HealthKit hides denial). Reflect it
                // locally, but the sync layer never clears the server from nil.
                vo2Max = nil
            }
            return true
        }
    }

    @discardableResult
    func fetchWeeklyRunningDistance() async -> Bool {
        guard isAvailable else { return false }

        // ISO week (Monday start) to match the board's week model everywhere
        // else; Calendar.current would start the week on Sunday in some locales.
        guard let weekInterval = Calendar(identifier: .iso8601).dateInterval(of: .weekOfYear, for: Date()) else {
            return false
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: weekInterval.start,
            end: weekInterval.end,
            options: .strictStartDate
        )
        let workoutPredicate = HKQuery.predicateForWorkouts(with: .running)
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, workoutPredicate])

        let result: Result<[HKWorkout], Error> = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: compoundPredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, results, error in
                if let error {
                    continuation.resume(returning: .failure(error))
                } else {
                    continuation.resume(returning: .success((results as? [HKWorkout]) ?? []))
                }
            }
            store.execute(query)
        }

        switch result {
        case .failure(let error):
            SyncLog.hk.error("workout query failed — keeping previous value: \(error.localizedDescription, privacy: .public)")
            return false
        case .success(let workouts):
            let totalMeters = workouts.compactMap { workout in
                workout.totalDistance?.doubleValue(for: .meter())
            }.reduce(0, +)
            weeklyRunningKilometers = totalMeters / 1000.0
            lastDistanceWeekStart = weekInterval.start
            return true
        }
    }

    @discardableResult
    func refreshAll() async -> RefreshOutcome {
        async let vo2 = fetchLatestVO2Max()
        async let distance = fetchWeeklyRunningDistance()
        return await RefreshOutcome(vo2Succeeded: vo2, distanceSucceeded: distance)
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
