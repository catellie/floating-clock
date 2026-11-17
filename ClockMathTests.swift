import Foundation

@main
struct ClockMathTests {
    static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        func date(month: Int = 1, hour: Int = 0, minute: Int = 0, second: Int = 0) -> Date {
            calendar.date(from: DateComponents(
                year: 2025, month: month, day: 15, hour: hour, minute: minute, second: second
            ))!
        }

        func assertAngles(
            _ date: Date,
            calendar: Calendar,
            hour: Double,
            minute: Double,
            second: Double
        ) {
            let actual = ClockMath.angles(at: date, calendar: calendar)
            assert(abs(actual.hour - hour) < 1e-12, "Hour: \(actual.hour) != \(hour)")
            assert(abs(actual.minute - minute) < 1e-12, "Minute: \(actual.minute) != \(minute)")
            assert(abs(actual.second - second) < 1e-12, "Second: \(actual.second) != \(second)")
        }

        assertAngles(date(), calendar: calendar, hour: 0, minute: 0, second: 0)
        assertAngles(date(hour: 12), calendar: calendar, hour: 0, minute: 0, second: 0)

        // 03:15:30 corresponds to 97.75, 93, and 180 degrees clockwise.
        for hour in [3, 15] {
            assertAngles(
                date(hour: hour, minute: 15, second: 30),
                calendar: calendar,
                hour: 97.75 * .pi / 180,
                minute: 93 * .pi / 180,
                second: .pi
            )
        }
        assertAngles(
            date(hour: 3, minute: 15, second: 30).addingTimeInterval(0.75),
            calendar: calendar,
            hour: 97.75 * .pi / 180,
            minute: 93 * .pi / 180,
            second: .pi
        )

        var offsetCalendar = calendar
        offsetCalendar.timeZone = TimeZone(secondsFromGMT: 3 * 3600)!
        assertAngles(date(), calendar: offsetCalendar, hour: .pi / 2, minute: 0, second: 0)

        var easternCalendar = Calendar(identifier: .gregorian)
        easternCalendar.timeZone = TimeZone(identifier: "America/New_York")!
        let iso8601 = ISO8601DateFormatter()
        for (instant, expectedDegrees) in [
            ("2026-01-15T02:30:00Z", 285.0), // Previous day, 21:30 EST.
            ("2026-07-15T13:15:00Z", 277.5), // 09:15 EDT.
            ("2026-03-08T06:59:00Z", 59.5), // 01:59 EST.
            ("2026-03-08T07:00:00Z", 90.0), // 03:00 EDT.
            ("2026-11-01T05:30:00Z", 45.0), // First 01:30, EDT.
            ("2026-11-01T06:30:00Z", 45.0), // Repeated 01:30, EST.
        ] {
            let actual = ClockMath.angles(at: iso8601.date(from: instant)!, calendar: easternCalendar)
            let expected = expectedDegrees * .pi / 180
            assert(abs(actual.hour - expected) < 1e-12,
                   "Eastern hour at \(instant): \(actual.hour) != \(expected)")
        }

        let winter = date()
        for (offset, expected) in [
            (0, "GMT"),
            (3600, "GMT+1"),
            (5 * 3600 + 30 * 60, "GMT+5:30"),
            (-(3 * 3600 + 30 * 60), "GMT-3:30"),
            (45 * 60, "GMT+0:45"),
            (-30 * 60, "GMT-0:30"),
        ] {
            let actual = ClockMath.timeZoneLabel(at: winter, timeZone: TimeZone(secondsFromGMT: offset)!)
            assert(actual == expected, "Time zone: \(actual) != \(expected)")
        }

        let losAngeles = TimeZone(identifier: "America/Los_Angeles")!
        assert(ClockMath.timeZoneLabel(at: winter, timeZone: losAngeles) == "GMT-8")
        assert(ClockMath.timeZoneLabel(at: date(month: 7), timeZone: losAngeles) == "GMT-7")

        assert(ClockMath.dotLanes(for: []) == [])
        assert(ClockMath.dotLanes(for: [0, 1, 2, 3]) == [0, 0, 0, 0])
        assert(ClockMath.dotLanes(for: [1, 1, 1]) == [0, 1, 2])
        assert(ClockMath.dotLanes(for: [0.01, 2 * .pi - 0.01]) == [0, 1])
        assert(ClockMath.dotLanes(for: [0, 0.1, 0.25]) == [0, 1, 0])

        print("ClockMathTests passed: 12 angle cases (24 assertions), 8 time-zone assertions, 5 layout tests")
    }
}
