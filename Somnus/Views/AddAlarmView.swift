import SwiftUI

struct AddAlarmView: View {
    @Binding var isPresented: Bool
    @Binding var selectedTime: Date
    @ObservedObject var alarmManager: AlarmManager
    
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