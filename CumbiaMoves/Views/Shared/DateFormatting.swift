import Foundation

extension Date {
    var friendlyLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(self) { return "Today" }
        if cal.isDateInYesterday(self) { return "Yesterday" }

        let now = Date()
        let startOfNow = cal.startOfDay(for: now)
        let startOfSelf = cal.startOfDay(for: self)
        let dayDelta = cal.dateComponents([.day], from: startOfSelf, to: startOfNow).day ?? 0

        if dayDelta >= 2 && dayDelta < 7 {
            return "\(dayDelta) days ago"
        }

        if dayDelta >= 7 && dayDelta < 28 {
            let weeks = dayDelta / 7
            return weeks == 1 ? "1 week ago" : "\(weeks) weeks ago"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
}
