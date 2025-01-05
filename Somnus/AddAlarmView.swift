import SwiftUI

struct AddAlarmView: View {
    @Environment(\.dismiss) var dismiss
    let alarmManager: AlarmManager
    
    @State private var alarmTime = Date()
    @State private var alarmLabel = ""
    @State private var isRepeatEnabled = false
    @State private var selectedDays: Set<Int> = []
    
    let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    DatePicker("Time", selection: $alarmTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                }
                
                Section {
                    TextField("Label", text: $alarmLabel)
                    Toggle("Repeat", isOn: $isRepeatEnabled)
                    
                    if isRepeatEnabled {
                        ForEach(0..<7) { index in
                            Toggle(daysOfWeek[index], isOn: Binding(
                                get: { selectedDays.contains(index) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedDays.insert(index)
                                    } else {
                                        selectedDays.remove(index)
                                    }
                                }
                            ))
                        }
                    }
                }
            }
            .navigationTitle("Add Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAlarm()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveAlarm() {
        let newAlarm = Alarm(
            time: alarmTime,
            label: alarmLabel,
            isEnabled: true,
            repeatDays: isRepeatEnabled ? selectedDays : []
        )
        alarmManager.addAlarm(newAlarm)
    }
}

#Preview {
    AddAlarmView(alarmManager: AlarmManager.shared)
} 