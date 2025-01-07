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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(alarmManager)
                .onAppear {
                    let delegate = NotificationDelegate(alarmManager: alarmManager)
                    UNUserNotificationCenter.current().delegate = delegate
                    alarmManager.setNotificationDelegate(delegate)
                }
        }
    }
}
