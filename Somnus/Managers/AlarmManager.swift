import SwiftUI
import UserNotifications
import AVFoundation
import MediaPlayer

class AlarmManager: ObservableObject {
    @Published var alarms: [Alarm] = []
    private var audioPlayer: AVAudioPlayer?
    private var silentPlayer: AVAudioPlayer?
    private var volumeView: MPVolumeView?
    private var volumeSlider: UISlider?
    private var notificationDelegate: NotificationDelegate?
    
    init() {
        setupVolumeControl()
        setupAudio()
        requestNotificationPermission()
        loadAlarms()
        setupScenePhaseObserver()
    }
    
    private func setupScenePhaseObserver() {
        NotificationCenter.default.addObserver(self,
                                             selector: #selector(appWillTerminate),
                                             name: UIApplication.willTerminateNotification,
                                             object: nil)
    }

    @objc private func appWillTerminate() {
        let activeAlarms = alarms.filter { $0.isEnabled }
        if !activeAlarms.isEmpty {
            let content = UNMutableNotificationContent()
            content.title = "⚠️ Warning: Alarms Will Not Work"
            content.body = "You have closed the app completely. Your alarms will not sound until you open the app again."
            content.sound = .default
            
            // Show notification after 5 seconds
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
            let request = UNNotificationRequest(identifier: "app-terminated-warning",
                                              content: content,
                                              trigger: trigger)
            
            UNUserNotificationCenter.current().add(request)
        }
    }
    
    func setNotificationDelegate(_ delegate: NotificationDelegate) {
        notificationDelegate = delegate
        UNUserNotificationCenter.current().delegate = delegate
    }
    
    private func setupVolumeControl() {
        volumeView = MPVolumeView(frame: CGRect.zero)
        if let view = volumeView {
            view.isHidden = true
            UIApplication.shared.windows.first?.addSubview(view)
            
            for subview in view.subviews {
                if let slider = subview as? UISlider {
                    slider.value = 0.3
                    volumeSlider = slider
                    break
                }
            }
        }
    }
    
    private func maximizeVolume() {
        DispatchQueue.main.async {
            self.volumeSlider?.setValue(0.3, animated: false)
            self.volumeSlider?.sendActions(for: .touchUpInside)
        }
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
        maximizeVolume()
        audioPlayer?.play()
    }
    
    func stopAlarmSound() {
        audioPlayer?.stop()
        silentPlayer?.play()
        
        // Clean up all notifications when alarm is stopped
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
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
            
            Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
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
