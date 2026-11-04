import Foundation
import SliceRating

/// The App Store rating pop-up after happy moments (SliceRating). Three places record a
/// happy moment: saving a created code, sharing a created code, and finishing an action
/// on a scan without leaving the app (copy, join Wi-Fi, add contact or event, share).
/// The library asks at most once per app version and stops after the last step;
/// iOS also shows it at most 3 times a year and never after the person has rated.
enum Rating {
    static let happy = RatingMoment("happy")

    static let prompt = RatingPrompt(
        steps: [
            RatingStep(after: happy, count: 1),
            RatingStep(after: happy, count: 8, daysSinceLastAsk: 30),
            RatingStep(after: happy, count: 20, daysSinceLastAsk: 60),
        ],
        keyPrefix: "qodiRating")

    static func happyMoment() {
        guard !AppConfig.isUITesting else { return }
        prompt.ask(after: happy)
    }
}
