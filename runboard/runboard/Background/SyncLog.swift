//
//  SyncLog.swift
//  runboard
//

import Foundation
import os

enum SyncLog {
    static let subsystem = "p3g3.runboard.sync"

    static let bootstrap = Logger(subsystem: subsystem, category: "bootstrap")
    static let observer = Logger(subsystem: subsystem, category: "observer")
    static let bgtask = Logger(subsystem: subsystem, category: "bgtask")
    static let cloudkit = Logger(subsystem: subsystem, category: "cloudkit")
    static let queue = Logger(subsystem: subsystem, category: "queue")
    static let hk = Logger(subsystem: subsystem, category: "healthkit")

    static let signposter = OSSignposter(subsystem: subsystem, category: "trace")
}
