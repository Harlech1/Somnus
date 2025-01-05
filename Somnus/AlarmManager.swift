import SwiftUI
import UserNotifications
import AVFoundation
import BackgroundTasks

@Observable final class AlarmManager: NSObject {
    static let shared = AlarmManager()
    var alarms: [Alarm] = []
    private var isAlarmActive = false
    private var activeTimer: Timer?
    
    override init() {
        super.init()
        setupNotifications()
    }
    
    private func setupNotifications() {
        // Request all possible permissions
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound, .provisional, .criticalAlert]
        ) { success, error in
            if success {
                print("All notifications permissions granted")
            } else if let error = error {
                print("Error requesting permissions: \(error)")
            }
        }
        
        UNUserNotificationCenter.current().delegate = self
    }
    
    func addAlarm(_ alarm: Alarm) {
        alarms.append(alarm)
        scheduleAlarm(alarm)
        saveAlarms()
    }
    
    func toggleAlarm(_ alarm: Alarm) {
        if let index = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[index].isEnabled = !alarms[index].isEnabled
            if alarms[index].isEnabled {
                scheduleAlarm(alarms[index])
            } else {
                stopAlarm(alarms[index])
            }
            saveAlarms()
        }
    }
    
    private func scheduleAlarm(_ alarm: Alarm) {
        guard alarm.isEnabled else { return }
        
        // Cancel any existing notifications for this alarm
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [alarm.id.uuidString])
        
        let content = UNMutableNotificationContent()
        content.title = "Wake Up!"
        content.body = alarm.label.isEmpty ? "Time to wake up!" : alarm.label
        content.sound = .default
        content.interruptionLevel = .critical
        content.userInfo = ["alarmID": alarm.id.uuidString]
        
        // Schedule the initial trigger
        let components = Calendar.current.dateComponents([.hour, .minute], from: alarm.time)
        var triggerDate = Calendar.current.date(bySettingHour: components.hour ?? 0, minute: components.minute ?? 0, second: 0, of: Date()) ?? Date()
        
        if triggerDate < Date() {
            triggerDate = Calendar.current.date(byAddingDay: 1, to: triggerDate) ?? Date()
        }
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.hour, .minute], from: triggerDate),
            repeats: alarm.repeatDays.isEmpty ? false : true
        )
        
        let request = UNNotificationRequest(
            identifier: alarm.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling alarm: \(error)")
            }
        }
    }
    
    private func startRepeatingNotifications(for alarm: Alarm) {
        guard !isAlarmActive else { return }
        isAlarmActive = true
        
        // Function to send a notification
        func sendNotification() {
            // Remove previous notifications first
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
            
            // Create and send new notification
            let content = UNMutableNotificationContent()
            content.title = "Wake Up!"
            content.body = "Time: \(Date().formatted(date: .omitted, time: .standard))"
            content.sound = .default
            content.interruptionLevel = .critical
            
            // Send immediate notification
            let immediateRequest = UNNotificationRequest(
                identifier: "immediate-\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(immediateRequest)
            
            // Schedule next notification in 2 seconds
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
            let nextRequest = UNNotificationRequest(
                identifier: "next-\(UUID().uuidString)",
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(nextRequest)
            
            // Play sound and vibrate
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            AudioServicesPlaySystemSound(1005)
        }
        
        // Send first notification immediately
        sendNotification()
        
        // Set up timer to send notifications every second
        activeTimer?.invalidate()
        activeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard self?.isAlarmActive == true else { return }
            sendNotification()
        }
        
        // Make sure timer runs in background
        if let timer = activeTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    func stopAlarm(_ alarm: Alarm? = nil) {
        isAlarmActive = false
        activeTimer?.invalidate()
        activeTimer = nil
        
        // Remove all pending and delivered notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        
        if let alarm = alarm {
            if !alarm.repeatDays.isEmpty {
                // For repeating alarms, reschedule for next occurrence
                scheduleAlarm(alarm)
            } else {
                // For one-time alarms, disable it
                if let index = alarms.firstIndex(where: { $0.id == alarm.id }) {
                    alarms[index].isEnabled = false
                    saveAlarms()
                }
            }
        }
    }
    
    func snoozeAlarm(_ alarm: Alarm) {
        stopAlarm(alarm)
        
        // Schedule a new notification for 5 minutes later
        let content = UNMutableNotificationContent()
        content.title = "Snoozed Alarm"
        content.body = alarm.label.isEmpty ? "Time to wake up!" : alarm.label
        content.sound = .default
        content.interruptionLevel = .critical
        content.userInfo = ["alarmID": alarm.id.uuidString]
        
        // Create a trigger for 5 minutes from now
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 5 * 60, // 5 minutes
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "snooze-\(alarm.id)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func saveAlarms() {
        if let encoded = try? JSONEncoder().encode(alarms) {
            UserDefaults.standard.set(encoded, forKey: "SavedAlarms")
        }
    }
    
    func loadAlarms() {
        if let savedAlarms = UserDefaults.standard.data(forKey: "SavedAlarms"),
           let decodedAlarms = try? JSONDecoder().decode([Alarm].self, from: savedAlarms) {
            alarms = decodedAlarms
            for alarm in alarms where alarm.isEnabled {
                scheduleAlarm(alarm)
            }
        }
    }
}

extension AlarmManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // If this is the initial alarm notification, start the repeating notifications
        if let alarmID = notification.request.content.userInfo["alarmID"] as? String,
           let alarm = alarms.first(where: { $0.id.uuidString == alarmID }) {
            startRepeatingNotifications(for: alarm)
        }
        
        // Show the notification with all options
        completionHandler([.banner, .sound, .list, .badge])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == UNNotificationDismissActionIdentifier {
            // If user dismissed the notification, send another one immediately
            if let alarmID = response.notification.request.content.userInfo["alarmID"] as? String,
               let alarm = alarms.first(where: { $0.id.uuidString == alarmID }) {
                startRepeatingNotifications(for: alarm)
            }
        } else {
            // For any other interaction, stop the alarm
            stopAlarm()
        }
        completionHandler()
    }
}

private extension Calendar {
    func date(byAddingDay days: Int, to date: Date) -> Date? {
        return self.date(byAdding: .day, value: days, to: date)
    }
} 
