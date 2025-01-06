import SwiftUI

struct AlarmRow: View {
    let alarm: Alarm
    @ObservedObject var alarmManager: AlarmManager
    
    var body: some View {
        HStack {
            Text(alarm.time, style: .time)
                .font(.title2)
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { alarm.isEnabled },
                set: { _ in alarmManager.toggleAlarm(alarm) }
            ))
        }
        .padding(.vertical, 8)
    }
} 