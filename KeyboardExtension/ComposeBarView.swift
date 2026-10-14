import BanglaKit
import SwiftUI

/// The strip above the keys: Banglish input, AI result, and the Convert / Edit / Insert actions.
struct ComposeBarView: View {
    @ObservedObject var model: KeyboardModel

    var body: some View {
        HStack(spacing: 8) {
            if model.state.mode == .ai {
                aiContent
            } else {
                directContent
            }
        }
        .padding(.horizontal, 10)
        .frame(height: KeyboardMetrics.barHeight - 8)
        .background(KeyboardTheme.barBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 6)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    // MARK: - AI mode

    @ViewBuilder
    private var aiContent: some View {
        let state = model.state
        switch state.phase {
        case .composing:
            if state.source.isEmpty {
                Text("Type Banglish… e.g. ami bhat khai")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                barButton("text.insert", label: "Convert field text", action: model.useFieldText)
            } else if state.preview.isEmpty {
                (Text(state.source) + Text("|").foregroundColor(KeyboardTheme.accent))
                    .lineLimit(2)
                    .truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .leading)
                barButton("xmark", label: "Clear", action: model.clear)
                pillButton("Convert", icon: "sparkles", action: model.convert)
            } else {
                // Live preview: what you typed on top, the Bangla below. Dimmed while it catches up.
                VStack(alignment: .leading, spacing: 1) {
                    (Text(state.source) + Text("|").foregroundColor(KeyboardTheme.accent))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                    Text(state.preview)
                        .font(.system(size: 18))
                        .lineLimit(1)
                        .truncationMode(.head)
                        .opacity(state.isPreviewFresh ? 1 : 0.45)
                        .animation(.easeOut(duration: 0.12), value: state.isPreviewFresh)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if state.isPreviewFresh {
                    barButton("pencil", label: "Edit", action: model.edit)
                    barButton("xmark", label: "Clear", action: model.clear)
                    pillButton("Insert", icon: nil, action: model.insertResult)
                } else {
                    barButton("xmark", label: "Clear", action: model.clear)
                    pillButton("Convert", icon: "sparkles", action: model.convert)
                }
            }
        case .converting:
            VStack(alignment: .leading, spacing: 1) {
                Text(state.source)
                    .font(state.result.isEmpty ? .body : .caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
                if !state.result.isEmpty {
                    Text(state.result)
                        .font(.system(size: 18))
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ProgressView()
            barButton("xmark", label: "Cancel", action: model.clear)
        case .result:
            VStack(alignment: .leading, spacing: 1) {
                Text(state.source)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
                Text(state.result)
                    .font(.system(size: 18))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            barButton("pencil", label: "Edit", action: model.edit)
            barButton("arrow.clockwise", label: "Retry", action: model.convert)
            barButton("xmark", label: "Clear", action: model.clear)
            pillButton("Insert", icon: nil, action: model.insertResult)
        case .editing:
            let parts = state.resultParts
            (Text(parts.before) + Text("|").foregroundColor(KeyboardTheme.accent) + Text(parts.after))
                .font(.system(size: 18))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
            barButton("chevron.left", label: "Move cursor left") { model.moveCursor(-1) }
            barButton("chevron.right", label: "Move cursor right") { model.moveCursor(1) }
            pillButton("Done", icon: nil, action: model.finishEditing)
        case .error(let message):
            Label {
                Text(message).font(.caption).lineLimit(3).minimumScaleFactor(0.8)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            barButton("arrow.clockwise", label: "Retry", action: model.convert)
            barButton("xmark", label: "Clear", action: model.clear)
        }
    }

    // MARK: - English / Bangla modes

    @ViewBuilder
    private var directContent: some View {
        Text(model.state.mode == .english ? "English keyboard" : "বাংলা কীবোর্ড")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        pillButton("AI", icon: "sparkles", action: model.switchToAI)
    }

    // MARK: - Buttons

    private func barButton(_ systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .accessibilityLabel(label)
    }

    private func pillButton(_ title: String, icon: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon { Image(systemName: icon) }
                Text(title)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(KeyboardTheme.accent, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct KeyboardRootView: View {
    @ObservedObject var model: KeyboardModel

    var body: some View {
        VStack(spacing: 0) {
            ComposeBarView(model: model)
            KeyGridView(config: model.gridConfig, model: model)
                .equatable()
        }
        .frame(height: KeyboardMetrics.totalHeight, alignment: .top)
    }
}
