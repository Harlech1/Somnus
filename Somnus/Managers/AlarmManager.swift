import SwiftUI
import UserNotifications
import AVFoundation
import MediaPlayer
import AudioToolbox

class AlarmManager: ObservableObject {
    @Published var alarms: [Alarm] = []
    @Published var showMathQuiz = false
    @Published var isAlarmPlaying = false
    var audioPlayer: AVAudioPlayer?
    var silentPlayer: AVAudioPlayer?
    private let volumeManager = VolumeManager.shared
    private var notificationDelegate: NotificationDelegate?
    
    init() {
        setupAudio()
        requestNotificationPermission()
        loadAlarms()
        setupSceneObserver()
    }
    
    func setNotificationDelegate(_ delegate: NotificationDelegate) {
        notificationDelegate = delegate
        UNUserNotificationCenter.current().delegate = delegate
    }
    
    private func setupAudio() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback)
            try session.setActive(true)
            
            if let soundURL = Bundle.main.url(forResource: "alarm_sound", withExtension: "wav") {
                audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                audioPlayer?.numberOfLoops = -1
                audioPlayer?.prepareToPlay()
            }

            if let silentURL = Bundle.main.url(forResource: "silence", withExtension: "mp3") {
                silentPlayer = try AVAudioPlayer(contentsOf: silentURL)
                silentPlayer?.numberOfLoops = -1
                silentPlayer?.volume = 0.0
                silentPlayer?.play()
            }
        } catch {
            print("Failed to setup audio: \(error)")
        }
    }
    
    func playAlarmSound() {
        silentPlayer?.pause()
        volumeManager.setVolume()
        audioPlayer?.play()
        isAlarmPlaying = true
        showMathQuiz = true
    }
    
    func pauseAlarm() {
        audioPlayer?.pause()
        silentPlayer?.play()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    
    func resumeAlarm() {
        silentPlayer?.pause()
        audioPlayer?.play()
        isAlarmPlaying = true
        AudioServicesPlayAlertSoundWithCompletion(SystemSoundID(kSystemSoundID_Vibrate)) { }
    }
    
    func stopAlarmSound() {
        audioPlayer?.stop()
        silentPlayer?.play()
        isAlarmPlaying = false
        
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    func startImmediateNotifications(for alarm: Alarm) {
        // Send first notification immediately
        let content = UNMutableNotificationContent()
        content.title = "Wake Up!"
        content.body = "Time to wake up! Tap to stop."
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: "\(alarm.id.uuidString)-\(Date().timeIntervalSince1970)",
                                          content: content,
                                          trigger: trigger)
        UNUserNotificationCenter.current().add(request)
        
        // Create intense haptic pattern
        createIntenseHapticFeedback()
        
        // Then start the timer for subsequent notifications with 5-second interval
        Timer.scheduledTimer(withTimeInterval: 4.9, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            if self.audioPlayer?.isPlaying == true {
                let content = UNMutableNotificationContent()
                content.title = "Wake Up!"
                content.body = "Time to wake up! Tap to stop."
                
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
                let request = UNNotificationRequest(identifier: "\(alarm.id.uuidString)-\(Date().timeIntervalSince1970)",
                                                  content: content,
                                                  trigger: trigger)
                
                UNUserNotificationCenter.current().add(request)
                
                // Create intense haptic pattern for each notification
                createIntenseHapticFeedback()
            } else {
                timer.invalidate()
            }
        }
    }
    
    private func createIntenseHapticFeedback() {
        AudioServicesPlayAlertSoundWithCompletion(SystemSoundID(kSystemSoundID_Vibrate)) { }
    }
    
    func scheduleNotification(for alarm: Alarm) {
        let calendar = Calendar.current
        let now = Date()
        
        var components = calendar.dateComponents([.hour, .minute], from: alarm.time)
        components.second = 0
        
        guard let alarmTime = calendar.nextDate(after: now,
                                              matching: components,
                                              matchingPolicy: .nextTime) else {
            return
        }
        
        Timer.scheduledTimer(withTimeInterval: alarmTime.timeIntervalSince(now), repeats: false) { [weak self] _ in
            self?.playAlarmSound()
            AudioServicesPlayAlertSoundWithCompletion(SystemSoundID(kSystemSoundID_Vibrate)) { }
            
            Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] timer in
                guard let self = self else { return }
                if self.audioPlayer?.isPlaying == true {
                    let content = UNMutableNotificationContent()
                    content.title = "Wake Up!"
                    content.body = "Time to wake up! Tap to stop."
                    
                    // Create an immediate trigger
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

                    let request = UNNotificationRequest(identifier: "\(alarm.id.uuidString)-\(Date().timeIntervalSince1970)",
                                                      content: content,
                                                      trigger: trigger)
                    
                    UNUserNotificationCenter.current().add(request)
                    AudioServicesPlayAlertSoundWithCompletion(SystemSoundID(kSystemSoundID_Vibrate)) { }
                } else {
                    timer.invalidate()
                }
            }
        }
        
        // Schedule initial notification
        let content = UNMutableNotificationContent()
        content.title = "Wake Up!"
        content.body = "Time to wake up! Tap to stop."
        
        let triggerComponents = Calendar.current.dateComponents([.hour, .minute], from: alarm.time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        
        let request = UNNotificationRequest(identifier: alarm.id.uuidString,
                                          content: content,
                                          trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func cancelNotifications(for alarm: Alarm) {
        // Remove all notifications with this alarm's UUID prefix
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiersToRemove = requests.filter { $0.identifier.hasPrefix(alarm.id.uuidString) }
                                            .map { $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
        }
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            let identifiersToRemove = notifications.filter { $0.request.identifier.hasPrefix(alarm.id.uuidString) }
                                                .map { $0.request.identifier }
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiersToRemove)
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else {
                print("Notification permission denied")
            }
        }
    }

    // MARK: - Termination Management
    
    private func setupSceneObserver() {
        NotificationCenter.default.addObserver(self,
                                             selector: #selector(appWillTerminate),
                                             name: UIApplication.willTerminateNotification,
                                             object: nil)
        
        NotificationCenter.default.addObserver(self,
                                             selector: #selector(appDidBecomeActive),
                                             name: UIApplication.didBecomeActiveNotification,
                                             object: nil)
    }
    
    @objc private func appWillTerminate() {
        let activeAlarms = alarms.filter { $0.isEnabled }
        if !activeAlarms.isEmpty {
            let content = UNMutableNotificationContent()
            content.title = "⚠️ Warning: Alarms Will Not Work"
            content.body = "You have closed the app completely. Your alarms will not sound until you open the app again."
            content.sound = .default
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
            let request = UNNotificationRequest(identifier: "app-terminated-warning",
                                              content: content,
                                              trigger: trigger)
            
            UNUserNotificationCenter.current().add(request)
        }
    }
    
    @objc private func appDidBecomeActive() {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["app-terminated-warning"])
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["app-terminated-warning"])
    }

    // MARK: - Alarm Management
    
    func loadAlarms() {
        if let data = UserDefaults.standard.data(forKey: "savedAlarms"),
           let decoded = try? JSONDecoder().decode([Alarm].self, from: data) {
            alarms = decoded
        }
    }
    
    func saveAlarms() {
        if let encoded = try? JSONEncoder().encode(alarms) {
            UserDefaults.standard.set(encoded, forKey: "savedAlarms")
        }
    }
    
    func addAlarm(time: Date) {
        let alarm = Alarm(id: UUID(), time: time, isEnabled: true)
        alarms.append(alarm)
        scheduleNotification(for: alarm)
        saveAlarms()
    }
    
    func toggleAlarm(_ alarm: Alarm) {
        if let index = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[index].isEnabled.toggle()
            if alarms[index].isEnabled {
                scheduleNotification(for: alarms[index])
            } else {
                cancelNotifications(for: alarm)
            }
            saveAlarms()
        }
    }
    
    func deleteAlarm(_ alarm: Alarm) {
        alarms.removeAll { $0.id == alarm.id }
        cancelNotifications(for: alarm)
        saveAlarms()
    }
} 
