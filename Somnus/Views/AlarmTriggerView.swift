import SwiftUI
import AVFoundation

struct AlarmTriggerView: View {
    let alarm: Alarm
    @Environment(\.dismiss) var dismiss
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = true
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text(timeString)
                    .font(.system(size: 70, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                if !alarm.label.isEmpty {
                    Text(alarm.label)
                        .font(.title)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                HStack(spacing: 40) {
                    Button(action: {
                        stopAlarm()
                        dismiss()
                    }) {
                        VStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: "stop.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white)
                                )
                            Text("Stop")
                                .foregroundColor(.white)
                        }
                    }
                    
                    Button(action: {
                        snoozeAlarm()
                        dismiss()
                    }) {
                        VStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: "zzz")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white)
                                )
                            Text("Snooze")
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.bottom, 50)
            }
            .padding()
        }
        .onAppear(perform: startAlarm)
        .onDisappear(perform: stopAlarm)
        .interactiveDismissDisabled()  // Prevent swipe to dismiss
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }
    
    private func startAlarm() {
        // Play system sound repeatedly
        AudioServicesPlaySystemSound(1005)
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if isPlaying {
                AudioServicesPlaySystemSound(1005)
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            }
        }
        
        // Keep screen on
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    private func stopAlarm() {
        isPlaying = false
        UIApplication.shared.isIdleTimerDisabled = false
        AlarmManager.shared.stopAlarm(alarm)
    }
    
    private func snoozeAlarm() {
        stopAlarm()
        AlarmManager.shared.snoozeAlarm(alarm)
    }
} 