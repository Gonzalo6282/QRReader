import SwiftUI
import SliceUI

/// Qodi's two looks (Build Doc "Look"): camera, onboarding and paywall are always
/// dark (brand); Create, History and Settings follow iOS light and dark mode.
/// Colours come from the approved mockup. Refined in M2 (T2.1).
enum QodiTheme {
    static let lime = Color(hex: "#7fee64")

    /// Lime on near-black, whatever the system setting.
    static let brand = SliceTheme.dark(accent: lime, background: Color(hex: "#000000"))

    /// System light/dark, with the darker green for lime-coloured text on light screens.
    static let main = SliceTheme.system(
        accent: Color(light: "#2a7d17", dark: "#7fee64"),
        onAccent: Color(light: "#ffffff", dark: "#071405")
    )
}
