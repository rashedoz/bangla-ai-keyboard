import SwiftUI
import UIKit

/// A keyboard key. The hit area includes the gap around the key so taps between keys still register.
struct KeyButton<Label: View>: View {
    var width: CGFloat
    var special = false
    var prominent = false
    /// Fires on touch-down and keeps firing while held (backspace).
    var repeats = false
    var action: () -> Void
    @ViewBuilder var label: () -> Label

    @State private var pressed = false
    @State private var repeatTimer: Timer?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(background)
                .shadow(color: KeyboardTheme.shadow, radius: 0, x: 0, y: 1)
                .padding(.horizontal, KeyboardMetrics.keySpacing / 2)
                .padding(.vertical, KeyboardMetrics.keyVerticalInset)
            label()
                .foregroundStyle(prominent ? Color.white : Color.primary)
        }
        .frame(width: width, height: KeyboardMetrics.rowHeight)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !pressed else { return }
                    pressed = true
                    if repeats { startRepeating() }
                }
                .onEnded { _ in
                    if !repeats { action() }
                    stopRepeating()
                    pressed = false
                }
        )
        .accessibilityElement()
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { action() }
    }

    private var background: Color {
        if prominent { return pressed ? KeyboardTheme.accent.opacity(0.7) : KeyboardTheme.accent }
        if special { return pressed ? KeyboardTheme.pressedSpecial : KeyboardTheme.specialKey }
        return pressed ? KeyboardTheme.pressedKey : KeyboardTheme.key
    }

    private func startRepeating() {
        action()
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { _ in
            Task { @MainActor in
                repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
                    Task { @MainActor in action() }
                }
            }
        }
    }

    private func stopRepeating() {
        repeatTimer?.invalidate()
        repeatTimer = nil
    }
}

/// The 🌐 key must be a UIKit control so it can call `handleInputModeList(from:with:)`,
/// which shows the system keyboard picker on long-press.
struct GlobeKey: UIViewRepresentable {
    weak var controller: UIInputViewController?

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "globe"), for: .normal)
        button.tintColor = .label
        if let controller {
            button.addTarget(controller,
                             action: #selector(UIInputViewController.handleInputModeList(from:with:)),
                             for: .allTouchEvents)
        }
        button.accessibilityLabel = "Next keyboard"
        return button
    }

    func updateUIView(_ uiView: UIButton, context: Context) {}
}
