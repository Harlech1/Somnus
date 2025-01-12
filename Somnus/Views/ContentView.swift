import SwiftUI

struct ContentView: View {
    @StateObject private var alarmManager = AlarmManager()
    @StateObject private var notificationDelegate = NotificationDelegate()
    @State private var showingAddAlarm = false
    @Environment(\.scenePhase) private var scenePhase
    
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
                    Button(action: { showingAddAlarm = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddAlarm) {
            AddAlarmView(isPresented: $showingAddAlarm, alarmManager: alarmManager)
        }
        .fullScreenCover(isPresented: $alarmManager.showMathQuiz) {
            MathQuizView(alarmManager: alarmManager)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Check alarm state when app becomes active
                if alarmManager.audioPlayer?.isPlaying == true {
                    alarmManager.pauseAlarm()
                    alarmManager.showMathQuiz = true
                }
            }
        }
        .onAppear {
            notificationDelegate.alarmManager = alarmManager
            alarmManager.setNotificationDelegate(notificationDelegate)
            
            // Initial check for playing alarm
            if alarmManager.audioPlayer?.isPlaying == true {
                alarmManager.pauseAlarm()
                alarmManager.showMathQuiz = true
            }
        }
    }
}

#Preview {
    ContentView()
} 
