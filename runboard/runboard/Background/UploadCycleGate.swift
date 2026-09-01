//
//  UploadCycleGate.swift
//  runboard
//

import Foundation

/// Serializes upload cycles so at most one runs at a time.
///
/// Callers that arrive while a cycle is running either queue their own cycle
/// behind it (HealthKit observer wakes, BGTask — new samples must never be
/// skipped) or, with `joinRunning`, just wait for the running one and return
/// (foreground refreshes only need *a* fresh result, not their own).
@MainActor
final class UploadCycleGate {
    private var inflight: Task<Void, Never>?

    func run(joinRunning: Bool = false, _ work: @escaping @MainActor () async -> Void) async {
        if joinRunning, let existing = inflight {
            await existing.value
            return
        }

        // Every task stored in `inflight` clears it as its own last step, before
        // it completes, so a non-nil value is always a still-running cycle and
        // this await genuinely suspends. Awaiting an already-finished task
        // returns without yielding the main actor; when the owner was the one
        // responsible for clearing `inflight`, a waiter that resumed before it
        // re-awaited the finished task forever and hung the main thread.
        while let existing = inflight {
            await existing.value
        }

        let task = Task { @MainActor [self] in
            await work()
            inflight = nil
        }
        inflight = task
        await task.value
    }
}
