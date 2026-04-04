//
//  HealthKitManager.swift
//  runboard
//
//  Created by Paul Goldschmidt on 03.04.26.
//

import Foundation
import HealthKit
import Observation

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
}
