import SwiftUI
import UserNotifications
import MediaPlayer
import AVFoundation

class AlarmManager: ObservableObject {
    @Published var alarms: [Alarm] = []
    private let maxNotifications = 64
    private let notificationInterval: TimeInterval = 2
    private var volumeView: MPVolumeView?
    private var volumeSlider: UISlider?
    private var audioPlayer: AVAudioPlayer?
    private var silentAudioPlayer: AVAudioPlayer?
    private var notificationDelegate: NotificationDelegate?
    
    init() {
        setupVolumeControl()
        setupAudioSession()
        setupSilentAudio()
        requestNotificationPermission()
        loadAlarms()
        setupNotificationHandling()
    }
    
    func setNotificationDelegate(_ delegate: NotificationDelegate) {
        notificationDelegate = delegate
    }
    
    private func setupVolumeControl() {
        volumeView = MPVolumeView(frame: CGRect.zero)
        if let view = volumeView {
            view.isHidden = true
            UIApplication.shared.windows.first?.addSubview(view)
            
            for subview in view.subviews {
                if let slider = subview as? UISlider {
                    slider.value = 0.2
                    volumeSlider = slider
                    break
                }
            }
        }
    }

    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            if let soundURL = Bundle.main.url(forResource: "alarm_sound", withExtension: "wav") {
                audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                audioPlayer?.numberOfLoops = -1
                audioPlayer?.prepareToPlay()
            }
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    private func setupSilentAudio() {
        do {
            if let silentURL = Bundle.main.url(forResource: "silence", withExtension: "mp3") {
                silentAudioPlayer = try AVAudioPlayer(contentsOf: silentURL)
                silentAudioPlayer?.numberOfLoops = -1  // Loop indefinitely
                silentAudioPlayer?.volume = 0.0       // Make sure it's silent
                silentAudioPlayer?.play()             // Start playing immediately
            }
        } catch {
            print("Failed to setup silent audio: \(error)")
        }
    }
    
    func maximizeVolume() {
        DispatchQueue.main.async {
            self.volumeSlider?.setValue(0.2, animated: false)
            self.volumeSlider?.sendActions(for: .touchUpInside)
        }
    }
    
    func playAlarmSound() {
        do {
            // Pause silent audio while alarm is playing
            silentAudioPlayer?.pause()
            
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer?.play()
        } catch {
            print("Failed to play alarm sound: \(error)")
        }
    }
    
    func stopAlarmSound() {
        audioPlayer?.stop()
        // Resume silent audio
        silentAudioPlayer?.play()
    }
    
    func setupNotificationHandling() {
        NotificationCenter.default.addObserver(self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil)
    }
    
    @objc func handleAppDidBecomeActive() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        stopAlarmSound()
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
        
        var components = calendar.dateComponents([.hour, .minute], from: alarm.time)
        components.second = 0
        guard let nextAlarmTime = calendar.nextDate(after: now,
                                                  matching: components,
                                                  matchingPolicy: .nextTime) else {
            return
        }
        
        let timeUntilAlarm = nextAlarmTime.timeIntervalSince(now)
        
        Timer.scheduledTimer(withTimeInterval: timeUntilAlarm, repeats: false) { [weak self] _ in
            self?.startAlarmSequence()
        }
        
        for i in 0..<maxNotifications {
            let content = UNMutableNotificationContent()
            content.title = "Wake Up!"
            content.body = "Time to wake up! (\(i + 1) of \(maxNotifications))"
            
            let timeInterval = TimeInterval(i) * notificationInterval
            let notificationTime = nextAlarmTime.addingTimeInterval(timeInterval)
            
            let triggerComponents = calendar.dateComponents([.hour, .minute, .second], from: notificationTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: true)
            
            let identifier = "\(alarm.id.uuidString)-\(i)"
            let request = UNNotificationRequest(identifier: identifier,
                                              content: content,
                                              trigger: trigger)
            
            UNUserNotificationCenter.current().add(request)
        }
    }
    
    private func startAlarmSequence() {
        maximizeVolume()
        playAlarmSound()
        
        for i in 1..<maxNotifications {
            let timeInterval = TimeInterval(i) * notificationInterval
            Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
                self?.maximizeVolume()
                self?.playAlarmSound()
            }
        }
    }
    
    func cancelNotification(for alarm: Alarm) {
        let identifiers = (0..<maxNotifications).map { "\(alarm.id.uuidString)-\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        stopAlarmSound()
    }
    
    deinit {
        // Clean up audio players
        silentAudioPlayer?.stop()
        audioPlayer?.stop()
    }
} 
