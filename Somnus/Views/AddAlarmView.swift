import SwiftUI

struct AddAlarmView: View {
    @Binding var isPresented: Bool
    @ObservedObject var alarmManager: AlarmManager
    @State private var selectedTime: Date
    
    init(isPresented: Binding<Bool>, alarmManager: AlarmManager) {
        self._isPresented = isPresented
        self.alarmManager = alarmManager
        
        let calendar = Calendar.current
        let now = Date()
        let nextMinute = calendar.date(byAdding: .minute, value: 1, to: now) ?? now
        self._selectedTime = State(initialValue: nextMinute)
    }
    
    var body: some View {
        NavigationView {
            Form {
                DatePicker("Time",
                          selection: $selectedTime,
                          displayedComponents: .hourAndMinute)
                    .datePickerStyle(WheelDatePickerStyle())
                    .labelsHidden()
            }
            .navigationTitle("Add Alarm")
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                },
                trailing: Button("Save") {
                    alarmManager.addAlarm(time: selectedTime)
                    isPresented = false
                }
            )
        }
    }
} 
