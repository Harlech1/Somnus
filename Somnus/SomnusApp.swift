//
//  SomnusApp.swift
//  Somnus
//
//  Created by Türker Kızılcık on 4.01.2025.
//

import SwiftUI

@main
struct SomnusApp: App {
    @StateObject private var alarmManager = AlarmManager()
    
    init() {
        let notificationDelegate = NotificationDelegate(alarmManager: alarmManager)
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(alarmManager)  // Provide alarmManager to all views
        }
    }
}
