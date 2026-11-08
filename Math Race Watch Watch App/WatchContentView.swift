//
//  ContentView.swift
//  Math Race Watch Watch App
//
//  Created by Jozef Ziak on 1/18/26.
//

import SwiftUI

struct WatchContentView: View {
    @AppStorage("watchMaxFactor") private var maxFactor: Int = 6
    @State private var showSettings = false
    @State private var q = makeQuestion(maxFactor: 6)
    @State private var choices: [Int] = []
    @State private var message = "Tap!"
    @State private var score = 0
    @State private var showCorrectOverlay = false
    @State private var correctEquation = ""
    @State private var overlayPop = false

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                // Scales for different watch sizes
                let problemFont = max(40, min(56, w * 0.38))
                let answerFont  = max(16, min(22, w * 0.16))
                let buttonH: CGFloat = max(26, min(32, h * 0.11))

                ZStack {
                    VStack(spacing: 6) {
                        // Top row: problem + settings in one line (uses the space that was previously the title bar)
                        HStack(spacing: 4) {
                            Text(q.text)
                                .font(.system(size: problemFont, weight: .black, design: .rounded))
                                .minimumScaleFactor(0.50)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .center)

                            Button {
                                showSettings = true
                            } label: {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .padding(6)
                                    .background(Color.white.opacity(0.10))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text("Settings"))
                        }
                        .padding(.bottom, 2)

                        // Small status row
                        HStack {
                            Text("⭐️\(score)")
                                .font(.system(.caption2, design: .rounded).weight(.bold))
                            Spacer()
                            Text(message)
                                .font(.system(.caption2, design: .rounded).weight(.bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .foregroundStyle(.secondary)

                        // Answers
                        let cols = [
                            GridItem(.flexible(), spacing: 6),
                            GridItem(.flexible(), spacing: 6)
                        ]

                        LazyVGrid(columns: cols, spacing: 6) {
                            ForEach(Array(choices.enumerated()), id: \.offset) { idx, v in
                                Button {
                                    tapped(v)
                                } label: {
                                    Text("\(v)")
                                        .font(.system(size: answerFont, weight: .black, design: .rounded))
                                        .frame(maxWidth: .infinity, minHeight: buttonH)
                                }
                                .buttonStyle(.bordered)
                                .tint(.accentColor)
                                .gridCellColumns(choices.count == 3 && idx == 2 ? 2 : 1)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.horizontal, 6)
                    .padding(.top, 2)
                    .padding(.bottom, 4)

                    if showCorrectOverlay {
                        WatchCorrectOverlay(equation: correctEquation, pop: overlayPop)
                            .transition(.opacity.combined(with: .scale))
                            .zIndex(10)
                    }
                }
            }
            // Removed navigationTitle and navigationBarTitleDisplayMode for compact UI
            // Removed toolbar gear button, now gear is in top row
            .sheet(isPresented: $showSettings) {
                WatchSettingsView(maxFactor: $maxFactor)
            }
        }
        .onAppear { newRound() }
        .onChange(of: maxFactor) { _, _ in
            // Regenerate immediately if settings change
            newRound()
        }
    }

    private func newRound() {
        q = makeQuestion(maxFactor: maxFactor)
        choices = makeChoices(correct: q.answer, maxValue: maxFactor * maxFactor)
        message = "Tap!"
    }

    private func tapped(_ v: Int) {
        if v == q.answer {
            score += 1
            message = "✅"

            // Full-screen celebration (like iOS)
            correctEquation = "\(q.text) = \(q.answer)"
            overlayPop = true
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                showCorrectOverlay = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                overlayPop = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                withAnimation(.easeOut(duration: 0.20)) {
                    showCorrectOverlay = false
                }
            }

            // Advance only after a correct answer
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                newRound()
            }

        } else {
            // Wrong: do NOT change the problem. Let the player try again.
            message = "❌"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                // reset message but keep the same question/choices
                message = "Tap!"
            }
        }
    }
}

struct WatchSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var maxFactor: Int

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $maxFactor, in: 2...12) {
                        HStack {
                            Text("Max")
                                .font(.system(.caption, design: .rounded).weight(.bold))
                            Spacer()
                            Text("\(maxFactor)")
                                .font(.system(.caption, design: .rounded).weight(.black))
                        }
                    }
                } header: {
                    Text("Practice")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            // Removed navigationTitle and navigationBarTitleDisplayMode for compact watch settings
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                }
            }
        }
    }
}

#Preview {
    WatchContentView()
}

struct WatchCorrectOverlay: View {
    let equation: String
    let pop: Bool

    var body: some View {
        ZStack {
            // No dark full-screen box; keep it airy
            Color.clear

            VStack(spacing: 6) {
                Text("🎉")
                    .font(.system(size: 30))

                Text(equation)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.55)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.10, green: 0.70, blue: 0.35),
                                Color(red: 0.20, green: 0.85, blue: 0.55)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(radius: 6)

                Text("✨")
                    .font(.system(size: 18))
                    .opacity(0.9)
            }
            .scaleEffect(pop ? 1.06 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: pop)
        }
        .allowsHitTesting(false)
    }
}
