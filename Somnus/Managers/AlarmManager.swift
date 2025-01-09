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
                    slider.value = 0.8
                    volumeSlider = slider
                    break
                }
            }
        }
    }
    
    private func maximizeVolume() {
        DispatchQueue.main.async {
            self.volumeSlider?.setValue(0.8, animated: false)
            self.volumeSlider?.sendActions(for: .touchUpInside)
        }
    }
    
    private func setupAudio() {
        do {
            // Setup audio session
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback)
            try session.setActive(true)
            
            // Setup alarm sound
            if let soundURL = Bundle.main.url(forResource: "alarm_sound", withExtension: "wav") {
                audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                audioPlayer?.numberOfLoops = -1
                audioPlayer?.prepareToPlay()
            }
            
            // Setup silent audio for background capability
            if let silentURL = Bundle.main.url(forResource: "silence", withExtension: "mp3") {
                silentPlayer = try AVAudioPlayer(contentsOf: silentURL)
                silentPlayer?.numberOfLoops = -1
                silentPlayer?.volume = 0.0
                silentPlayer?.play()  // Start playing silent sound immediately
            }
        } catch {
            print("Failed to setup audio: \(error)")
        }
    }
    
    func playAlarmSound() {
        silentPlayer?.pause()  // Pause silent sound
        maximizeVolume()      // Ensure volume is maximum
        audioPlayer?.play()
    }
    
    func stopAlarmSound() {
        audioPlayer?.stop()
        silentPlayer?.play()  // Resume silent sound to keep background capability
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
        
        // Calculate delay until alarm time
        let timeUntilAlarm = alarmTime.timeIntervalSince(now)
        
        // Schedule alarm sound
        Timer.scheduledTimer(withTimeInterval: timeUntilAlarm, repeats: false) { [weak self] _ in
            self?.playAlarmSound()
        }
        
        // Schedule notifications starting from 0 to be consistent
        for i in 0..<64 {
            let content = UNMutableNotificationContent()
            content.title = "Wake Up!"
            content.body = "Time to wake up! (\(i) of 63)"
            
            let notificationTime = alarmTime.addingTimeInterval(TimeInterval(i * 2))
            let triggerComponents = calendar.dateComponents([.hour, .minute, .second], from: notificationTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
            
            let identifier = "\(alarm.id.uuidString)-\(i)"
            let request = UNNotificationRequest(identifier: identifier,
                                              content: content,
                                              trigger: trigger)
            
            UNUserNotificationCenter.current().add(request)
        }
    }
    
    func cancelNotifications(for alarm: Alarm) {
        let identifiers = (0..<64).map { "\(alarm.id.uuidString)-\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
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
