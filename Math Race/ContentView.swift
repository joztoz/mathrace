//
//  ContentView.swift
//  Math Race
//
//  Created by Jozef Ziak on 1/17/26.
//

import SwiftUI
import Combine
import AVFoundation
import StoreKit
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Modes

enum GameMode: String, CaseIterable, Identifiable {
    case single = "single_mode"
    case duel = "duel_mode" // 2-player "STOP + answer" duel
    var id: String { rawValue }
}

enum OperationMode: String, CaseIterable, Identifiable {
    case multiply = "op_multiply"
    case divide = "op_divide"
    case add = "op_add"
    case subtract = "op_subtract"
    case mix = "op_mix"
    var id: String { rawValue }
}

struct Question {
    let a: Int
    let b: Int
    let op: OperationMode

    var answer: Int {
        switch op {
        case .multiply: return a * b
        case .divide:   return b == 0 ? 0 : a / b
        case .add:      return a + b
        case .subtract: return a - b
        case .mix:      return a * b
        }
    }

    var text: String {
        let symbol: String = {
            switch op {
            case .multiply: return "×"
            case .divide: return "÷"
            case .add: return "+"
            case .subtract: return "−"
            case .mix: return "×"
            }
        }()
        return "\(a) \(symbol) \(b)"
    }
}

enum DuelTurn {
    case player1Answer
    case player2Answer
    case reveal
}

// MARK: - View

// MARK: - Purchases (StoreKit 2)

@MainActor
final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    @Published var isPro: Bool = false
    @Published var products: [Product] = []

    // App Store Connect IAP Product ID (Non-Consumable)
    let proProductId = "funApp.MathRace.pro"
    private var updatesTask: Task<Void, Never>? = nil

    private init() {}

    func startListeningForTransactions() {
        // Start (or restart) a single long-lived listener for StoreKit 2 updates.
        // This prevents missing successful purchases (e.g., after app resumes or Ask to Buy).
        updatesTask?.cancel()
        updatesTask = Task { [proProductId] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                if transaction.productID == proProductId {
                    // Mark as unlocked and finish the transaction.
                    await MainActor.run { self.isPro = true }
                }
                await transaction.finish()
            }
        }
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: [proProductId])
        } catch {
            products = []
        }
    }

    func refreshEntitlements() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result else { continue }
            if t.productID == proProductId {
                unlocked = true
                break
            }
        }
        isPro = unlocked
    }

    func purchasePro() async -> Bool {
        if products.isEmpty { await loadProducts() }
        guard let product = products.first(where: { $0.id == proProductId }) else { return false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else { return false }
                await transaction.finish()
                await refreshEntitlements()
                return isPro
            default:
                return false
            }
        } catch {
            return false
        }
    }

    func restore() async {
        await refreshEntitlements()
    }
}

// MARK: - Paywall View (PRO)

/// Shown only after the parental gate is passed (Guideline 1.3).
/// Displays the product title, purchase type (one-time, not a subscription) and price,
/// plus links to the Privacy Policy and Terms of Use (Guideline 3.1.2), each behind the gate.
struct PaywallView: View {
    let isPro: Bool
    let product: Product?
    let onBuy: () -> Void
    let onRestore: () -> Void
    let onClose: () -> Void

    @State private var gatePassed = false

    var body: some View {
        if gatePassed {
            paywall
        } else {
            ParentalGateView(
                onSuccess: { withAnimation { gatePassed = true } },
                onCancel: onClose
            )
        }
    }

    private var paywall: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    VStack(spacing: 10) {
                        Text("pro_badge")
                            .font(.system(.caption, design: .rounded).weight(.black))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.10))
                            .clipShape(Capsule())

                        Text("pro_title")
                            .font(.system(.title2, design: .rounded).weight(.black))

                        Text("pro_subtitle")
                            .font(.system(.body, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)

                    // Product title, purchase type and price
                    VStack(spacing: 6) {
                        Text(product?.displayName ?? "Math Race PRO")
                            .font(.system(.title3, design: .rounded).weight(.black))
                        Text("pro_purchase_type")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        if let product {
                            Text(product.displayPrice)
                                .font(.system(.largeTitle, design: .rounded).weight(.black))
                        } else {
                            ProgressView()
                                .padding(.vertical, 8)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("pro_whats_included")
                            .font(.system(.headline, design: .rounded).weight(.black))

                        VStack(alignment: .leading, spacing: 10) {
                            Label("pro_feature_duel", systemImage: "person.2.fill")
                            Label("pro_feature_faceoff", systemImage: "rectangle.split.2x1.fill")
                            Label("pro_feature_ops_detail", systemImage: "plus.slash.minus")
                            Label("pro_feature_more_tables_detail", systemImage: "number.circle.fill")
                            Label("pro_feature_stats", systemImage: "chart.bar.xaxis")
                        }
                        .font(.system(.headline, design: .rounded))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 10) {
                        Text("pro_parent_title")
                            .font(.system(.headline, design: .rounded).weight(.black))

                        VStack(alignment: .leading, spacing: 8) {
                            Label("pro_parent_noads", systemImage: "checkmark.seal.fill")
                            Label("pro_parent_notracking", systemImage: "hand.raised.fill")
                            Label("pro_parent_onetime", systemImage: "creditcard.fill")
                        }
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.secondary)

                        Text("pro_parent_note")
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.black.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    VStack(spacing: 10) {
                        Button(action: onBuy) {
                            Group {
                                if let product {
                                    Text(String(format: String(localized: "pro_buy_with_price"), product.displayPrice))
                                } else {
                                    Text("pro_loading")
                                }
                            }
                            .font(.system(.headline, design: .rounded).bold())
                            .frame(maxWidth: .infinity, minHeight: 56)
                        }
                        .buttonStyle(KidButtonStyle())
                        .disabled(product == nil || isPro)

                        Button(action: onRestore) {
                            Text("restore")
                                .font(.system(.headline, design: .rounded).bold())
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(KidSecondaryButtonStyle())

                        Text("pro_footer")
                            .font(.system(.footnote, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)

                        HStack(spacing: 20) {
                            GatedLinkButton(titleKey: "privacy_policy", systemImage: "hand.raised", url: ParentalGate.privacyURL)
                            GatedLinkButton(titleKey: "terms_of_use", systemImage: "doc.text", url: ParentalGate.termsURL)
                        }
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .padding(.top, 4)
                    }

                    Spacer(minLength: 8)
                }
                .padding(18)
            }
            .navigationTitle("pro")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("close") { onClose() }
                }
            }
        }
    }
}

struct ContentView: View {

    // MARK: - Settings
    @State private var maxFactor: Int = 6
    @State private var mode: GameMode = .single
    @State private var revealDelaySingle: Double = 2.5 // kept for future use (optional)
    @AppStorage("operationMode") private var operationModeRaw: String = OperationMode.multiply.rawValue

    // UI
    @State private var showSettingsSheet = false

    // Language override: "system", "en", "sk"
    @AppStorage("appLanguage") private var appLanguage: String = "system"
    @AppStorage("roundLength") private var roundLength: Int = 10
    @AppStorage("soundsEnabled") private var soundsEnabled: Bool = true
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Single game state
    @State private var question: Question = Question(a: 1, b: 1, op: .multiply)
    @StateObject private var purchases = PurchaseManager.shared
    @State private var showPaywall = false
    @State private var showFaceOff = false
    @State private var hasFold = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var operationMode: OperationMode {
        OperationMode(rawValue: operationModeRaw) ?? .multiply
    }
    @State private var choices: [Int] = []
    @State private var singleScore = 0
    @State private var singleStreak = 0
    @State private var messageKey: LocalizedStringKey = "tap_to_start"

    // MARK: - Duel state
    @State private var duelTurn: DuelTurn = .player1Answer
    @State private var duelChoices: [Int] = []
    @State private var p1Score = 0
    @State private var p2Score = 0
    @State private var showAnswer = false

    // per-round duel bookkeeping (same question for both players)
    @State private var duelP1Correct: Bool? = nil
    @State private var duelP2Correct: Bool? = nil
    @State private var duelP1Time: TimeInterval = 0
    @State private var duelP2Time: TimeInterval = 0

    // MARK: - Effects
    @State private var pop = false
    @State private var confetti = false
    @State private var singleWrongPulse = false
    @State private var duelWrongPulse = false
    @State private var singleWrongShake = 0
    @State private var duelWrongShake = 0
    @State private var showSingleWrongX = false

    @State private var showCorrectOverlay = false
    @State private var correctQuestionText: String = ""
    @State private var correctAnswer: Int = 0

    // MARK: - Timing (stopwatch)
    @State private var roundStartDate = Date()
    @State private var elapsed: TimeInterval = 0
    @State private var isTiming = false
    @State private var singleBestTime: TimeInterval? = nil
    @State private var duelBestTime: TimeInterval? = nil

    // MARK: - Match / Results
    @State private var currentRound = 1
    @State private var showResultsSheet = false
    // MARK: - Start / End gate
    enum GateState {
        case start
        case matchEnded
    }
    @State private var showGateOverlay = true
    @State private var gateState: GateState = .start

    @State private var singleRoundTimes: [TimeInterval] = []
    @State private var duelRoundTimesP1: [TimeInterval] = []
    @State private var duelRoundTimesP2: [TimeInterval] = []

    struct DuelRoundEntry: Identifiable {
        let id = UUID()
        let round: Int
        let player: Int
        let time: TimeInterval
        let questionText: String
        let answer: Int
    }
    @State private var duelRoundLog: [DuelRoundEntry] = []

    struct MatchSummary: Identifiable {
        let id = UUID()
        let date: Date
        let mode: GameMode
        let rounds: Int
        let avgSingle: TimeInterval?
        let avgP1: TimeInterval?
        let avgP2: TimeInterval?
    }
    @State private var matchHistory: [MatchSummary] = []

    // MARK: - Sound variety + throttle
    @State private var successSoundIndex = 0
    @State private var errorSoundIndex = 0
    @State private var lastSoundAt = Date.distantPast
    private let tick = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    /// Face-to-face mode needs a big screen: iPad or the unfolded iPhone Duo inner display.
    private var faceOffAvailable: Bool {
        isPad || hasFold || horizontalSizeClass == .regular
    }

    private var selectedLocale: Locale {
        switch appLanguage {
        case "en": return Locale(identifier: "en")
        case "sk": return Locale(identifier: "sk")
        default: return Locale.current
        }
    }

    private var mainCardBackground: Color {
        colorScheme == .dark ? Color.black.opacity(0.35) : Color.white.opacity(0.72)
    }

    private var bubbleGradientColors: [Color] {
        if colorScheme == .dark {
            return [Color.black.opacity(0.60), Color.black.opacity(0.40)]
        } else {
            return [Color.white.opacity(0.95), Color.white.opacity(0.70)]
        }
    }

    var body: some View {
        NavigationStack {
            let locale = selectedLocale
            ZStack {
                kidBackground

                VStack(spacing: 18) {
                    header
                    if !showGateOverlay {
                        modeBar
                    }
                    mainCard
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: isPad ? 720 : .infinity)
                .padding(.top, isPad ? 10 : 0)
                .padding(.horizontal, isPad ? 28 : 16)
                .padding(.vertical, 16)
                .toolbarTitleDisplayMode(.inline)
                .onAppear {
                    // Start screen: wait for user
                    isTiming = false
                    showGateOverlay = true
                    gateState = .start
                    ToneFeedback.shared.configureIfNeeded()
                    purchases.startListeningForTransactions()
                    #if DEBUG
                    // Screenshot / layout testing: open face-to-face mode directly.
                    if ProcessInfo.processInfo.arguments.contains("-faceOffDemo") { showFaceOff = true }
                    #endif
                    Task {
                        await purchases.loadProducts()
                        await purchases.refreshEntitlements()
                    }
                }
                .onReceive(tick) { _ in
                    guard isTiming else { return }
                    elapsed = Date().timeIntervalSince(roundStartDate)
                }
                .sheet(isPresented: $showSettingsSheet) {
                    SettingsView(
                        maxFactor: $maxFactor,
                        appLanguage: $appLanguage,
                        roundLength: $roundLength,
                        operationModeRaw: $operationModeRaw,
                        isPro: purchases.isPro,
                        onUnlockPro: { showPaywall = true },
                        onRestore: {
                            Task { await purchases.restore() }
                        }
                    )
                }
                .sheet(isPresented: $showPaywall) {
                    PaywallView(
                        isPro: purchases.isPro,
                        product: purchases.products.first(where: { $0.id == purchases.proProductId }),
                        onBuy: {
                            Task {
                                let ok = await purchases.purchasePro()
                                if ok { showPaywall = false }
                            }
                        },
                        onRestore: {
                            Task {
                                await purchases.restore()
                                if purchases.isPro { showPaywall = false }
                            }
                        },
                        onClose: { showPaywall = false }
                    )
                }
                .fullScreenCover(isPresented: $showFaceOff) {
                    FaceOffView(
                        target: roundLength,
                        maxFactor: maxFactor,
                        operation: operationMode,
                        onExit: { showFaceOff = false }
                    )
                    .environment(\.locale, locale)
                }
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .onChange(of: proxy.foldRect != nil, initial: true) { _, present in
                                hasFold = present
                            }
                    }
                )
                .sheet(isPresented: $showResultsSheet) {
                    ResultsView(
                        mode: mode,
                        roundLength: roundLength,
                        currentRound: currentRound,
                        singleScore: singleScore,
                        singleStreak: singleStreak,
                        p1Score: p1Score,
                        p2Score: p2Score,
                        singleTimes: singleRoundTimes,
                        duelTimesP1: duelRoundTimesP1,
                        duelTimesP2: duelRoundTimesP2,
                        duelLog: duelRoundLog,
                        history: matchHistory,
                        onNewMatch: {
                            startNewMatch()
                        }
                    )
                }

                if mode == .duel {
                    duelOverlay
                }

                if confetti {
                    ConfettiOverlay()
                        .transition(.opacity)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                                withAnimation(.easeOut(duration: 0.25)) { confetti = false }
                            }
                        }
                }

                if showCorrectOverlay {
                    CorrectFullScreenOverlay(
                        questionText: correctQuestionText,
                        answer: correctAnswer
                    )
                    .transition(.opacity.combined(with: .scale))
                    .zIndex(10)
                }
                if showGateOverlay {
                    GateOverlay(
                        state: gateState,
                        roundLength: roundLength,
                        mode: $mode,
                        resultsAvailable: (!matchHistory.isEmpty || !singleRoundTimes.isEmpty || !duelRoundLog.isEmpty),
                        isPro: purchases.isPro,
                        showFaceOff: faceOffAvailable,
                        onFaceOff: {
                            if purchases.isPro { showFaceOff = true } else { showPaywall = true }
                        },
                        onModeChanged: {
                            // allow switching mode before starting
                            isTiming = false
                            gateState = .start
                            showGateOverlay = true
                        },
                        onStart: {
                            startNewMatch()
                        },
                        onShowResults: {
                            showResultsSheet = true
                        }
                    )
                    .transition(.opacity)
                    .zIndex(20)
                }
            }
            .environment(\.locale, locale)
        }
    }

    // MARK: - UI Pieces

    private var kidBackground: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.45, green: 0.78, blue: 1.00),
                Color(red: 0.78, green: 0.55, blue: 1.00),
                Color(red: 1.00, green: 0.75, blue: 0.60)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.35),
                    Color.clear
                ]),
                center: .top,
                startRadius: 10,
                endRadius: 420
            )
            .ignoresSafeArea()
        )
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("title_sub")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                Text("app_title")
                    .font(.system(.title2, design: .rounded).bold())
                    .foregroundStyle(.white)
            }

            Spacer()

            scoreBoard

            Button {
                showResultsSheet = true
            } label: {
                Image(systemName: "trophy.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(Color.black.opacity(0.18))
                    .clipShape(Circle())
            }
            .accessibilityLabel(Text("open_results"))

            Button {
                showSettingsSheet = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(Color.black.opacity(0.18))
                    .clipShape(Circle())
            }
            .accessibilityLabel(Text("open_settings"))
        }
    }

    private var modeBar: some View {
        HStack(spacing: 12) {
            Text("game_mode")
                .font(.system(.subheadline, design: .rounded).bold())
                .foregroundStyle(.white)

            Picker("mode", selection: $mode) {
                Text("single_mode").tag(GameMode.single)
                Text(purchases.isPro ? "duel_mode" : "duel_mode_locked").tag(GameMode.duel)
            }
            .pickerStyle(.segmented)
            .onChange(of: mode) { _, newValue in
                if newValue == .duel && !purchases.isPro {
                    mode = .single
                    showPaywall = true
                    return
                }
                // reset to start gate for the chosen mode
                isTiming = false
                showGateOverlay = true
                gateState = .start
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }



    private var scoreBoard: some View {
        Group {
            if mode == .single {
                if hSizeClass == .compact {
                    VStack(spacing: 6) {
                        singleScoreRow
                        singleStreakRow
                    }
                } else {
                    HStack(spacing: 10) {
                        singleScoreRow
                        singleStreakRow
                    }
                }
            } else {
                if hSizeClass == .compact {
                    VStack(spacing: 6) {
                        duelP1Row
                        duelP2Row
                    }
                } else {
                    HStack(spacing: 10) {
                        duelP1Row
                        duelP2Row
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var singleScoreRow: some View {
        HStack(spacing: 8) {
            Text("⭐️")
            Text("score")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
            Text("\(singleScore)")
                .font(.system(.title3, design: .rounded).weight(.black))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.12))
        .clipShape(Capsule())
    }

    private var singleStreakRow: some View {
        HStack(spacing: 8) {
            Text("🔥")
            Text("streak")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
            Text("\(singleStreak)")
                .font(.system(.title3, design: .rounded).weight(.black))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.12))
        .clipShape(Capsule())
    }

    private var duelP1Row: some View {
        HStack(spacing: 8) {
            Text("🟦")
            Text("player1_short")
                .font(.system(.caption, design: .rounded).bold())
                .foregroundStyle(.white.opacity(0.92))
            Text("\(p1Score)")
                .font(.system(.title3, design: .rounded).weight(.black))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.12))
        .clipShape(Capsule())
    }

    private var duelP2Row: some View {
        HStack(spacing: 8) {
            Text("🟥")
            Text("player2_short")
                .font(.system(.caption, design: .rounded).bold())
                .foregroundStyle(.white.opacity(0.92))
            Text("\(p2Score)")
                .font(.system(.title3, design: .rounded).weight(.black))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.12))
        .clipShape(Capsule())
    }



    private var mainCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text(mode == .single ? "🧠" : "⚔️")
                    .font(.title2)
                Text(mode == .single ? "single_header" : "duel_header")
                    .font(.system(.headline, design: .rounded).bold())
                Spacer()
            }

            questionBubble
            timeRow

            if mode == .single {
                singleGameUI
            } else {
                duelGameUI
            }

            Text(messageKey)
                .font(.system(.headline, design: .rounded).bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .padding(.top, 2)
                .frame(minHeight: 28)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(mainCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 8)
    }

    private var questionBubble: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: bubbleGradientColors),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.red.opacity(singleWrongPulse ? 0.85 : 0.0), lineWidth: 4)
                        .animation(.easeOut(duration: 0.25), value: singleWrongPulse)
                )

            VStack(spacing: 6) {
                Text("question_title")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.85) : .secondary)

                Text(question.text)
                    .font(.system(size: 58, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .scaleEffect(pop ? 1.06 : 1.0)
                    .animation(.spring(response: 0.35, dampingFraction: 0.55), value: pop)

                if mode == .single && showSingleWrongX {
                    Text("❌")
                        .font(.system(size: 44))
                        .foregroundStyle(.red)
                        .transition(.scale)
                        .padding(.top, -6)
                }

                if mode == .duel {
                    Text(showAnswer ? "= \(question.answer)" : "= ?")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundStyle(showAnswer ? .primary : (colorScheme == .dark ? Color.white.opacity(0.75) : .secondary))
                        .animation(.easeInOut(duration: 0.2), value: showAnswer)
                }
            }
            .padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: mode == .duel ? 190 : 160)
        .modifier(ShakeEffect(shakes: singleWrongShake))
    }
    // MARK: - Sound + Haptics

    private func playSuccessFeedback() {
        // Throttle so it never “spams”
        let now = Date()
        guard now.timeIntervalSince(lastSoundAt) > 0.10 else { return }
        lastSoundAt = now

        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif

        guard soundsEnabled else { return }
        ToneFeedback.shared.playSuccess(index: successSoundIndex)
        successSoundIndex += 1
    }

    private func playErrorFeedback() {
        let now = Date()
        guard now.timeIntervalSince(lastSoundAt) > 0.10 else { return }
        lastSoundAt = now

        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif

        guard soundsEnabled else { return }
        ToneFeedback.shared.playError(index: errorSoundIndex)
        errorSoundIndex += 1
    }
    private var timeRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Text("⏱")
                Text(formatTime(elapsed))
                    .font(.system(.headline, design: .rounded).weight(.black))
                Text("•")
                    .foregroundStyle(.secondary)
                Text("\(currentRound)/\(roundLength)")
                    .font(.system(.subheadline, design: .rounded).weight(.black))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if mode == .single, let best = singleBestTime {
                HStack(spacing: 6) {
                    Text("🏆")
                    Text(formatTime(best))
                        .font(.system(.subheadline, design: .rounded).weight(.black))
                }
                .foregroundStyle(.secondary)
            } else if mode == .duel, let best = duelBestTime {
                HStack(spacing: 6) {
                    Text("🏆")
                    Text(formatTime(best))
                        .font(.system(.subheadline, design: .rounded).weight(.black))
                }
                .foregroundStyle(.secondary)
            } else {
                // reserve space so layout doesn't jump when a best time appears
                Text(" ")
                    .font(.system(.subheadline, design: .rounded))
                    .opacity(0)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .frame(minHeight: 40)
    }

    private func formatTime(_ t: TimeInterval) -> String {
        // show like 1.23s
        let clamped = max(0, t)
        return String(format: "%.2fs", clamped)
    }


    // MARK: - Single UI

    private var singleGameUI: some View {
        VStack(spacing: 12) {
            Text("choose_answer")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(choices, id: \.self) { value in
                    Button {
                        singleAnswerTapped(value)
                    } label: {
                        Text("\(value)")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(KidButtonStyle())
                }
            }

            Button {
                // allow skipping only if game is active
                if !showGateOverlay { newRound() }
            } label: {
                Label("next_problem", systemImage: "arrow.clockwise.circle.fill")
                    .font(.system(.headline, design: .rounded).bold())
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(KidSecondaryButtonStyle())
        }
    }

    // MARK: - Duel UI

    private var duelGameUI: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                duelSide(player: 1)
                duelSide(player: 2)
            }
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity, alignment: .center)

            Button {
                if !showGateOverlay { newRound() }
            } label: {
                Text("next_round")
                    .font(.system(.headline, design: .rounded).bold())
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(KidSecondaryButtonStyle())
            .disabled(duelTurn != .reveal)
            .opacity(duelTurn == .reveal ? 1 : 0)
            .frame(height: 52)
        }
    }

    private func duelSide(player: Int) -> some View {
        let isP1 = (player == 1)
        let titleKey = isP1 ? "player1" : "player2"
        let color = isP1 ? Color(red: 0.15, green: 0.45, blue: 0.95) : Color(red: 0.95, green: 0.25, blue: 0.25)

        let isActiveTurn = (isP1 && duelTurn == .player1Answer) || (!isP1 && duelTurn == .player2Answer)
        let statusText: String = {
            if duelTurn == .reveal { return "✓" }
            return isActiveTurn ? "▶︎" : "…"
        }()

        return VStack(spacing: 10) {
            HStack {
                Text(titleKey)
                    .font(.system(.title3, design: .rounded).weight(.black))
                    .foregroundStyle(.primary)

                Spacer()

                Text(isP1 ? "🟦" : "🟥")
                    .font(.title2)
            }

            Text(isP1 ? "\(p1Score)" : "\(p2Score)")
                .font(.system(size: 44, weight: .black, design: .rounded))
                .minimumScaleFactor(0.6)

            Text(statusText)
                .font(.system(.headline, design: .rounded).weight(.black))
                .frame(maxWidth: .infinity, minHeight: 60)
                .background(isActiveTurn ? color.opacity(0.85) : Color.black.opacity(0.08))
                .foregroundStyle(isActiveTurn ? Color.white : Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(isActiveTurn ? color.opacity(0.35) : Color.black.opacity(0.10), lineWidth: 2)
                )
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(colorScheme == .dark ? Color.black.opacity(0.25) : Color.white.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(color.opacity(0.35), lineWidth: 2)
        )
    }

    private var duelOverlay: some View {
        Group {
            if duelTurn == .player1Answer || duelTurn == .player2Answer {
                let player = (duelTurn == .player1Answer) ? 1 : 2
                DuelAnswerOverlay(
                    player: player,
                    questionText: question.text,
                    choices: duelChoices,
                    wrongPulse: duelWrongPulse,
                    shakeCount: duelWrongShake,
                    onPick: { picked in
                        duelPicked(player: player, value: picked)
                    },
                    onSkip: {
                        duelSkip(player: player)
                    }
                )
                .transition(.opacity)
            }
        }
    }

    // MARK: - Game Logic (Common)

    private func newRound() {
        roundStartDate = Date()
        elapsed = 0
        isTiming = true
        // FREE limits (iOS): only multiply and max 6 unless PRO
        if !purchases.isPro {
            if maxFactor > 6 { maxFactor = 6 }
            if operationMode != .multiply {
                operationModeRaw = OperationMode.multiply.rawValue
            }
        }
        // Ensure round label is correct when switching modes
        if mode == .single {
            currentRound = max(1, singleRoundTimes.count + 1)
        } else {
            currentRound = max(1, duelRoundTimesP1.count + 1)
        }
        // reset common
        showAnswer = false
        duelP1Correct = nil
        duelP2Correct = nil
        duelP1Time = 0
        duelP2Time = 0
        duelTurn = .player1Answer

        // new question (based on operation)
        let a = Int.random(in: 1...maxFactor)
        let b = Int.random(in: 1...maxFactor)

        switch operationMode {
        case .multiply:
            question = Question(a: a, b: b, op: .multiply)

        case .divide:
            // clean division: (a*b) ÷ a = b
            let aa = a
            let bb = b
            question = Question(a: aa * bb, b: aa, op: .divide)

        case .add:
            question = Question(a: a, b: b, op: .add)

        case .subtract:
            let hi = max(a, b)
            let lo = min(a, b)
            question = Question(a: hi, b: lo, op: .subtract)

        case .mix:
            // PRO-only; if somehow reached in free, it was already clamped to multiply above.
            let ops: [OperationMode] = [.multiply, .divide, .add, .subtract]
            let picked = ops.randomElement() ?? .multiply
            question = {
                switch picked {
                case .multiply:
                    return Question(a: a, b: b, op: .multiply)
                case .divide:
                    let aa = a
                    let bb = b
                    return Question(a: aa * bb, b: aa, op: .divide)
                case .add:
                    return Question(a: a, b: b, op: .add)
                case .subtract:
                    let hi = max(a, b)
                    let lo = min(a, b)
                    return Question(a: hi, b: lo, op: .subtract)
                case .mix:
                    return Question(a: a, b: b, op: .multiply)
                }
            }()
        }

        // animate pop
        pop = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            pop = false
        }

        let maxValueForChoices: Int = {
            switch question.op {
            case .multiply: return maxFactor * maxFactor
            case .divide: return maxFactor
            case .add: return maxFactor + maxFactor
            case .subtract: return maxFactor
            case .mix: return maxFactor * maxFactor
            }
        }()

        if mode == .single {
            messageKey = "tap_fast"
            choices = generateChoices(correct: question.answer, maxValue: maxValueForChoices)
        } else {
            messageKey = "p1_turn"
            duelChoices = generateChoices(correct: question.answer, maxValue: maxValueForChoices)
        }
    }

    // MARK: - Match helpers

    private func startNewMatch() {
        showResultsSheet = false
        showGateOverlay = false
        currentRound = 1
        gateState = .start
        singleRoundTimes = []
        duelRoundTimesP1 = []
        duelRoundTimesP2 = []
        duelRoundLog = []
        newRound()
    }

    private func completeRoundSingle(with time: TimeInterval) {
        singleRoundTimes.append(time)
        if singleRoundTimes.count >= roundLength {
            finishMatch()
        } else {
            currentRound = singleRoundTimes.count + 1
        }
    }

    private func completeRoundDuel(player: Int, time: TimeInterval) {
        if player == 1 { duelRoundTimesP1.append(time) } else { duelRoundTimesP2.append(time) }
        duelRoundLog.append(.init(round: currentRound, player: player, time: time, questionText: question.text, answer: question.answer))

        // A "round" in duel = one question answered by BOTH players.
        // We finish/advance only after Player 2 has answered (so counts stay aligned).
        if player == 2 {
            if duelRoundTimesP1.count >= roundLength && duelRoundTimesP2.count >= roundLength {
                finishMatch()
            } else {
                currentRound = duelRoundTimesP1.count + 1
            }
        }
    }

    private func avg(_ arr: [TimeInterval]) -> TimeInterval? {
        guard !arr.isEmpty else { return nil }
        return arr.reduce(0, +) / Double(arr.count)
    }

    private func best(_ arr: [TimeInterval]) -> TimeInterval? {
        arr.min()
    }

    private func finishMatch() {
        isTiming = false

        let summary = MatchSummary(
            date: Date(),
            mode: mode,
            rounds: roundLength,
            avgSingle: mode == .single ? avg(singleRoundTimes) : nil,
            avgP1: mode == .duel ? avg(duelRoundTimesP1) : nil,
            avgP2: mode == .duel ? avg(duelRoundTimesP2) : nil
        )
        matchHistory.insert(summary, at: 0)
        gateState = .matchEnded
        showGateOverlay = true
    }

    private func generateChoices(correct: Int, maxValue: Int) -> [Int] {
        var set: Set<Int> = [correct]
        while set.count < 3 {
            let delta = Int.random(in: -8...8)
            let candidate = min(maxValue, Swift.max(0, correct + (delta == 0 ? 3 : delta)))
            set.insert(candidate)
        }
        return Array(set).shuffled()
    }

    // MARK: - Single Logic

    private func singleAnswerTapped(_ value: Int) {
        if value == question.answer {
            singleScore += 1
            singleStreak += 1
            isTiming = false
            let thisTime = elapsed
            if let best = singleBestTime {
                singleBestTime = min(best, thisTime)
            } else {
                singleBestTime = thisTime
            }
            completeRoundSingle(with: thisTime)
            messageKey = praiseKey(for: singleStreak)
            playSuccessFeedback()
            showCorrectCelebration()

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) {
                if !showResultsSheet { newRound() }
            }
        } else {
            singleStreak = 0
            messageKey = "try_again"
            playErrorFeedback()

            withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                showSingleWrongX = true
            }

            singleWrongPulse = true
            singleWrongShake += 1

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                singleWrongPulse = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                withAnimation(.easeOut(duration: 0.18)) {
                    showSingleWrongX = false
                }
            }
        }
    }

    private func praiseKey(for streak: Int) -> LocalizedStringKey {
        if streak >= 5 { return "praise_amazing" }
        if streak >= 3 { return "praise_great" }
        return "praise_good"
    }

    // MARK: - Duel Logic

    // Duel: turn-based, both answer, scored by correctness + speed
    private func duelPicked(player: Int, value: Int) {
        let isCorrect = (value == question.answer)

        // record time for this player's attempt
        isTiming = false
        let thisTime = elapsed

        if player == 1 {
            duelP1Correct = isCorrect
            duelP1Time = thisTime

            if isCorrect { playSuccessFeedback() } else { playErrorFeedback() }
            messageKey = "p2_turn"

            // Switch to Player 2 turn with a fresh timer, same question & choices
            roundStartDate = Date()
            elapsed = 0
            isTiming = true
            duelTurn = .player2Answer
            return
        }

        // player 2
        duelP2Correct = isCorrect
        duelP2Time = thisTime

        if isCorrect { playSuccessFeedback() } else { playErrorFeedback() }

        // Now score the round and reveal the correct answer
        showAnswer = true
        duelTurn = .reveal

        let p1Ok = (duelP1Correct ?? false)
        let p2Ok = (duelP2Correct ?? false)

        // Award point:
        // - if only one correct -> that player gets 1
        // - if both correct -> faster time gets 1 (tie -> no point)
        if p1Ok && !p2Ok {
            p1Score += 1
            messageKey = "p1_point"
        } else if p2Ok && !p1Ok {
            p2Score += 1
            messageKey = "p2_point"
        } else if p1Ok && p2Ok {
            if duelP1Time < duelP2Time {
                p1Score += 1
                messageKey = "p1_point"
            } else if duelP2Time < duelP1Time {
                p2Score += 1
                messageKey = "p2_point"
            } else {
                messageKey = "no_points"
            }
        } else {
            messageKey = "no_points"
        }

        // Update best time (best per-question "winner" time or minimum of both if both correct)
        let candidateBest: TimeInterval? = {
            if p1Ok && p2Ok { return min(duelP1Time, duelP2Time) }
            if p1Ok { return duelP1Time }
            if p2Ok { return duelP2Time }
            return nil
        }()
        if let candidateBest {
            if let best = duelBestTime {
                duelBestTime = min(best, candidateBest)
            } else {
                duelBestTime = candidateBest
            }
        }

        // Log times for both players (only once per question each)
        completeRoundDuel(player: 1, time: duelP1Time)
        completeRoundDuel(player: 2, time: duelP2Time)

        // Celebration only if at least one correct
        if p1Ok || p2Ok {
            showCorrectCelebration()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
            if !showResultsSheet { newRound() }
        }
    }

    // MARK: - Correct Celebration Overlay Helper
    private func showCorrectCelebration() {
        // Snapshot the current example so it stays visible even if state changes
        correctQuestionText = question.text
        correctAnswer = question.answer

        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            showCorrectOverlay = true
        }
        withAnimation(.easeOut(duration: 0.15)) {
            confetti = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            withAnimation(.easeOut(duration: 0.2)) {
                showCorrectOverlay = false
            }
        }
    }

    private func duelSkip(player: Int) {
        // skipping counts as wrong
        duelPicked(player: player, value: question.answer + 99999)
    }
}


// MARK: - Tone Feedback (Silent-mode friendly)

/// Audio work runs on a private serial queue: AVAudioSession activation and
/// AVAudioPlayer preparation can block, so they must not run on the main thread.
nonisolated final class ToneFeedback: @unchecked Sendable {
    static let shared = ToneFeedback()

    private let queue = DispatchQueue(label: "MathRace.ToneFeedback", qos: .userInitiated)
    // Accessed only on `queue`.
    private var configured = false
    private var successPlayers: [AVAudioPlayer] = []
    private var errorPlayers: [AVAudioPlayer] = []

    private init() {}

    func configureIfNeeded() {
        queue.async { self.configureOnQueue() }
    }

    func playSuccess(index: Int) {
        queue.async {
            self.configureOnQueue()
            guard !self.successPlayers.isEmpty else { return }
            let p = self.successPlayers[index % self.successPlayers.count]
            p.currentTime = 0
            p.play()
        }
    }

    func playError(index: Int) {
        queue.async {
            self.configureOnQueue()
            guard !self.errorPlayers.isEmpty else { return }
            let p = self.errorPlayers[index % self.errorPlayers.count]
            p.currentTime = 0
            p.play()
        }
    }

    private func configureOnQueue() {
        guard !configured else { return }
        configured = true

        // Use Ambient so tones respect the Silent switch and do not interrupt other audio.
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: [])
        } catch {
            // If this fails, we still keep haptics; tones may not play.
        }

        // Prepare a few subtle variations so it doesn't get annoying
        successPlayers = [
            makeTonePlayer(frequency: 880, duration: 0.06, gain: 0.22),
            makeTonePlayer(frequency: 988, duration: 0.06, gain: 0.22),
            makeTonePlayer(frequency: 784, duration: 0.07, gain: 0.22),
            makeTonePlayer(frequency: 1046, duration: 0.05, gain: 0.22)
        ].compactMap { $0 }

        errorPlayers = [
            makeTonePlayer(frequency: 220, duration: 0.09, gain: 0.20),
            makeTonePlayer(frequency: 196, duration: 0.09, gain: 0.20)
        ].compactMap { $0 }

        // Avoid “first play lag”
        successPlayers.forEach { $0.prepareToPlay() }
        errorPlayers.forEach { $0.prepareToPlay() }
    }

    private func makeTonePlayer(frequency: Double, duration: Double, gain: Double) -> AVAudioPlayer? {
        // Generate a tiny PCM WAV tone and load it into AVAudioPlayer
        let sampleRate = 44100.0
        let totalSamples = Int(sampleRate * duration)
        if totalSamples <= 0 { return nil }

        var samples = [Int16](repeating: 0, count: totalSamples)
        for i in 0..<totalSamples {
            let t = Double(i) / sampleRate
            let s = sin(2.0 * Double.pi * frequency * t) * gain
            samples[i] = Int16(max(-1.0, min(1.0, s)) * Double(Int16.max))
        }

        let wavData = makeWavData(samples: samples, sampleRate: Int(sampleRate))

        do {
            let player = try AVAudioPlayer(data: wavData)
            player.volume = 0.25
            return player
        } catch {
            return nil
        }
    }

    private func makeWavData(samples: [Int16], sampleRate: Int) -> Data {
        // PCM 16-bit mono WAV
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = UInt32(sampleRate) * UInt32(numChannels) * UInt32(bitsPerSample / 8)
        let blockAlign = UInt16(numChannels * (bitsPerSample / 8))
        let dataSize = UInt32(samples.count * MemoryLayout<Int16>.size)
        let riffSize = 36 + dataSize

        var data = Data()
        data.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        data.append(riffSize.littleEndianData)
        data.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"

        // fmt chunk
        data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
        data.append(UInt32(16).littleEndianData)          // PCM chunk size
        data.append(UInt16(1).littleEndianData)           // audio format = PCM
        data.append(numChannels.littleEndianData)
        data.append(UInt32(sampleRate).littleEndianData)
        data.append(byteRate.littleEndianData)
        data.append(blockAlign.littleEndianData)
        data.append(bitsPerSample.littleEndianData)

        // data chunk
        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        data.append(dataSize.littleEndianData)

        // samples
        samples.forEach { s in
            data.append(s.littleEndianData)
        }

        return data
    }
}

private extension FixedWidthInteger {
    nonisolated var littleEndianData: Data {
        var v = self.littleEndian
        return Data(bytes: &v, count: MemoryLayout<Self>.size)
    }
}
// MARK: - Styles

struct KidButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 8)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.20, green: 0.70, blue: 1.00),
                        Color(red: 0.55, green: 0.40, blue: 1.00)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.06 : 0.16),
                    radius: configuration.isPressed ? 6 : 10,
                    x: 0,
                    y: configuration.isPressed ? 2 : 6)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct KidSecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.10))
            .foregroundStyle(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.05 : 0.10),
                    radius: configuration.isPressed ? 4 : 8,
                    x: 0,
                    y: configuration.isPressed ? 1 : 4)
            .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

struct KidDuelButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        color.opacity(0.95),
                        color.opacity(0.75)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.06 : 0.16),
                    radius: configuration.isPressed ? 6 : 10,
                    x: 0,
                    y: configuration.isPressed ? 2 : 6)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}


// MARK: - Duel Overlay

struct DuelAnswerOverlay: View {
    @Environment(\.colorScheme) private var colorScheme
    let player: Int
    let questionText: String
    let choices: [Int]
    let wrongPulse: Bool
    let shakeCount: Int
    let onPick: (Int) -> Void
    let onSkip: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                VStack(spacing: 6) {
                    Text("question_title")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.85) : .secondary)

                    Text(questionText)
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(colorScheme == .dark ? .white : .primary)
                }
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(colorScheme == .dark ? Color.black.opacity(0.35) : Color.white.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 18))

                if wrongPulse {
                    Text("❌")
                        .font(.system(size: 52))
                        .transition(.scale)
                }
                Text(player == 1 ? "p1_answer_now" : "p2_answer_now")
                    .font(.system(.title3, design: .rounded).bold())
                    .multilineTextAlignment(.center)

                HStack(spacing: 10) {
                    ForEach(choices, id: \.self) { value in
                        Button {
                            onPick(value)
                        } label: {
                            Text("\(value)")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .frame(maxWidth: .infinity, minHeight: 56)
                        }
                        .buttonStyle(KidButtonStyle())
                    }
                }

                Button {
                    onSkip()
                } label: {
                    Text("skip")
                        .font(.system(.headline, design: .rounded).bold())
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(KidSecondaryButtonStyle())
            }
            .padding(18)
            .frame(maxWidth: 520)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(wrongPulse ? Color.red.opacity(0.85) : Color.white.opacity(0.35), lineWidth: wrongPulse ? 3 : 1)
                    .animation(.easeOut(duration: 0.25), value: wrongPulse)
            )
            .modifier(ShakeEffect(shakes: shakeCount))
            .padding(.horizontal, 18)
        }
    }
}

// MARK: - Shake Effect (for wrong answers)

struct ShakeEffect: GeometryEffect {
    var shakes: Int
    var amplitude: CGFloat = 12

    var animatableData: CGFloat {
        get { CGFloat(shakes) }
        set { /* no-op */ }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        // 6 oscillations across the animation
        let translation = amplitude * sin(CGFloat(shakes) * .pi * 6)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

// MARK: - Confetti (simple)

struct ConfettiOverlay: View {
    @State private var fly = false

    var body: some View {
        ZStack {
            ForEach(0..<16, id: \.self) { i in
                Text(["🎉", "✨", "⭐️", "🎈"].randomElement() ?? "🎉")
                    .font(.system(size: 28))
                    .offset(x: fly ? CGFloat.random(in: -170...170) : 0,
                            y: fly ? CGFloat.random(in: 220...520) : 0)
                    .opacity(fly ? 0 : 1)
                    .rotationEffect(.degrees(fly ? Double.random(in: -220...220) : 0))
                    .animation(.easeOut(duration: 0.9), value: fly)
            }
        }
        .allowsHitTesting(false)
        .onAppear { fly = true }
    }
}


#Preview {
    ContentView()
}

// MARK: - Settings Sheet

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var maxFactor: Int
    @Binding var appLanguage: String // "system", "en", "sk"
    @Binding var roundLength: Int
    @Binding var operationModeRaw: String
    let isPro: Bool
    let onUnlockPro: () -> Void
    let onRestore: () -> Void
    @AppStorage("soundsEnabled") private var soundsEnabled: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $maxFactor, in: 2...12) {
                        HStack {
                            Text("max_table")
                            Spacer()
                            Text("\(maxFactor)")
                                .font(.headline)
                        }
                    }
                    .onChange(of: maxFactor) { _, newValue in
                        if !isPro && newValue > 6 {
                            maxFactor = 6
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                onUnlockPro()
                            }
                        }
                    }
                } header: {
                    Text("settings")
                }

                Section {
                    Picker("operation_mode", selection: $operationModeRaw) {
                        Text("op_multiply").tag(OperationMode.multiply.rawValue)
                        // Show real names even when locked, with lock indicator
                        Text(isPro ? "op_divide" : "op_divide_locked").tag(OperationMode.divide.rawValue)
                        Text(isPro ? "op_add" : "op_add_locked").tag(OperationMode.add.rawValue)
                        Text(isPro ? "op_subtract" : "op_subtract_locked").tag(OperationMode.subtract.rawValue)
                        Text(isPro ? "op_mix" : "op_mix_locked").tag(OperationMode.mix.rawValue)
                    }
                    .onChange(of: operationModeRaw) { _, newValue in
                        let picked = OperationMode(rawValue: newValue) ?? .multiply
                        if !isPro && picked != .multiply {
                            operationModeRaw = OperationMode.multiply.rawValue
                            // Close settings first to avoid sheet-on-sheet delay, then show paywall
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                onUnlockPro()
                            }
                        }
                    }
                } header: {
                    Text("operation_mode")
                }

                Section {
                    Picker("rounds_to_play", selection: $roundLength) {
                        Text("10").tag(10)
                        Text("20").tag(20)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("rounds_to_play")
                }

                Section {
                    Toggle("sounds", isOn: $soundsEnabled)
                } header: {
                    Text("sounds")
                }

                Section {
                    Picker("language", selection: $appLanguage) {
                        Text("system_language").tag("system")
                        Text("english").tag("en")
                        Text("slovak").tag("sk")
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("language")
                }

                Section {
                    if isPro {
                        Label("pro_unlocked", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                onUnlockPro()
                            }
                        } label: {
                            Label("pro_unlock", systemImage: "lock.open.fill")
                        }
                        Button {
                            onRestore()
                        } label: {
                            Label("restore", systemImage: "arrow.clockwise")
                        }
                    }
                } header: {
                    Text("pro")
                }

                // External links — every one is behind the parental gate (Guideline 1.3).
                Section {
                    GatedLinkButton(titleKey: "support", systemImage: "questionmark.circle", url: ParentalGate.supportURL)
                    GatedLinkButton(titleKey: "privacy_policy", systemImage: "hand.raised", url: ParentalGate.privacyURL)
                    GatedLinkButton(titleKey: "terms_of_use", systemImage: "doc.text", url: ParentalGate.termsURL)
                } header: {
                    Text("pro_parent_title")
                } footer: {
                    Text("parents_links_footer")
                }
            }
            .navigationTitle("settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Results Sheet

struct ResultsView: View {
    @Environment(\.dismiss) private var dismiss

    let mode: GameMode
    let roundLength: Int
    let currentRound: Int

    let singleScore: Int
    let singleStreak: Int
    let p1Score: Int
    let p2Score: Int

    let singleTimes: [TimeInterval]
    let duelTimesP1: [TimeInterval]
    let duelTimesP2: [TimeInterval]
    let duelLog: [ContentView.DuelRoundEntry]

    let history: [ContentView.MatchSummary]
    let onNewMatch: () -> Void

    private func avg(_ arr: [TimeInterval]) -> TimeInterval? {
        guard !arr.isEmpty else { return nil }
        return arr.reduce(0, +) / Double(arr.count)
    }

    private func best(_ arr: [TimeInterval]) -> TimeInterval? {
        arr.min()
    }

    private func format(_ t: TimeInterval?) -> String {
        guard let t else { return "—" }
        return String(format: "%.2fs", max(0, t))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("match_status")
                        Spacer()
                        if mode == .single {
                            Text("\(min(singleTimes.count, roundLength))/\(roundLength)")
                                .font(.headline)
                        } else {
                            Text("\(min(duelTimesP1.count + duelTimesP2.count, roundLength))/\(roundLength)")
                                .font(.headline)
                        }
                    }

                    if mode == .single {
                        HStack {
                            Text("score")
                            Spacer()
                            Text("\(singleScore)")
                                .font(.headline)
                        }
                        HStack {
                            Text("streak")
                            Spacer()
                            Text("\(singleStreak)")
                                .font(.headline)
                        }
                        HStack {
                            Text("average")
                            Spacer()
                            Text(format(avg(singleTimes)))
                                .font(.headline)
                        }
                        HStack {
                            Text("best")
                            Spacer()
                            Text(format(best(singleTimes)))
                                .font(.headline)
                        }
                    } else {
                        HStack {
                            Text("player1")
                            Spacer()
                            Text("\(p1Score)")
                                .font(.headline)
                        }
                        HStack {
                            Text("player2")
                            Spacer()
                            Text("\(p2Score)")
                                .font(.headline)
                        }
                        HStack {
                            Text("average") ; Spacer()
                            Text("🟦 \(format(avg(duelTimesP1)))   🟥 \(format(avg(duelTimesP2)))")
                                .font(.headline)
                        }
                        HStack {
                            Text("best") ; Spacer()
                            Text("🟦 \(format(best(duelTimesP1)))   🟥 \(format(best(duelTimesP2)))")
                                .font(.headline)
                        }

                        let a1 = avg(duelTimesP1)
                        let a2 = avg(duelTimesP2)
                        HStack {
                            Text("faster")
                            Spacer()
                            if let a1, let a2 {
                                Text(a1 < a2 ? "🟦" : (a2 < a1 ? "🟥" : "🤝"))
                                    .font(.title3)
                            } else {
                                Text("—")
                            }
                        }
                    }
                }

                if mode == .single {
                    Section("round_times") {
                        ForEach(Array(singleTimes.enumerated()), id: \.offset) { idx, t in
                            HStack {
                                Text("\(idx + 1).")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(String(format: "%.2fs", t))
                                    .font(.headline)
                            }
                        }
                    }
                } else {
                    Section("round_times") {
                        ForEach(duelLog) { entry in
                            HStack {
                                Text("\(entry.round).")
                                    .foregroundStyle(.secondary)
                                Text(entry.player == 1 ? "🟦" : "🟥")
                                Spacer()
                                Text(String(format: "%.2fs", entry.time))
                                    .font(.headline)
                            }
                        }
                    }
                }

                if !history.isEmpty {
                    Section("history") {
                        ForEach(history.prefix(10)) { h in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(h.mode == .single ? "single_mode" : "duel_mode")
                                    .font(.headline)
                                if let s = h.avgSingle {
                                    Text("average: \(String(format: "%.2fs", s))")
                                        .foregroundStyle(.secondary)
                                } else if let a1 = h.avgP1, let a2 = h.avgP2 {
                                    Text("🟦 \(String(format: "%.2fs", a1))   🟥 \(String(format: "%.2fs", a2))")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("results")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("new_match") {
                        onNewMatch()
                        dismiss()
                    }
                }
            }
        }
    }
}
// MARK: - Full-screen Correct Overlay

struct CorrectFullScreenOverlay: View {
    let questionText: String
    let answer: Int

    var body: some View {
        ZStack {
            VStack(spacing: 14) {
                Text("🎉")
                    .font(.system(size: 64))

                Text("correct_toast_title")
                    .font(.system(.title2, design: .rounded).weight(.black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.8))
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.80), radius: 10, x: 0, y: 6)

                Text("\(questionText) = \(answer)")
                    .font(.system(size: 54, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
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
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 10)

                Text("✨")
                    .font(.system(size: 34))
                    .opacity(0.9)
            }
            .padding(.horizontal, 24)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Gate Overlay (Start / Match End)

struct GateOverlay: View {
    let state: ContentView.GateState
    let roundLength: Int

    @Binding var mode: GameMode
    let resultsAvailable: Bool
    let isPro: Bool
    let showFaceOff: Bool
    let onFaceOff: () -> Void
    let onModeChanged: () -> Void

    let onStart: () -> Void
    let onShowResults: () -> Void

    var body: some View {
        ZStack {
            // light blur/veil so the underlying card is visible but blocked
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 14) {
                Text(state == .start ? "🎮" : "🏁")
                    .font(.system(size: 54))

                Picker("mode", selection: $mode) {
                    Text("single_mode").tag(GameMode.single)
                    Text(isPro ? "duel_mode" : "duel_mode_locked").tag(GameMode.duel)
                }
                .pickerStyle(.segmented)
                .onChange(of: mode) { _, newValue in
                    if newValue == .duel && !isPro {
                        mode = .single
                        onModeChanged()
                        return
                    }
                    onModeChanged()
                }
                .frame(maxWidth: 420)

                if showFaceOff {
                    Button(action: onFaceOff) {
                        VStack(spacing: 2) {
                            Label(isPro ? "face_off_mode" : "face_off_locked", systemImage: "person.2.fill")
                                .font(.system(.headline, design: .rounded).bold())
                            Text("face_off_hint")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 54)
                    }
                    .buttonStyle(KidSecondaryButtonStyle())
                    .frame(maxWidth: 420)
                }

                if state == .start {
                    Text("tap_to_start")
                        .font(.system(.title3, design: .rounded).weight(.black))
                        .multilineTextAlignment(.center)

                    Text("\(roundLength) \(String(localized: "round_times"))")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                } else {
                    Text("results")
                        .font(.system(.title3, design: .rounded).weight(.black))
                        .multilineTextAlignment(.center)

                    Text("match_status")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 10) {
                    Button {
                        onStart()
                    } label: {
                        Text(state == .start ? "tap_to_start" : "new_match")
                            .font(.system(.headline, design: .rounded).bold())
                            .frame(maxWidth: .infinity, minHeight: 54)
                    }
                    .buttonStyle(KidButtonStyle())

                    Button {
                        onShowResults()
                    } label: {
                        Text("open_results")
                            .font(.system(.headline, design: .rounded).bold())
                            .frame(maxWidth: .infinity, minHeight: 54)
                    }
                    .buttonStyle(KidSecondaryButtonStyle())
                    .disabled(!resultsAvailable)
                    .opacity(resultsAvailable ? 1 : 0.45)
                }
                .frame(maxWidth: 420)
            }
            .padding(18)
            .frame(maxWidth: 520)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
            )
            .padding(.horizontal, 18)
        }
    }
}
