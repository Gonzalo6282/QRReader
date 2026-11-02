import SwiftUI
import SliceUI

/// Qodi's two looks (Build Doc "Look"), with the approved mockup's colours.
/// Camera, onboarding and paywall are always dark (brand); Create, History and
/// Settings follow iOS light and dark mode.
enum QodiTheme {
    /// Brand accent: reticle, primary buttons.
    static let lime = Color(hex: "#7fee64")
    /// Text on lime.
    static let onLime = Color(hex: "#071405")
    /// Lime readable as text on light surfaces.
    static let limeInk = Color(light: "#2a7d17", dark: "#7fee64")

    /// Lime on void black, whatever the system setting.
    static let brand = SliceTheme(
        appearance: .dark,
        accent: lime, accentSoft: lime.opacity(0.16), accentEdge: lime.opacity(0.45), onAccent: onLime,
        canvas: Color(hex: "#000000"), surface: Color(hex: "#181818"), surfaceAlt: Color(hex: "#242624"),
        line: Color(hex: "#1f221e"),
        ink: Color(hex: "#ddffdc"), inkSecondary: Color(hex: "#8cab87"), inkTertiary: Color(hex: "#6f786c"),
        success: lime, successInk: onLime,
        danger: Color(hex: "#ff6369"), warning: Color(hex: "#ffb64a")
    )

    /// iOS grouped style with a green bias, light and dark.
    static let main = SliceTheme(
        appearance: .system,
        accent: limeInk, onAccent: Color(light: "#ffffff", dark: "#071405"),
        canvas: Color(light: "#f1f3ef", dark: "#000000"), surface: Color(light: "#ffffff", dark: "#1b1e1a"),
        surfaceAlt: Color(light: "#e7ebe4", dark: "#222622"), line: Color(light: "#dfe4dc", dark: "#272b26"),
        ink: Color(light: "#0e130d", dark: "#eef3ec"), inkSecondary: Color(light: "#5c6659", dark: "#98a294"),
        inkTertiary: Color(light: "#8b9488", dark: "#6c7569"),
        success: limeInk, successInk: .white,
        danger: Color(light: "#d93a3f", dark: "#ff6369"), warning: Color(light: "#b86e00", dark: "#ffb64a")
    )

    /// Result-card banners.
    static let okWash = Color(light: "#e6f7df", dark: "#16290f")
    static let warnWash = Color(light: "#fff3dc", dark: "#2e2412")
    /// Bottom sheets.
    static let sheet = Color(light: "#f1f3ef", dark: "#0f110f")
    /// Favourite star.
    static let star = Color(hex: "#e6a700")
}

/// The mockup's lime button (`.btn-lime`): lime with near-black text in every theme.
struct LimeButtonStyle: ButtonStyle {
    var height: CGFloat = 54

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: height)
            .foregroundStyle(QodiTheme.onLime)
            .background(QodiTheme.lime.opacity(configuration.isPressed ? 0.85 : 1), in: RoundedRectangle(cornerRadius: 16))
    }
}

/// The mockup's plain button (`.btn-plain`): surface fill, ink text.
struct PlainFillButtonStyle: ButtonStyle {
    @Environment(\.sliceTheme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(theme.ink)
            .background(theme.surfaceAlt.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: 16))
    }
}

/// Icon tile (`.ibox`).
struct IconTile: View {
    let systemName: String
    var size: CGFloat = 30
    var lime = false
    @Environment(\.sliceTheme) private var theme

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.5, weight: .semibold))
            .frame(width: size, height: size)
            .foregroundStyle(lime ? QodiTheme.onLime : theme.ink)
            .background(lime ? QodiTheme.lime : theme.surfaceAlt, in: RoundedRectangle(cornerRadius: size * 0.27))
    }
}
