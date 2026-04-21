//
//  BackgroundSyncCoordinator.swift
//  runboard
//

import BackgroundTasks
import CloudKit
import Foundation
import HealthKit
import os
import WidgetKit

@MainActor
final class BackgroundSyncCoordinator {
    static let shared = BackgroundSyncCoordinator()

    enum Trigger {
        case foreground
        case observer(HKSampleType)
        case bgAppRefresh
    }

    static let appRefreshIdentifier = "p3g3.runboard.refresh"
    private static let foregroundDebounce: TimeInterval = 5
    private static let bgAppRefreshInterval: TimeInterval = 4 * 60 * 60

    private let healthKit = HealthKitManager()
    private let cloudKit = CloudKitManager()

    private var observerQueries: [HKObserverQuery] = []
    private var didEnableBackgroundDelivery = false
    private var lastSyncAt: Date = .distantPast
    private var inflight: Task<Void, Never>?

    private init() {}

    // MARK: - Bootstrap

    /// Must be called synchronously from `AppDelegate.didFinishLaunchingWithOptions`
    /// so the BGTaskScheduler handler is registered before iOS queries it.
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.appRefreshIdentifier,
            using: nil
        ) { [weak self] task in
            guard let task = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor in
                self?.handleAppRefresh(task: task)
            }
        }
        SyncLog.bootstrap.info("BGTaskScheduler handler registered")
    }

    /// Kicks off HealthKit background delivery, attaches observer queries, and
    /// schedules the next app-refresh. Safe to call more than once; guards ensure
    /// we only enable delivery / attach observers the first time.
    func bootstrap() {
        Task { @MainActor in
            await enableHealthKitIfNeeded()
            attachObserversIfNeeded()
            scheduleNextAppRefresh()
        }
    }

    private func enableHealthKitIfNeeded() async {
        guard !didEnableBackgroundDelivery, healthKit.isAvailable else { return }
        await healthKit.enableBackgroundDelivery()
        didEnableBackgroundDelivery = true
    }

    private func attachObserversIfNeeded() {
        guard observerQueries.isEmpty, healthKit.isAvailable else { return }
        observerQueries = healthKit.attachObservers { [weak self] type, completion in
            Task { @MainActor [weak self] in
                defer { completion() }
                guard let self else { return }
                SyncLog.observer.info("wake for \(type.identifier, privacy: .public)")
                await self.runUploadCycle(trigger: .observer(type))
            }
        }
        SyncLog.bootstrap.info("attached \(self.observerQueries.count, privacy: .public) observer queries")
    }

    // MARK: - BGTask handler

    private func handleAppRefresh(task: BGAppRefreshTask) {
        SyncLog.bgtask.info("BGAppRefresh fired")
        scheduleNextAppRefresh()

        let work = Task { @MainActor in
            await runUploadCycle(trigger: .bgAppRefresh)
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = {
            SyncLog.bgtask.fault("BGAppRefresh expired")
            work.cancel()
        }
    }

    func scheduleNextAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.appRefreshIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: Self.bgAppRefreshInterval)
        do {
            try BGTaskScheduler.shared.submit(request)
            SyncLog.bgtask.info("scheduled next BGAppRefresh")
        } catch {
            SyncLog.bgtask.error("failed to schedule BGAppRefresh: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Upload cycle

    func runUploadCycle(trigger: Trigger) async {
        if case .foreground = trigger,
           Date().timeIntervalSince(lastSyncAt) < Self.foregroundDebounce {
            return
        }

        if let existing = inflight {
            await existing.value
            if case .foreground = trigger { return }
        }

        let task = Task { @MainActor in
            await performUpload(trigger: trigger)
        }
        inflight = task
        await task.value
        inflight = nil
    }

    private func performUpload(trigger: Trigger) async {
        await drainRetryQueue()

        guard cloudKit.hasBoard else {
            SyncLog.cloudkit.debug("no board joined — skipping upload")
            return
        }

        do {
            try await advanceAnchors(for: trigger)
        } catch {
            SyncLog.hk.error("anchor advance failed: \(error.localizedDescription, privacy: .public)")
        }

        await healthKit.refreshAll()
        let vo2 = healthKit.vo2Max
        let km = healthKit.weeklyRunningKilometers
        let weekStart = CloudKitManager.currentWeekStart()

        do {
            try await cloudKit.updateMyStats(vo2Max: vo2, weeklyKilometers: km)
            lastSyncAt = Date()
            await cloudKit.fetchBoardMembers()
            WidgetCenter.shared.reloadAllTimelines()
            SyncLog.cloudkit.info("upload cycle complete (km=\(km, privacy: .public))")
        } catch {
            SyncLog.cloudkit.error("upload failed — enqueueing: \(error.localizedDescription, privacy: .public)")
            await RetryQueue.shared.enqueue(vo2Max: vo2, weeklyKilometers: km, weekStart: weekStart)
        }
    }

    private func advanceAnchors(for trigger: Trigger) async throws {
        let types: [HKSampleType]
        switch trigger {
        case .observer(let type): types = [type]
        default: types = HealthKitManager.observedTypes
        }

        for type in types {
            let previous = SharedDataStore.hkAnchorData(for: type.identifier)
            let nextData = try await healthKit.advanceAnchor(for: type, from: previous)
            SharedDataStore.setHkAnchorData(nextData, for: type.identifier)
        }
    }

    private func drainRetryQueue() async {
        let pending = await RetryQueue.shared.snapshot()
        guard !pending.isEmpty else { return }
        SyncLog.queue.info("draining \(pending.count, privacy: .public) pending uploads")

        for entry in pending {
            do {
                try await cloudKit.updateMyStats(vo2Max: entry.vo2Max, weeklyKilometers: entry.weeklyKilometers)
                await RetryQueue.shared.remove(id: entry.id)
            } catch {
                SyncLog.queue.error("retry still failing; leaving in queue: \(error.localizedDescription, privacy: .public)")
                return
            }
        }
    }
}
