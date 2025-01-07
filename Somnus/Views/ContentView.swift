import SwiftUI

struct ContentView: View {
    @EnvironmentObject var alarmManager: AlarmManager
    @State private var showingAddAlarm = false
    
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
                            alarmManager: alarmManager)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AlarmManager())
} 
