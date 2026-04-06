//
//  SharedDataStore.swift
//  runboard
//
//  Created by Paul Goldschmidt on 06.04.26.
//

import Foundation

enum SharedDataStore {
    static let suiteName = "group.p3g3.runboard"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName)!
    }

    private enum Keys {
        static let boardCode = "boardCode"
        static let myRecordName = "myRecordName"
        static let displayName = "displayName"
        static let cachedMembers = "cachedMembers"
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
        return members
    }

    static func clearCache() {
        defaults.removeObject(forKey: Keys.cachedMembers)
    }
}
