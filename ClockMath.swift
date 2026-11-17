import Foundation

enum ClockMath {
    static func dotLanes(for angles: [Double]) -> [Int] {
        var lanes: [Int] = []
        for (index, angle) in angles.enumerated() {
            var usedLanes: Set<Int> = []
            for prior in 0..<index {
                let difference = angle - angles[prior]
                if abs(atan2(sin(difference), cos(difference))) < 0.18 {
                    usedLanes.insert(lanes[prior])
                }
            }
            var lane = 0
            while usedLanes.contains(lane) {
                lane += 1
            }
            lanes.append(lane)
        }
        return lanes
    }

    static func angles(at date: Date, calendar: Calendar) -> (hour: Double, minute: Double, second: Double) {
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        let second = Double(components.second!)
        let minute = Double(components.minute!) + second / 60
        let hour = Double(components.hour! % 12) + minute / 60
        let fullTurn = 2 * Double.pi
        return (hour / 12 * fullTurn, minute / 60 * fullTurn, second / 60 * fullTurn)
    }

    static func timeZoneLabel(at date: Date, timeZone: TimeZone) -> String {
        let offset = timeZone.secondsFromGMT(for: date)
        guard offset != 0 else { return "GMT" }
        let sign = offset > 0 ? "+" : "-"
        let totalMinutes = abs(offset) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        let suffix = minutes == 0 ? "" : String(format: ":%02d", minutes)
        return "GMT\(sign)\(hours)\(suffix)"
    }
}
