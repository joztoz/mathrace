//
//  FaceOff.swift
//  Math Race
//
//  "Face to face" mode (PRO): two players sit opposite each other at an iPad or an
//  unfolded iPhone Duo. The screen is split in half (on Duo exactly at the fold),
//  each half is rotated towards its player and has its own problems, answers and score.
//  The match has a shared start, timer and winner. Both halves accept touches at the
//  same time (each answer is its own UIKit touch view, no gesture arbitration).
//

import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Fold detection

extension GeometryProxy {
    /// The iPhone Duo fold (inner display), in this proxy's local coordinates. nil elsewhere.
    var foldRect: CGRect? {
        #if os(iOS)
        if #available(iOS 27.1, *) {
            return reservedRegions(kind: .division, options: .includeInactive).first?.frame
        }
        #endif
        return nil
    }
}

// MARK: - Split geometry

struct FaceOffSplit {
    enum Axis { case topBottom, leftRight }
    let axis: Axis
    let first: CGRect   // player 1: top (or left) half
    let second: CGRect  // player 2: bottom (or right) half

    static func make(size: CGSize, fold: CGRect?) -> FaceOffSplit {
        if let fold, fold.width < size.width || fold.height < size.height {
            if fold.height >= fold.width {
                // Vertical crease → left / right halves.
                let minX = min(max(0, fold.minX), size.width)
                let maxX = min(max(minX, fold.maxX), size.width)
                return FaceOffSplit(
                    axis: .leftRight,
                    first: CGRect(x: 0, y: 0, width: minX, height: size.height),
                    second: CGRect(x: maxX, y: 0, width: size.width - maxX, height: size.height)
                )
            } else {
                let minY = min(max(0, fold.minY), size.height)
                let maxY = min(max(minY, fold.maxY), size.height)
                return FaceOffSplit(
                    axis: .topBottom,
                    first: CGRect(x: 0, y: 0, width: size.width, height: minY),
                    second: CGRect(x: 0, y: maxY, width: size.width, height: size.height - maxY)
                )
            }
        }
        // iPad / no fold: split across the longer side, in the middle.
        let gap: CGFloat = 8
        if size.width > size.height {
            let w = (size.width - gap) / 2
            return FaceOffSplit(axis: .leftRight,
                                first: CGRect(x: 0, y: 0, width: w, height: size.height),
                                second: CGRect(x: w + gap, y: 0, width: w, height: size.height))
        } else {
            let h = (size.height - gap) / 2
            return FaceOffSplit(axis: .topBottom,
                                first: CGRect(x: 0, y: 0, width: size.width, height: h),
                                second: CGRect(x: 0, y: h + gap, width: size.width, height: h))
        }
    }

    /// Each half faces the edge where its player sits.
    var firstRotation: Angle { axis == .topBottom ? .degrees(180) : .degrees(90) }
    var secondRotation: Angle { axis == .topBottom ? .zero : .degrees(-90) }
}

// MARK: - Game model

@MainActor
final class FaceOffGame: ObservableObject {
    enum Phase: Equatable {
        case lobby
        case countdown(Int)
        case playing
        case finished(winner: Int)
    }

    enum Feedback { case correct, wrong }

    struct Player {
        var question: Question
        var choices: [Int]
        var score = 0
        var ready = false
        var feedback: Feedback? = nil
        var feedbackID = 0
        var lockedUntil = Date.distantPast
    }

    @Published private(set) var phase: Phase = .lobby
    @Published private(set) var players: [Player]
    @Published private(set) var startDate = Date()
    @Published private(set) var finishTime: TimeInterval = 0

    let target: Int
    let maxFactor: Int
    let operation: OperationMode
    var soundsEnabled = true
    private var countdownTask: Task<Void, Never>?
    private var soundIndex = 0

    init(target: Int, maxFactor: Int, operation: OperationMode) {
        self.target = max(1, target)
        self.maxFactor = max(2, maxFactor)
        self.operation = operation
        let q1 = Self.makeQuestion(operation, maxFactor: max(2, maxFactor))
        let q2 = Self.makeQuestion(operation, maxFactor: max(2, maxFactor))
        players = [
            Player(question: q1, choices: Self.makeChoices(for: q1, maxFactor: max(2, maxFactor))),
            Player(question: q2, choices: Self.makeChoices(for: q2, maxFactor: max(2, maxFactor)))
        ]
    }

    func setReady(_ p: Int) {
        guard phase == .lobby else { return }
        players[p].ready = true
        if players.allSatisfy(\.ready) { startCountdown() }
    }

    func playAgain() {
        countdownTask?.cancel()
        for i in players.indices {
            players[i].ready = false
            players[i].score = 0
            players[i].feedback = nil
        }
        phase = .lobby
    }

    func answer(_ p: Int, value: Int) {
        guard phase == .playing, Date() >= players[p].lockedUntil else { return }
        if value == players[p].question.answer {
            players[p].score += 1
            flash(p, .correct)
            if soundsEnabled { ToneFeedback.shared.playSuccess(index: soundIndex); soundIndex += 1 }
            if players[p].score >= target {
                finishTime = Date().timeIntervalSince(startDate)
                phase = .finished(winner: p)
                return
            }
            nextQuestion(for: p)
        } else {
            // Short lock so random tapping doesn't pay off.
            players[p].lockedUntil = Date().addingTimeInterval(0.8)
            flash(p, .wrong)
            if soundsEnabled { ToneFeedback.shared.playError(index: soundIndex); soundIndex += 1 }
        }
    }

    func stop() { countdownTask?.cancel() }

    private func startCountdown() {
        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            for n in [3, 2, 1] {
                guard let self, !Task.isCancelled else { return }
                self.phase = .countdown(n)
                try? await Task.sleep(nanoseconds: 800_000_000)
            }
            guard let self, !Task.isCancelled else { return }
            self.begin()
        }
    }

    private func begin() {
        for i in players.indices {
            players[i].score = 0
            players[i].lockedUntil = .distantPast
            nextQuestion(for: i)
        }
        startDate = Date()
        phase = .playing
    }

    private func nextQuestion(for p: Int) {
        var q = Self.makeQuestion(operation, maxFactor: maxFactor)
        // Avoid repeating the same problem twice in a row.
        for _ in 0..<5 where q.text == players[p].question.text {
            q = Self.makeQuestion(operation, maxFactor: maxFactor)
        }
        players[p].question = q
        players[p].choices = Self.makeChoices(for: q, maxFactor: maxFactor)
    }

    private func flash(_ p: Int, _ feedback: Feedback) {
        players[p].feedback = feedback
        players[p].feedbackID += 1
        let id = players[p].feedbackID
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self, self.players[p].feedbackID == id else { return }
            self.players[p].feedback = nil
        }
    }

    static func makeQuestion(_ op: OperationMode, maxFactor: Int) -> Question {
        let picked: OperationMode = op == .mix
            ? ([.multiply, .divide, .add, .subtract].randomElement() ?? .multiply)
            : op
        let a = Int.random(in: 1...maxFactor)
        let b = Int.random(in: 1...maxFactor)
        switch picked {
        case .multiply, .mix: return Question(a: a, b: b, op: .multiply)
        case .divide:         return Question(a: a * b, b: a, op: .divide)
        case .add:            return Question(a: a, b: b, op: .add)
        case .subtract:       return Question(a: max(a, b), b: min(a, b), op: .subtract)
        }
    }

    static func makeChoices(for q: Question, maxFactor: Int, count: Int = 4) -> [Int] {
        let correct = q.answer
        var set: Set<Int> = [correct]
        var attempts = 0
        while set.count < count && attempts < 200 {
            attempts += 1
            let spread = max(3, min(10, correct / 3 + 2))
            var delta = Int.random(in: -spread...spread)
            if delta == 0 { delta = 1 }
            set.insert(max(0, correct + delta))
        }
        var extra = correct + 1
        while set.count < count { set.insert(extra); extra += 1 }
        return Array(set).shuffled()
    }
}

// MARK: - Multitouch tap area

/// A transparent UIKit view that fires on touch-down. Every instance receives its own
/// touches, so both players can tap at exactly the same time.
struct TouchDownArea: UIViewRepresentable {
    let action: () -> Void

    func makeUIView(context: Context) -> TouchView {
        let view = TouchView()
        view.backgroundColor = .clear
        view.isExclusiveTouch = false
        view.action = action
        return view
    }

    func updateUIView(_ view: TouchView, context: Context) {
        view.action = action
    }

    final class TouchView: UIView {
        var action: (() -> Void)?
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            action?()
        }
    }
}

private extension View {
    func touchDown(_ action: @escaping () -> Void) -> some View {
        overlay(TouchDownArea(action: action))
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { action() }
    }
}

// MARK: - Views

struct FaceOffView: View {
    @StateObject private var game: FaceOffGame
    @AppStorage("soundsEnabled") private var soundsEnabled: Bool = true
    let onExit: () -> Void

    init(target: Int, maxFactor: Int, operation: OperationMode, onExit: @escaping () -> Void) {
        _game = StateObject(wrappedValue: FaceOffGame(target: target, maxFactor: maxFactor, operation: operation))
        self.onExit = onExit
    }

    var body: some View {
        GeometryReader { proxy in
            let split = FaceOffSplit.make(size: proxy.size, fold: proxy.foldRect)
            ZStack {
                Color(red: 0.10, green: 0.09, blue: 0.16)
                RotatedPanel(rect: split.first, rotation: split.firstRotation) { size in
                    FaceOffPanel(game: game, player: 0, size: size, onExit: exit)
                }
                RotatedPanel(rect: split.second, rotation: split.secondRotation) { size in
                    FaceOffPanel(game: game, player: 1, size: size, onExit: exit)
                }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear {
            game.soundsEnabled = soundsEnabled
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-faceOffAutoStart") {
                game.setReady(0); game.setReady(1)
            }
            #endif
            ToneFeedback.shared.configureIfNeeded()
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            game.stop()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private func exit() {
        game.stop()
        onExit()
    }
}

/// Lays out content in `rect`, rotated towards the player.
struct RotatedPanel<Content: View>: View {
    let rect: CGRect
    let rotation: Angle
    let content: (CGSize) -> Content

    init(rect: CGRect, rotation: Angle, @ViewBuilder content: @escaping (CGSize) -> Content) {
        self.rect = rect
        self.rotation = rotation
        self.content = content
    }

    var body: some View {
        let quarterTurn = abs(Int(rotation.degrees.rounded())) % 180 == 90
        let inner = quarterTurn ? CGSize(width: rect.height, height: rect.width) : rect.size
        content(inner)
            .frame(width: inner.width, height: inner.height)
            .rotationEffect(rotation)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }
}

struct FaceOffPanel: View {
    @ObservedObject var game: FaceOffGame
    let player: Int
    let size: CGSize
    let onExit: () -> Void

    private var me: FaceOffGame.Player { game.players[player] }
    private var other: FaceOffGame.Player { game.players[1 - player] }
    private var color: Color {
        player == 0 ? Color(red: 1.0, green: 0.55, blue: 0.20) : Color(red: 0.25, green: 0.65, blue: 1.0)
    }
    private var unit: CGFloat { max(1, min(size.width, size.height * 1.3)) }
    private var nameKey: LocalizedStringKey { player == 0 ? "player1" : "player2" }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(color.opacity(0.22))
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(feedbackColor)
                .animation(.easeOut(duration: 0.2), value: me.feedbackID)

            VStack(spacing: unit * 0.025) {
                header
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, unit * 0.05)
            .padding(.vertical, unit * 0.04)
        }
        .padding(10)
        .foregroundStyle(.white)
    }

    private var feedbackColor: Color {
        switch me.feedback {
        case .correct: return Color.green.opacity(0.35)
        case .wrong: return Color.red.opacity(0.40)
        case nil: return Color.clear
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            HStack {
                Text(nameKey)
                    .font(.system(size: unit * 0.05, weight: .black, design: .rounded))
                    .foregroundStyle(color)
                Spacer()
                Text("\(me.score) / \(game.target)")
                    .font(.system(size: unit * 0.05, weight: .black, design: .rounded).monospacedDigit())
                Button(action: onExit) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: unit * 0.06))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .accessibilityLabel(Text("fo_exit"))
                .padding(.leading, 8)
            }
            ProgressView(value: Double(min(me.score, game.target)), total: Double(game.target))
                .tint(color)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch game.phase {
        case .lobby:
            VStack(spacing: unit * 0.04) {
                Text(String(format: String(localized: "fo_first_to"), game.target))
                    .font(.system(size: unit * 0.045, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.8))
                if me.ready {
                    Text("fo_waiting")
                        .font(.system(size: unit * 0.05, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                } else {
                    bigButton("fo_ready") { game.setReady(player) }
                }
            }

        case .countdown(let n):
            VStack(spacing: 8) {
                Text("fo_get_ready")
                    .font(.system(size: unit * 0.05, weight: .bold, design: .rounded))
                Text("\(n)")
                    .font(.system(size: unit * 0.3, weight: .black, design: .rounded))
                    .contentTransition(.numericText())
            }

        case .playing:
            VStack(spacing: unit * 0.03) {
                TimelineView(.periodic(from: .now, by: 0.1)) { context in
                    Text(String(format: "%.1f s", context.date.timeIntervalSince(game.startDate)))
                        .font(.system(size: unit * 0.04, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.7))
                }
                Text(me.question.text)
                    .font(.system(size: unit * 0.14, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                answerGrid
            }

        case .finished(let winner):
            VStack(spacing: unit * 0.03) {
                Text(winner == player ? "fo_you_win" : "fo_you_lose")
                    .font(.system(size: unit * 0.09, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                Text(String(format: "%.1f s · %d : %d", game.finishTime, me.score, other.score))
                    .font(.system(size: unit * 0.045, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.8))
                bigButton("fo_play_again") { game.playAgain() }
            }
        }
    }

    private var answerGrid: some View {
        let columns = [GridItem(.flexible(), spacing: unit * 0.03), GridItem(.flexible(), spacing: unit * 0.03)]
        return LazyVGrid(columns: columns, spacing: unit * 0.03) {
            ForEach(Array(me.choices.enumerated()), id: \.offset) { _, value in
                Text("\(value)")
                    .font(.system(size: unit * 0.09, weight: .black, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity, minHeight: unit * 0.16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(color.opacity(0.85))
                    )
                    .contentShape(Rectangle())
                    .touchDown { game.answer(player, value: value) }
            }
        }
    }

    private func bigButton(_ key: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Text(key)
            .font(.system(size: unit * 0.065, weight: .black, design: .rounded))
            .frame(maxWidth: .infinity, minHeight: unit * 0.18)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(color))
            .contentShape(Rectangle())
            .touchDown(action)
    }
}
