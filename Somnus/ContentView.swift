//
//  ContentView.swift
//  Somnus
//
//  Created by Türker Kızılcık on 4.01.2025.
//

import SwiftUI
import UserNotifications

struct Alarm: Identifiable, Codable {
    let id: UUID
    var time: Date
    var isEnabled: Bool
}

class AlarmManager: ObservableObject {
    @Published var alarms: [Alarm] = []
    private let maxNotifications = 64 // iOS notification limit
    private let notificationInterval: TimeInterval = 3 // 3 seconds between notifications
    
    init() {
        requestNotificationPermission()
        loadAlarms()
        setupNotificationHandling()
    }
    
    func setupNotificationHandling() {
        NotificationCenter.default.addObserver(self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil)
        
        UNUserNotificationCenter.current().delegate = UIApplication.shared.delegate as? UNUserNotificationCenterDelegate
    }
    
    @objc func handleAppDidBecomeActive() {
        // Clear all pending notifications when app becomes active
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else {
                print("Notification permission denied")
            }
        }
    }
    
    func loadAlarms() {
        if let data = UserDefaults.standard.data(forKey: "savedAlarms"),
           let decodedAlarms = try? JSONDecoder().decode([Alarm].self, from: data) {
            alarms = decodedAlarms
        }
    }
    
    func saveAlarms() {
        if let encoded = try? JSONEncoder().encode(alarms) {
            UserDefaults.standard.set(encoded, forKey: "savedAlarms")
        }
    }
    
    func addAlarm(time: Date) {
        let newAlarm = Alarm(id: UUID(), time: time, isEnabled: true)
        alarms.append(newAlarm)
        scheduleNotification(for: newAlarm)
        saveAlarms()
    }
    
    func toggleAlarm(_ alarm: Alarm) {
        if let index = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[index].isEnabled.toggle()
            if alarms[index].isEnabled {
                scheduleNotification(for: alarms[index])
            } else {
                cancelNotification(for: alarm)
            }
            saveAlarms()
        }
    }
    
    func deleteAlarm(_ alarm: Alarm) {
        alarms.removeAll { $0.id == alarm.id }
        cancelNotification(for: alarm)
        saveAlarms()
    }
    
    func scheduleNotification(for alarm: Alarm) {
        let calendar = Calendar.current
        let now = Date()
        
        // Get the next occurrence of the alarm time
        var components = calendar.dateComponents([.hour, .minute], from: alarm.time)
        components.second = 0
        guard let nextAlarmTime = calendar.nextDate(after: now,
                                                  matching: components,
                                                  matchingPolicy: .nextTime) else {
            return
        }
        
        // Schedule multiple notifications with 3-second delays
        for i in 0..<maxNotifications {
            let content = UNMutableNotificationContent()
            content.title = "Wake Up!"
            content.body = "Time to wake up! (\(i + 1) of \(maxNotifications))"
            content.sound = .default
            
            // Calculate the delay for this notification
            let timeInterval = TimeInterval(i) * notificationInterval
            let notificationTime = nextAlarmTime.addingTimeInterval(timeInterval)
            
            // Create components for the daily repeating trigger
            let triggerComponents = calendar.dateComponents([.hour, .minute, .second], from: notificationTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: true)
            
            // Create unique identifier for each notification
            let identifier = "\(alarm.id.uuidString)-\(i)"
            let request = UNNotificationRequest(identifier: identifier,
                                              content: content,
                                              trigger: trigger)
            
            UNUserNotificationCenter.current().add(request)
        }
    }
    
    func cancelNotification(for alarm: Alarm) {
        // Cancel all notifications for this alarm
        let identifiers = (0..<maxNotifications).map { "\(alarm.id.uuidString)-\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

struct ContentView: View {
    @StateObject private var alarmManager = AlarmManager()
    @State private var showingAddAlarm = false
    @State private var selectedTime = Date()
    
    var body: some View {
        NavigationView {
            List {
                ForEach(alarmManager.alarms) { alarm in
                    AlarmRow(alarm: alarm, alarmManager: alarmManager)
                }
                .onDelete { indexSet in
                    indexSet.forEach { index in
                        alarmManager.deleteAlarm(alarmManager.alarms[index])
                    }
                }
            }
            .navigationTitle("Alarms")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddAlarm = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddAlarm) {
                AddAlarmView(isPresented: $showingAddAlarm,
                            selectedTime: $selectedTime,
                            alarmManager: alarmManager)
            }
            .onAppear {
                // Clear notifications when app opens
                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            }
        }
    }
}

struct AlarmRow: View {
    let alarm: Alarm
    @ObservedObject var alarmManager: AlarmManager
    
    var body: some View {
        HStack {
            Text(alarm.time, style: .time)
                .font(.title2)
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { alarm.isEnabled },
                set: { _ in alarmManager.toggleAlarm(alarm) }
            ))
        }
        .padding(.vertical, 8)
    }
}

struct AddAlarmView: View {
    @Binding var isPresented: Bool
    @Binding var selectedTime: Date
    @ObservedObject var alarmManager: AlarmManager
    
    var body: some View {
        NavigationView {
            Form {
                DatePicker("Time",
                          selection: $selectedTime,
                          displayedComponents: .hourAndMinute)
                    .datePickerStyle(WheelDatePickerStyle())
                    .labelsHidden()
            }
            .navigationTitle("Add Alarm")
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                },
                trailing: Button("Save") {
                    alarmManager.addAlarm(time: selectedTime)
                    isPresented = false
                }
            )
        }
    }
}

#Preview {
    ContentView()
}
