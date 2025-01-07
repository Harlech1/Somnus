//
//  SomnusApp.swift
//  Somnus
//
//  Created by Türker Kızılcık on 4.01.2025.
//

import SwiftUI
import UserNotifications

@main
struct SomnusApp: App {
    @StateObject private var alarmManager = AlarmManager()
    private let notificationDelegate: NotificationDelegate
    
    init() {
        let manager = AlarmManager()
        _alarmManager = StateObject(wrappedValue: manager)
        notificationDelegate = NotificationDelegate(alarmManager: manager)
        manager.setNotificationDelegate(notificationDelegate)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(alarmManager)
        }
    }
}
