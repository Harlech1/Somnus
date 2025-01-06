import SwiftUI

struct ContentView: View {
    @StateObject private var alarmManager = AlarmManager()
    @State private var showingAddAlarm = false
    @State private var selectedTime = Date()
    
    var body: some View {
        NavigationView {
            List {
                ForEach(alarmManager.alarms.reversed()) { alarm in
                    AlarmRow(alarm: alarm, alarmManager: alarmManager)
                }
                .onDelete { indexSet in
                    let originalIndices = indexSet.map { alarmManager.alarms.count - 1 - $0 }
                    originalIndices.forEach { index in
                        alarmManager.deleteAlarm(alarmManager.alarms[index])
                    }
                }
            }
            .navigationTitle("Alarms")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddAlarm = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddAlarm) {
                AddAlarmView(isPresented: $showingAddAlarm,
                            selectedTime: $selectedTime,
                            alarmManager: alarmManager)
            }
            .onAppear {
                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            }
        }
    }
}

#Preview {
    ContentView()
} 