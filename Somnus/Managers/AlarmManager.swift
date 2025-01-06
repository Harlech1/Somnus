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
    private var notificationDelegate: NotificationDelegate?
    private var audioPlayer: AVAudioPlayer?
    
    init() {
        setupVolumeControl()
        setupAudioSession()
        requestNotificationPermission()
        loadAlarms()
        setupNotificationHandling()
    }
    
    private func setupVolumeControl() {
        volumeView = MPVolumeView(frame: CGRect.zero)
        if let view = volumeView {
            view.isHidden = true
            UIApplication.shared.windows.first?.addSubview(view)
            
            for subview in view.subviews {
                if let slider = subview as? UISlider {
                    slider.value = 1.0
                    volumeSlider = slider
                    break
                }
            }
        }
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, 
                                   mode: .default,
                                   options: [.defaultToSpeaker])
            try audioSession.setActive(true)            
            try audioSession.overrideOutputAudioPort(.speaker)
            
            if let soundURL = Bundle.main.url(forResource: "alarm_sound", withExtension: "wav") {
                audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                audioPlayer?.numberOfLoops = -1
                audioPlayer?.prepareToPlay()
            }
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    func maximizeVolume() {
        DispatchQueue.main.async {
            self.volumeSlider?.setValue(1.0, animated: false)
            self.volumeSlider?.sendActions(for: .touchUpInside)
        }
    }
    
    func playAlarmSound() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer?.play()
        } catch {
            print("Failed to play alarm sound: \(error)")
        }
    }
    
    func stopAlarmSound() {
        audioPlayer?.stop()
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
        
        for i in 0..<maxNotifications {
            let content = UNMutableNotificationContent()
            content.title = "Wake Up!"
            content.body = "Time to wake up! (\(i + 1) of \(maxNotifications))"
            
            let timeInterval = TimeInterval(i) * notificationInterval
            let notificationTime = nextAlarmTime.addingTimeInterval(timeInterval)
            
            Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
                self?.maximizeVolume()
                self?.playAlarmSound()
            }
            
            let triggerComponents = calendar.dateComponents([.hour, .minute, .second], from: notificationTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: true)
            
            let identifier = "\(alarm.id.uuidString)-\(i)"
            let request = UNNotificationRequest(identifier: identifier,
                                              content: content,
                                              trigger: trigger)
            
            UNUserNotificationCenter.current().add(request)
        }
    }
    
    func cancelNotification(for alarm: Alarm) {
        let identifiers = (0..<maxNotifications).map { "\(alarm.id.uuidString)-\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        stopAlarmSound()
    }
} 
