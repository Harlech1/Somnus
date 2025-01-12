import UserNotifications
import SwiftUI

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, ObservableObject {
    var alarmManager: AlarmManager?
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
        guard let alarmManager = alarmManager else { return }
        
        // Pause the alarm while solving math quiz
        alarmManager.pauseAlarm()
        
        // Remove all notifications while solving
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        alarmManager.showMathQuiz = true
        completionHandler()
    }
} 
