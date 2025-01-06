import UserNotifications

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let alarmManager: AlarmManager
    
    init(alarmManager: AlarmManager) {
        self.alarmManager = alarmManager
        super.init()
    }

    // called just before the notification is shown
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        alarmManager.playAlarmSound()
        completionHandler([.banner, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
        alarmManager.stopAlarmSound()
        completionHandler()
    }
} 
