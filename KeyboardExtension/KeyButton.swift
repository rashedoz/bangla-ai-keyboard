import SwiftUI
import UIKit

/// A keyboard key. The hit area includes the gap around the key so taps between keys still register.
struct KeyButton<Label: View>: View {
    var width: CGFloat
    var special = false
    var prominent = false
    /// Fires on touch-down and keeps firing while held (backspace).
    var repeats = false
    /// Character shown in a magnified bubble above the key while pressed, like the system keyboard.
    var popup: String? = nil
    var popupFontSize: CGFloat = 23
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
                .opacity(pressed && popup != nil ? 0 : 1)
        }
        .frame(width: width, height: KeyboardMetrics.rowHeight)
        .overlay(alignment: .bottom) {
            if pressed, let popup {
                KeyPopup(text: popup, keyWidth: width, fontSize: popupFontSize)
                    .allowsHitTesting(false)
            }
        }
        .zIndex(pressed ? 1 : 0)
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
        // Character keys show the pop-up instead of darkening.
        return pressed && popup == nil ? KeyboardTheme.pressedKey : KeyboardTheme.key
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

/// The magnified bubble that rises above a pressed character key.
private struct KeyPopup: View {
    let text: String
    let keyWidth: CGFloat
    let fontSize: CGFloat

    var body: some View {
        let width = max(keyWidth - KeyboardMetrics.keySpacing, 30) + 14
        Text(text)
            .font(.system(size: fontSize * 1.45))
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .foregroundStyle(Color.primary)
            .frame(width: width, height: 52)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(KeyboardTheme.key)
                    .shadow(color: .black.opacity(0.28), radius: 2, x: 0, y: 1)
            )
            // Sit just above the key's top edge.
            .offset(y: -(KeyboardMetrics.rowHeight - KeyboardMetrics.keyVerticalInset))
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
