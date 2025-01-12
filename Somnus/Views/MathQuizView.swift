import SwiftUI

struct MathQuizView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var alarmManager: AlarmManager
    
    @State private var questions: [(num1: Int, num2: Int, operation: String, answer: Int)] = []
    @State private var userAnswers: [String] = ["", "", ""]
    @State private var currentQuestion = 0
    
    init(alarmManager: AlarmManager) {
        self.alarmManager = alarmManager
        
        // Generate 3 simple math questions
        let operations = ["+", "-"]
        var generatedQuestions: [(Int, Int, String, Int)] = []
        
        for _ in 0..<3 {
            let num1 = Int.random(in: 1...20)
            let num2 = Int.random(in: 1...10)
            let operation = operations.randomElement()!
            
            let answer: Int
            if operation == "+" {
                answer = num1 + num2
            } else {
                answer = num1 - num2
            }
            
            generatedQuestions.append((num1, num2, operation, answer))
        }
        _questions = State(initialValue: generatedQuestions)
    }
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Solve to Stop Alarm")
                .font(.title)
                .fontWeight(.bold)
            
            ForEach(0..<3) { index in
                HStack {
                    Text("\(questions[index].num1) \(questions[index].operation) \(questions[index].num2) = ")
                        .font(.title2)
                    
                    TextField("?", text: $userAnswers[index])
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 100)
                        .keyboardType(.numberPad)
                }
                .opacity(currentQuestion == index ? 1 : 0.3)
            }
            
            Button(action: checkAnswer) {
                Text("Submit")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 200, height: 50)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding()
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                // First resume the alarm sound
                alarmManager.resumeAlarm()
                
                // Then restart notifications immediately
                if let alarm = alarmManager.alarms.first(where: { $0.isEnabled }) {
                    alarmManager.startImmediateNotifications(for: alarm)
                }
                
                // Reset quiz state
                alarmManager.showMathQuiz = false
                dismiss()
            }
        }
    }
    
    private func checkAnswer() {
        let currentAnswer = Int(userAnswers[currentQuestion]) ?? -999999
        
        if currentAnswer == questions[currentQuestion].answer {
            if currentQuestion < 2 {
                currentQuestion += 1
            } else {
                // All questions answered correctly
                alarmManager.stopAlarmSound()
                dismiss()
            }
        } else {
            // Wrong answer, shake animation could be added here
            userAnswers[currentQuestion] = ""
        }
    }
} 
