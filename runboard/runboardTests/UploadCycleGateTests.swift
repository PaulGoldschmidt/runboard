//
//  UploadCycleGateTests.swift
//  runboardTests
//

import Testing
import Foundation
@testable import runboard

struct UploadCycleGateTests {

    /// Records cycle activity on the main actor, where the gate runs its work.
    @MainActor
    final class Recorder {
        private(set) var started = 0
        private(set) var finished = 0
        private(set) var maxConcurrent = 0
        private var running = 0

        func cycle() async {
            started += 1
            running += 1
            maxConcurrent = max(maxConcurrent, running)
            try? await Task.sleep(for: .milliseconds(100))
            running -= 1
            finished += 1
        }
    }

    // Regression test for the 1.0.4-rc launch hang. The coordinator used to
    // keep its own `inflight` task and clear it *after* awaiting it; a queued
    // trigger that resumed before that owner re-awaited the already-finished
    // task in a tight loop on the main actor (awaiting a finished task does not
    // yield), and the watchdog killed the app. A stuck main actor can't be
    // observed from the main actor, so the triggers are raced against a
    // detached watchdog instead of being awaited directly.
    //
    // The watchdog is deliberately generous: the test host is the app itself,
    // and on a cold CI simulator its main thread can be blocked for ~10 s
    // after launch, which stalls these cycles without anything being wrong.
    // A broken gate never finishes at all, so a long timeout costs nothing
    // when the code is right.
    @Test func queuedTriggersNeverStallTheMainActor() async {
        let gate = await UploadCycleGate()
        let recorder = await Recorder()

        // Same shape as app launch: two HealthKit observer wakes and one
        // foreground refresh all land while the first cycle is still running.
        let triggers = [
            Task { @MainActor in await gate.run { await recorder.cycle() } },
            Task { @MainActor in await gate.run { await recorder.cycle() } },
            Task { @MainActor in await gate.run(joinRunning: true) { await recorder.cycle() } },
        ]

        let outcome = await race({ for trigger in triggers { await trigger.value } }, timeout: .seconds(60))
        guard outcome == .completed else {
            Issue.record("triggers never finished — the gate is spinning on the main actor")
            return
        }

        // Two observer wakes → two serialized cycles; the foreground refresh
        // joined the running one instead of adding a third.
        #expect(await recorder.started == 2)
        #expect(await recorder.finished == 2)
        #expect(await recorder.maxConcurrent == 1)
    }

    @Test func joiningCallerWaitsForRunningCycle() async {
        let gate = await UploadCycleGate()
        let recorder = await Recorder()

        let first = Task { @MainActor in await gate.run { await recorder.cycle() } }
        let joiner = Task { @MainActor in await gate.run(joinRunning: true) { await recorder.cycle() } }

        await joiner.value
        // By the time the joiner returns the cycle it attached to is finished.
        #expect(await recorder.finished == 1)
        await first.value
        #expect(await recorder.started == 1)
    }

    @Test func joiningCallerRunsWhenNothingIsInFlight() async {
        let gate = await UploadCycleGate()
        let recorder = await Recorder()

        await gate.run(joinRunning: true) { await recorder.cycle() }
        #expect(await recorder.finished == 1)
    }

    // MARK: - Helpers

    private enum Outcome { case completed, timedOut }

    /// Resolves to `.completed` when `work` finishes, or `.timedOut` first.
    /// Unstructured on purpose: a task group would have to await the possibly
    /// stuck worker before it could return.
    private func race(_ work: @escaping @Sendable () async -> Void, timeout: Duration) async -> Outcome {
        let winner = FirstWriter<Outcome>()
        return await withCheckedContinuation { continuation in
            Task.detached {
                await work()
                await winner.resume(continuation, with: .completed)
            }
            Task.detached {
                try? await Task.sleep(for: timeout)
                await winner.resume(continuation, with: .timedOut)
            }
        }
    }

    private actor FirstWriter<Value: Sendable> {
        private var resumed = false

        func resume(_ continuation: CheckedContinuation<Value, Never>, with value: Value) {
            guard !resumed else { return }
            resumed = true
            continuation.resume(returning: value)
        }
    }
}
