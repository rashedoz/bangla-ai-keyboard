import BanglaKit
import SwiftUI

struct KeyGridView: View {
    @ObservedObject var model: KeyboardModel

    var body: some View {
        GeometryReader { geo in
            let available = geo.size.width - KeyboardMetrics.sidePadding * 2
            let unit = available / 10
            VStack(spacing: 0) {
                ForEach(Array(model.rows.enumerated()), id: \.offset) { _, row in
                    keyRow(row, available: available, unit: unit)
                }
                bottomRow(available: available, unit: unit)
            }
            .padding(.horizontal, KeyboardMetrics.sidePadding)
        }
        .frame(height: KeyboardMetrics.rowHeight * 4)
    }

    private func keyRow(_ row: [KeySpec], available: CGFloat, unit: CGFloat) -> some View {
        let totalUnits = row.reduce(0) { $0 + $1.width }
        let rowUnit = min(unit, available / totalUnits)
        return HStack(spacing: 0) {
            // Keyed by position so shift / layout swaps reuse views instead of
            // recreating them, which would drop a tap made mid-swap.
            ForEach(Array(row.enumerated()), id: \.offset) { _, key in
                KeyButton(width: rowUnit * key.width,
                          special: key.isSpecial,
                          repeats: key.action == .backspace,
                          action: { model.tap(key) }) {
                    keyLabel(key)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func keyLabel(_ key: KeySpec) -> some View {
        switch key.action {
        case .shift:
            Image(systemName: model.shift == .locked ? "capslock.fill" : (model.shift == .once ? "shift.fill" : "shift"))
                .font(.system(size: 18, weight: .medium))
        case .backspace:
            Image(systemName: "delete.left").font(.system(size: 18, weight: .medium))
        case .layer:
            Text(key.label).font(.system(size: 15))
        case .character:
            Text(key.label)
                .font(.system(size: model.state.displayLanguage == .bangla ? 21 : 23))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
    }

    private func bottomRow(available: CGFloat, unit: CGFloat) -> some View {
        let layerWidth = unit * 1.25
        let globeWidth = model.needsGlobeKey ? unit * 1.15 : 0
        let modeWidth = unit * 1.25
        let returnWidth = unit * 2.1
        let spaceWidth = max(unit * 2, available - layerWidth - globeWidth - modeWidth - returnWidth)
        return HStack(spacing: 0) {
            KeyButton(width: layerWidth, special: true, action: model.toggleLayer) {
                Text(model.layerKeyLabel).font(.system(size: 15))
            }
            if model.needsGlobeKey {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(KeyboardTheme.specialKey)
                        .shadow(color: KeyboardTheme.shadow, radius: 0, x: 0, y: 1)
                        .padding(.horizontal, KeyboardMetrics.keySpacing / 2)
                        .padding(.vertical, KeyboardMetrics.keyVerticalInset)
                    GlobeKey(controller: model.controller)
                }
                .frame(width: globeWidth, height: KeyboardMetrics.rowHeight)
            }
            KeyButton(width: modeWidth, special: true, action: model.modeKey) {
                Text(model.modeKeyLabel).font(.system(size: 15, weight: .semibold))
            }
            KeyButton(width: spaceWidth, action: model.space) {
                Text(spaceLabel).font(.system(size: 15)).foregroundStyle(.secondary)
            }
            KeyButton(width: returnWidth, special: true, prominent: model.returnIsProminent, action: model.returnKey) {
                Text(model.returnLabel).font(.system(size: 15, weight: model.returnIsProminent ? .semibold : .regular))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var spaceLabel: String {
        switch model.state.mode {
        case .ai: return model.state.phase == .editing ? "বাংলা (edit)" : "Banglish → বাংলা"
        case .english: return "English"
        case .bangla: return "বাংলা"
        }
    }
}
