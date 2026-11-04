import Foundation
import SliceRating
import Testing

@testable import QRReader

@MainActor
struct RatingTests {
    private func prompt(version: String, _ defaults: UserDefaults) -> RatingPrompt {
        RatingPrompt(steps: Rating.prompt.steps, keyPrefix: "test", defaults: defaults, version: version)
    }

    @Test func asksOnTheFirstHappyMomentThenWaitsForTheNextVersion() throws {
        let defaults = try #require(UserDefaults(suiteName: "RatingTests-\(UUID().uuidString)"))
        let v1 = prompt(version: "1.0", defaults)
        #expect(v1.record(Rating.happy))
        for _ in 0..<10 { #expect(!v1.record(Rating.happy)) }
        let v2 = prompt(version: "1.1", defaults)
        #expect(!v2.record(Rating.happy, now: .now.addingTimeInterval(86_400)))  // too soon (30 days)
        #expect(v2.record(Rating.happy, now: .now.addingTimeInterval(31 * 86_400)))
    }

    @Test func neverMoreThanThreeAsks() throws {
        let defaults = try #require(UserDefaults(suiteName: "RatingTests-\(UUID().uuidString)"))
        var asks = 0
        for version in 1...6 {
            let p = prompt(version: "\(version).0", defaults)
            for _ in 0..<30 where p.record(Rating.happy, now: .now.addingTimeInterval(Double(version) * 70 * 86_400)) { asks += 1 }
        }
        #expect(asks == 3)
    }

    @Test func shareMessageNamesTheAppAndLinks() {
        #expect(SettingsScreen.shareMessage.contains("Qodi"))
        #expect(SettingsScreen.shareMessage.contains("https://apps.apple.com/app/id6829893719"))
    }
}
