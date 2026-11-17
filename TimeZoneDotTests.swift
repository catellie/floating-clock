import Foundation

@main
struct TimeZoneDotTests {
    static func withDefaults(_ test: (UserDefaults) throws -> Void) rethrows {
        let suiteName = "FloatingClock.TimeZoneDotTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try test(defaults)
    }

    static func sampleDots() -> [TimeZoneDot] {
        [
            TimeZoneDot(
                label: "Tokyo 東京",
                timeZoneIdentifier: "Asia/Tokyo",
                color: DotColor(red: 0.1, green: 0.7, blue: 0.9)
            ),
            TimeZoneDot(
                label: "London",
                timeZoneIdentifier: "Europe/London",
                color: DotColor(red: 0.8, green: 0.6, blue: 0.2)
            ),
        ]
    }

    static func main() throws {
        try withDefaults { defaults in
            let dots = TimeZoneDot.load(from: defaults)
            assert(dots.count == 1)
            assert(dots[0].label == "East Coast")
            assert(dots[0].timeZoneIdentifier == "America/New_York")
            assert(dots[0].color == DotColor(red: 1, green: 0.23, blue: 0.25))
            assert(TimeZoneDot.eastCoast.label == dots[0].label)
            assert(TimeZoneDot.eastCoast.timeZoneIdentifier == dots[0].timeZoneIdentifier)
            assert(TimeZoneDot.eastCoast.color == dots[0].color)
            let data = defaults.data(forKey: "timeZoneDots")!
            let decoded = try JSONDecoder().decode([TimeZoneDot].self, from: data)
            assert(decoded == dots)
            assert(TimeZoneDot.load(from: defaults) == dots)
            assert(defaults.data(forKey: "timeZoneDots") == data)
            assert(defaults.object(forKey: "showsAlternateTime") == nil)
        }

        withDefaults { defaults in
            defaults.set("  Family 🌍  ", forKey: "alternateLabel")
            defaults.set("Asia/Kathmandu", forKey: "alternateTimeZone")
            defaults.set(false, forKey: "showsAlternateTime")
            let dots = TimeZoneDot.load(from: defaults)
            assert(dots.count == 1)
            assert(dots[0].label == "  Family 🌍  ")
            assert(dots[0].timeZoneIdentifier == "Asia/Kathmandu")
            assert(dots[0].color == .defaultRed)
            assert(defaults.string(forKey: "alternateLabel") == "  Family 🌍  ")
            assert(defaults.string(forKey: "alternateTimeZone") == "Asia/Kathmandu")
            assert(!defaults.bool(forKey: "showsAlternateTime"))
            let data = defaults.data(forKey: "timeZoneDots")!
            defaults.set("Changed legacy label", forKey: "alternateLabel")
            defaults.set("Europe/Paris", forKey: "alternateTimeZone")
            assert(TimeZoneDot.load(from: defaults) == dots)
            assert(defaults.data(forKey: "timeZoneDots") == data)
        }

        withDefaults { defaults in
            defaults.set("Home", forKey: "alternateLabel")
            defaults.set("Not/A_TimeZone", forKey: "alternateTimeZone")
            let dots = TimeZoneDot.load(from: defaults)
            assert(dots.count == 1)
            assert(dots[0].label == "Home")
            assert(dots[0].timeZoneIdentifier == "America/New_York")
            assert(TimeZoneDot.load(from: defaults) == dots)
        }

        withDefaults { defaults in
            defaults.set("", forKey: "alternateLabel")
            let dots = TimeZoneDot.load(from: defaults)
            assert(dots[0].label.isEmpty)
            assert(dots[0].timeZoneIdentifier == "America/New_York")
        }

        withDefaults { defaults in
            defaults.set("Pacific/Auckland", forKey: "alternateTimeZone")
            let dots = TimeZoneDot.load(from: defaults)
            assert(dots[0].label == "East Coast")
            assert(dots[0].timeZoneIdentifier == "Pacific/Auckland")
        }

        try withDefaults { defaults in
            let dots = sampleDots()
            assert(dots[0].id != dots[1].id)
            TimeZoneDot.save(dots, to: defaults)
            let data = defaults.data(forKey: "timeZoneDots")!
            let decoded = try JSONDecoder().decode([TimeZoneDot].self, from: data)
            assert(decoded == dots)
            assert(TimeZoneDot.load(from: defaults) == dots)
            assert(defaults.object(forKey: "alternateLabel") == nil)
            assert(defaults.object(forKey: "alternateTimeZone") == nil)
        }

        withDefaults { defaults in
            defaults.set("Legacy", forKey: "alternateLabel")
            defaults.set("America/New_York", forKey: "alternateTimeZone")
            defaults.set(true, forKey: "showsAlternateTime")
            var dots = sampleDots()
            TimeZoneDot.save(dots, to: defaults)
            let originalID = dots[0].id
            dots[0].label = "Sydney"
            dots[0].timeZoneIdentifier = "Australia/Sydney"
            dots[0].color = DotColor(red: 0.3, green: 0.2, blue: 0.1)
            TimeZoneDot.save(dots, to: defaults)
            assert(TimeZoneDot.load(from: defaults) == dots)
            assert(TimeZoneDot.load(from: defaults)[0].id == originalID)
            dots.remove(at: 0)
            TimeZoneDot.save(dots, to: defaults)
            assert(TimeZoneDot.load(from: defaults) == dots)
            TimeZoneDot.save([], to: defaults)
            assert(defaults.data(forKey: "timeZoneDots") == Data("[]".utf8))
            assert(TimeZoneDot.load(from: defaults).isEmpty)
            defaults.set("Resurrected?", forKey: "alternateLabel")
            defaults.set("Europe/Paris", forKey: "alternateTimeZone")
            assert(TimeZoneDot.load(from: defaults).isEmpty)
            assert(defaults.bool(forKey: "showsAlternateTime"))
        }

        withDefaults { defaults in
            defaults.set(Data("not JSON".utf8), forKey: "timeZoneDots")
            defaults.set("Recovered", forKey: "alternateLabel")
            defaults.set("Europe/Berlin", forKey: "alternateTimeZone")
            let dots = TimeZoneDot.load(from: defaults)
            assert(dots.count == 1)
            assert(dots[0].label == "Recovered")
            assert(dots[0].timeZoneIdentifier == "Europe/Berlin")
            assert(TimeZoneDot.load(from: defaults) == dots)
        }

        print("TimeZoneDotTests passed: 8 isolated persistence and migration scenarios")
    }
}
