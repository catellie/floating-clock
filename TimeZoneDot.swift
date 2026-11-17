import Foundation

struct DotColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double

    static let defaultRed = DotColor(red: 1, green: 0.23, blue: 0.25)
}

struct TimeZoneDot: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var label: String
    var timeZoneIdentifier: String
    var color: DotColor

    static let eastCoast = TimeZoneDot(
        label: "East Coast",
        timeZoneIdentifier: "America/New_York",
        color: .defaultRed
    )

    static func load(from defaults: UserDefaults) -> [TimeZoneDot] {
        if let data = defaults.data(forKey: "timeZoneDots"),
           let dots = try? JSONDecoder().decode([TimeZoneDot].self, from: data) {
            return dots
        }

        let legacyIdentifier = defaults.string(forKey: "alternateTimeZone")
            ?? eastCoast.timeZoneIdentifier
        let identifier = TimeZone(identifier: legacyIdentifier) == nil
            ? eastCoast.timeZoneIdentifier : legacyIdentifier
        let dots = [TimeZoneDot(
            label: defaults.string(forKey: "alternateLabel") ?? eastCoast.label,
            timeZoneIdentifier: identifier,
            color: .defaultRed
        )]
        save(dots, to: defaults)
        return dots
    }

    static func save(_ dots: [TimeZoneDot], to defaults: UserDefaults) {
        do {
            let data = try JSONEncoder().encode(dots)
            defaults.set(data, forKey: "timeZoneDots")
        } catch {
            preconditionFailure("Could not encode time-zone dots: \(error)")
        }
    }
}
