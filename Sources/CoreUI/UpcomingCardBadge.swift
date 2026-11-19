#if canImport(SwiftUI)
import SwiftUI

/// What an Upcoming card draws over its artwork: the air date as a weekday over a day number,
/// plus an optional chip naming the kind of release.
public struct UpcomingCardBadge {
    public let weekday: Text
    public let day: Text
    public let chip: Text?

    public init(weekday: Text, day: Text, chip: Text? = nil) {
        self.weekday = weekday
        self.day = day
        self.chip = chip
    }
}

/// Weekday-over-day tile for the top corner of an Upcoming card.
struct UpcomingDateBadgeView: View {
    let badge: UpcomingCardBadge
    let weekdaySize: CGFloat
    let daySize: CGFloat

    var body: some View {
        VStack(spacing: 2) {
            badge.weekday
                .font(.system(size: weekdaySize, weight: .bold))
                .textCase(.uppercase)
                .foregroundStyle(Color.orange)
            badge.day
                .font(.system(size: daySize, weight: .bold))
                .foregroundStyle(.white)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.horizontal, weekdaySize * 0.9)
        .padding(.vertical, weekdaySize * 0.55)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: weekdaySize, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
#endif
