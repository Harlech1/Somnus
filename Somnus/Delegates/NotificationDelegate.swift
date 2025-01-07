import UserNotifications

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let alarmManager: AlarmManager
    
    init(alarmManager: AlarmManager) {
        self.alarmManager = alarmManager
        super.init()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
        print("🔔 Notification received: \(response.notification.request.identifier)")
        
        // Log user interaction type
        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            print("👆 User tapped the notification")
        case UNNotificationDismissActionIdentifier:
            print("👋 User swiped to dismiss")
        default:
            print("❓ Unknown action: \(response.actionIdentifier)")
        }
        
        let fullId = response.notification.request.identifier
        if let lastHyphenIndex = fullId.lastIndex(of: "-") {
            let alarmId = String(fullId[..<lastHyphenIndex])
            print("📱 Extracted alarm ID: \(alarmId)")
            
            if let uuid = UUID(uuidString: alarmId) {
                print("✅ Valid UUID: \(uuid)")
                let identifiers = (0..<64).map { "\(uuid)-\($0)" }
                print("🗑️ Attempting to remove notifications with IDs: \(identifiers.first ?? "none") to \(identifiers.last ?? "none")")
                
                // Remove both pending and delivered notifications
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiers)
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
                
                print("✨ Removed notifications for alarm: \(uuid)")
            } else {
                print("❌ Invalid UUID from identifier: \(alarmId)")
            }
        }
        
        print("🔕 Stopping alarm sound")
        alarmManager.stopAlarmSound()
        completionHandler()
    }
} 
