import SwiftUI

struct MathQuizView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var alarmManager: AlarmManager
    
    @State private var questions: [(num1: Int, num2: Int, answer: Int, options: [Int])] = []
    @State private var currentQuestion = 0
    @State private var selectedAnswer: Int?
    @State private var isAnswerCorrect = false
    
    init(alarmManager: AlarmManager) {
        self.alarmManager = alarmManager
        
        var generatedQuestions: [(Int, Int, Int, [Int])] = []
        for _ in 0..<3 {
            let num1 = Int.random(in: 1...20)
            let num2 = Int.random(in: 1...10)
            let answer = num1 + num2
            
            var options = [answer]
            while options.count < 4 {
                let wrongAnswer = answer + Int.random(in: -5...5)
                if wrongAnswer != answer && !options.contains(wrongAnswer) && wrongAnswer > 0 {
                    options.append(wrongAnswer)
                }
            }
            options.shuffle()
            
            generatedQuestions.append((num1, num2, answer, options))
        }
        _questions = State(initialValue: generatedQuestions)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 10) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(index == currentQuestion ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            
            Text("Question \(currentQuestion + 1) of 3")
                .font(.headline)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text("\(questions[currentQuestion].num1) + \(questions[currentQuestion].num2)")
                .font(.system(size: 50, weight: .bold))
                .padding(.bottom, 40)
            
            VStack(spacing: 16) {
                ForEach(questions[currentQuestion].options, id: \.self) { option in
                    Button(action: { checkAnswer(option) }) {
                        Text("\(option)")
                            .font(.title)
                            .foregroundColor(getTextColor(for: option))
                            .frame(maxWidth: .infinity)
                            .frame(height: 70)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(getBackgroundColor(for: option))
                            )
                    }
                    .disabled(selectedAnswer != nil)
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.top, 20)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                alarmManager.resumeAlarm()
                if let alarm = alarmManager.alarms.first(where: { $0.isEnabled }) {
                    alarmManager.startImmediateNotifications(for: alarm)
                }
                alarmManager.showMathQuiz = false
                dismiss()
            }
        }
    }
    
    private func getTextColor(for option: Int) -> Color {
        guard let selected = selectedAnswer else { return .primary }
        if option == selected {
            return .white
        }
        return .primary
    }
    
    private func getBackgroundColor(for option: Int) -> Color {
        guard let selected = selectedAnswer else { return Color.gray.opacity(0.1) }
        
        if option == selected {
            return isAnswerCorrect ? .green : .red
        }
        return Color.gray.opacity(0.1)
    }
    
    private func checkAnswer(_ selected: Int) {
        let generator = UINotificationFeedbackGenerator()
        selectedAnswer = selected
        isAnswerCorrect = selected == questions[currentQuestion].answer
        
        if isAnswerCorrect {
            generator.notificationOccurred(.success)
            
            // Wait a moment to show the green color
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if currentQuestion < 2 {
                    currentQuestion += 1
                    selectedAnswer = nil
                } else {
                    generator.notificationOccurred(.success)
                    alarmManager.stopAlarmSound()
                    dismiss()
                }
            }
        } else {
            generator.notificationOccurred(.error)
            
            // Wait a moment to show the red color
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                selectedAnswer = nil
            }
        }
    }
} 
