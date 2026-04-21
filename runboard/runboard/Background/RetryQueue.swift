//
//  RetryQueue.swift
//  runboard
//

import Foundation
import os

struct PendingUpload: Codable, Identifiable {
    let id: UUID
    let createdAt: Date
    let vo2Max: Double?
    let weeklyKilometers: Double
    let weekStart: Date
}

actor RetryQueue {
    static let shared = RetryQueue()

    private let maxEntries = 50
    private let fileURL: URL?

    init() {
        let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: SharedDataStore.suiteName)
        self.fileURL = container?.appendingPathComponent("pending-uploads.json")
    }

    func enqueue(vo2Max: Double?, weeklyKilometers: Double, weekStart: Date) {
        var entries = load()
        entries.append(PendingUpload(
            id: UUID(),
            createdAt: Date(),
            vo2Max: vo2Max,
            weeklyKilometers: weeklyKilometers,
            weekStart: weekStart
        ))
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
            SyncLog.queue.fault("dropped oldest retry entries to enforce cap")
        }
        persist(entries)
        SyncLog.queue.info("enqueued pending upload, queue size=\(entries.count, privacy: .public)")
    }

    func snapshot() -> [PendingUpload] {
        load()
    }

    func remove(id: UUID) {
        var entries = load()
        entries.removeAll { $0.id == id }
        persist(entries)
    }

    func clear() {
        persist([])
    }

    private func load() -> [PendingUpload] {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder.iso8601.decode([PendingUpload].self, from: data)) ?? []
    }

    private func persist(_ entries: [PendingUpload]) {
        guard let fileURL else { return }
        do {
            let data = try JSONEncoder.iso8601.encode(entries)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            SyncLog.queue.error("failed to persist queue: \(error.localizedDescription, privacy: .public)")
        }
    }
}

private extension JSONEncoder {
    static let iso8601: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

private extension JSONDecoder {
    static let iso8601: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
