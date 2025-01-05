//
//  ContentView.swift
//  Somnus
//
//  Created by Türker Kızılcık on 4.01.2025.
//

import SwiftUI

struct Alarm: Identifiable, Codable {
    let id = UUID()
    var time: Date
    var label: String
    var isEnabled: Bool
    var repeatDays: Set<Int>
}

struct ContentView: View {
    @State private var showingAddAlarm = false
    private let alarmManager = AlarmManager.shared
    
    var body: some View {
        NavigationView {
            List {
                ForEach(alarmManager.alarms) { alarm in
                    AlarmRow(alarm: alarm, alarmManager: alarmManager)
                }
            }
            .navigationTitle("Somnus")
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
                AddAlarmView(alarmManager: alarmManager)
            }
        }
        .onAppear {
            alarmManager.loadAlarms()
            // Stop any active alarm when app is opened
            alarmManager.stopAlarm()
        }
    }
}

struct AlarmRow: View {
    let alarm: Alarm
    let alarmManager: AlarmManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(timeString(from: alarm.time))
                    .font(.title)
                    .fontWeight(.semibold)
                if !alarm.label.isEmpty {
                    Text(alarm.label)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                if !alarm.repeatDays.isEmpty {
                    Text(repeatDaysText(alarm.repeatDays))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { alarm.isEnabled },
                set: { _ in alarmManager.toggleAlarm(alarm) }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 8)
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func repeatDaysText(_ days: Set<Int>) -> String {
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let sortedDays = days.sorted()
        return sortedDays.map { dayNames[$0] }.joined(separator: ", ")
    }
}

#Preview {
    ContentView()
}
