import AudioToolbox
import UIKit

/// Sound and vibration after a scan, following Settings.
enum Feedback {
    static func scanned() {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: SettingsKey.vibration) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        if defaults.bool(forKey: SettingsKey.sound) {
            AudioServicesPlaySystemSound(1057)  // short "Tink"
        }
    }
}
