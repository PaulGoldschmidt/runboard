//
//  SharedDataStore.swift
//  runboard
//
//  Created by Paul Goldschmidt on 06.04.26.
//

import Foundation

enum SharedDataStore {
    nonisolated static let suiteName = "group.p3g3.runboard"
    nonisolated static let cloudKitContainerID = "iCloud.p3g3.runboard"

    static var defaults: UserDefaults = UserDefaults(suiteName: suiteName) ?? .standard

    private enum Keys {
        static let boardCode = "boardCode"
        static let myRecordName = "myRecordName"
        static let displayName = "displayName"
        static let cachedMembers = "cachedMembers"
        static let hkAnchorPrefix = "hkAnchor."
    }

    static var boardCode: String? {
        get { defaults.string(forKey: Keys.boardCode) }
        set { defaults.set(newValue, forKey: Keys.boardCode) }
    }

    static var myRecordName: String? {
        get { defaults.string(forKey: Keys.myRecordName) }
        set { defaults.set(newValue, forKey: Keys.myRecordName) }
    }

    static var displayName: String? {
        get { defaults.string(forKey: Keys.displayName) }
        set { defaults.set(newValue, forKey: Keys.displayName) }
    }

    static func cacheMembers(_ members: [BoardMember]) {
        if let data = try? JSONEncoder().encode(members) {
            defaults.set(data, forKey: Keys.cachedMembers)
        }
    }

    static func loadCachedMembers() -> [BoardMember] {
        guard let data = defaults.data(forKey: Keys.cachedMembers),
              let members = try? JSONDecoder().decode([BoardMember].self, from: data) else {
            return []
        }
        return members.deduplicatedByNameAndStats()
    }

    static func clearCache() {
        defaults.removeObject(forKey: Keys.cachedMembers)
    }

    static func hkAnchorData(for typeIdentifier: String) -> Data? {
        defaults.data(forKey: Keys.hkAnchorPrefix + typeIdentifier)
    }

    static func setHkAnchorData(_ data: Data?, for typeIdentifier: String) {
        let key = Keys.hkAnchorPrefix + typeIdentifier
        if let data {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
