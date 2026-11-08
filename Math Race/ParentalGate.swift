//
//  ParentalGate.swift
//  Math Race
//
//  Parental gate required by App Store Guideline 1.3 (Kids Category).
//  It is shown before every purchase and before every link that leaves the app.
//  There is intentionally no setting to turn it off.
//

import SwiftUI

enum ParentalGate {
    /// Public app links (GitHub Pages + Apple's standard EULA).
    static let supportURL = URL(string: "https://joztoz.github.io/mathrace/")!
    static let privacyURL = URL(string: "https://joztoz.github.io/mathrace/privacy.html")!
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    /// A four-digit number: hard for young children to read when written as words.
    static func randomNumber() -> Int {
        var n = Int.random(in: 1001...9999)
        while n % 100 == 0 { n = Int.random(in: 1001...9999) }
        return n
    }

    static func words(for number: Int, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .spellOut
        formatter.locale = locale
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

/// Adult challenge: the number is written in words, the adult types it with digits.
struct ParentalGateView: View {
    let onSuccess: () -> Void
    let onCancel: () -> Void

    @Environment(\.locale) private var locale
    @State private var number = ParentalGate.randomNumber()
    @State private var input = ""
    @State private var wrongAnswer = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.tint)
                        .padding(.top, 12)

                    Text("gate_title")
                        .font(.system(.title2, design: .rounded).weight(.black))
                        .multilineTextAlignment(.center)

                    Text("gate_instruction")
                        .font(.system(.body, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)

                    Text(ParentalGate.words(for: number, locale: locale))
                        .font(.system(.title3, design: .serif).weight(.semibold))
                        .multilineTextAlignment(.center)
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .accessibilityIdentifier("parentalGateQuestion")

                    TextField("gate_placeholder", text: $input)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .font(.system(.title2, design: .rounded).monospacedDigit())
                        .multilineTextAlignment(.center)
                        .padding(12)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .focused($fieldFocused)
                        .onChange(of: input) { _, newValue in
                            let digits = String(newValue.filter(\.isNumber).prefix(5))
                            if digits != newValue { input = digits }
                            wrongAnswer = false
                        }
                        .accessibilityIdentifier("parentalGateAnswer")

                    if wrongAnswer {
                        Text("gate_wrong")
                            .font(.system(.footnote, design: .rounded).weight(.semibold))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button(action: check) {
                        Text("gate_continue")
                            .font(.system(.headline, design: .rounded).bold())
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(input.isEmpty)
                }
                .padding(20)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("gate_nav_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("gate_cancel") { onCancel() }
                }
            }
            .onAppear { fieldFocused = true }
        }
    }

    private func check() {
        if Int(input) == number {
            onSuccess()
        } else {
            // Wrong answer: new challenge, so guessing doesn't help.
            wrongAnswer = true
            input = ""
            number = ParentalGate.randomNumber()
        }
    }
}

/// A button that opens an external URL only after the parental gate is passed.
struct GatedLinkButton: View {
    let titleKey: LocalizedStringKey
    let systemImage: String
    let url: URL

    @Environment(\.openURL) private var openURL
    @State private var showGate = false

    var body: some View {
        Button {
            showGate = true
        } label: {
            Label(titleKey, systemImage: systemImage)
        }
        .sheet(isPresented: $showGate) {
            ParentalGateView(
                onSuccess: {
                    showGate = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { openURL(url) }
                },
                onCancel: { showGate = false }
            )
        }
    }
}
