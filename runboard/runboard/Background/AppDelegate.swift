//
//  AppDelegate.swift
//  runboard
//

import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        BackgroundSyncCoordinator.shared.registerBackgroundTasks()
        BackgroundSyncCoordinator.shared.bootstrap()
        return true
    }
}
