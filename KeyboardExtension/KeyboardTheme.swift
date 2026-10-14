import SwiftUI
import UIKit

enum KeyboardMetrics {
    static let barHeight: CGFloat = 60
    static let rowHeight: CGFloat = 54
    static let keyVerticalInset: CGFloat = 5
    static let keySpacing: CGFloat = 6
    static let sidePadding: CGFloat = 3
    static let totalHeight: CGFloat = barHeight + rowHeight * 4 + 6
}

enum KeyboardTheme {
    private static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }

    static let key = dynamic(light: .white, dark: UIColor(white: 0.42, alpha: 1))
    static let specialKey = dynamic(light: UIColor(red: 0.67, green: 0.70, blue: 0.74, alpha: 1),
                                    dark: UIColor(white: 0.27, alpha: 1))
    static let pressedKey = dynamic(light: UIColor(red: 0.67, green: 0.70, blue: 0.74, alpha: 1),
                                    dark: UIColor(white: 0.55, alpha: 1))
    static let pressedSpecial = dynamic(light: .white, dark: UIColor(white: 0.42, alpha: 1))
    static let shadow = Color.black.opacity(0.32)
    static let barBackground = dynamic(light: UIColor(white: 1, alpha: 0.55), dark: UIColor(white: 1, alpha: 0.08))
    static let accent = Color(UIColor.systemBlue)
}
