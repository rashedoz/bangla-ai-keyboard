import BanglaKit
import SwiftUI

/// The keys. Takes a value snapshot (`GridConfig`) and is `Equatable`, so SwiftUI skips
/// re-rendering it while the user types into the compose bar.
struct KeyGridView: View, Equatable {
    let config: GridConfig
    /// Not observed: actions only. Redraws are driven by `config`.
    let model: KeyboardModel

    static func == (lhs: KeyGridView, rhs: KeyGridView) -> Bool {
        lhs.config == rhs.config
    }

    var body: some View {
        GeometryReader { geo in
            let available = geo.size.width - KeyboardMetrics.sidePadding * 2
            let unit = available / 10
            VStack(spacing: 0) {
                ForEach(Array(config.rows.enumerated()), id: \.offset) { _, row in
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
                          popup: popupText(for: key),
                          popupFontSize: fontSize,
                          action: { model.tap(key) }) {
                    keyLabel(key)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var fontSize: CGFloat { config.language == .bangla ? 21 : 23 }

    private func popupText(for key: KeySpec) -> String? {
        if case .character(let value) = key.action { return value }
        return nil
    }

    @ViewBuilder
    private func keyLabel(_ key: KeySpec) -> some View {
        switch key.action {
        case .shift:
            Image(systemName: config.shift == .locked ? "capslock.fill" : (config.shift == .once ? "shift.fill" : "shift"))
                .font(.system(size: 18, weight: .medium))
        case .backspace:
            Image(systemName: "delete.left").font(.system(size: 18, weight: .medium))
        case .layer:
            Text(key.label).font(.system(size: 15))
        case .character:
            Text(key.label)
                .font(.system(size: fontSize))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
    }

    private func bottomRow(available: CGFloat, unit: CGFloat) -> some View {
        let layerWidth = unit * 1.25
        let globeWidth = config.needsGlobe ? unit * 1.15 : 0
        let modeWidth = unit * 1.25
        let returnWidth = unit * 2.1
        let spaceWidth = max(unit * 2, available - layerWidth - globeWidth - modeWidth - returnWidth)
        return HStack(spacing: 0) {
            KeyButton(width: layerWidth, special: true, action: model.toggleLayer) {
                Text(config.layerLabel).font(.system(size: 15))
            }
            if config.needsGlobe {
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
                Text(config.modeLabel).font(.system(size: 15, weight: .semibold))
            }
            KeyButton(width: spaceWidth, action: model.space) {
                Text(config.spaceLabel).font(.system(size: 15)).foregroundStyle(.secondary)
            }
            KeyButton(width: returnWidth, special: true, prominent: config.returnProminent, action: model.returnKey) {
                Text(config.returnLabel).font(.system(size: 15, weight: config.returnProminent ? .semibold : .regular))
            }
        }
        .frame(maxWidth: .infinity)
    }
}
