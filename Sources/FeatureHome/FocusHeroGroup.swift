import SwiftUI
import UIKit
import CoreModels
import CoreUI
import FeatureHomeCore
import HeroUI

/// Several shows airing on one Upcoming day, presented by the hero together.
struct FocusHeroGroup: Equatable {
    struct Entry: Equatable {
        let item: MediaItem
        /// Compact season and episode, such as "S4 E6", when the schedule has one.
        let episode: String?
    }

    let id: String
    let day: Date
    let entries: [Entry]

    init(_ group: UpcomingDateGroup) {
        id = group.id
        day = group.day
        entries = group.releases.map { Entry(item: $0.item, episode: $0.seasonEpisodeLabel) }
    }
}

/// The group's backdrop: each show's backdrop in a slanted panel (two or three
/// shows) or a grid (four or more), drawn where a single backdrop would be so the
/// hero's fade and scrim still apply.
struct FocusHeroGroupBackdrop: View {
    let group: FocusHeroGroup
    @Environment(\.plozzArtworkPolicy) private var artworkPolicy

    private static let gridLimit = 4

    var body: some View {
        GeometryReader { geometry in
            let slant = geometry.size.width * 0.05
            Group {
                if group.entries.count < Self.gridLimit {
                    HStack(spacing: 0) {
                        ForEach(Array(group.entries.enumerated()), id: \.offset) { index, entry in
                            panel(entry.item)
                                .clipShape(SlantedPanel(
                                    slant: slant, leadingSlant: index > 0,
                                    trailingSlant: index < group.entries.count - 1
                                ))
                                .padding(.leading, index > 0 ? -slant : 0)
                        }
                    }
                } else {
                    let shown = Array(group.entries.prefix(Self.gridLimit))
                    VStack(spacing: 4) {
                        HStack(spacing: 4) { panel(shown[0].item); panel(shown[1].item) }
                        HStack(spacing: 4) { panel(shown[2].item); panel(shown[3].item) }
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .id(group.id)
        .transition(.opacity)
    }

    private func panel(_ item: MediaItem) -> some View {
        Color.clear.overlay {
            FallbackAsyncImage(
                references: HomeHeroArtwork.backdropReferences(for: item, policy: artworkPolicy),
                variant: .landscapeCard,
                asyncFallbackURL: HomeHeroArtwork.backdropFallback(for: item),
                pinIdentity: "group-hero|\(item.stablePresentationID)",
                content: { $0.resizable().aspectRatio(contentMode: .fill) },
                placeholder: { Color.white.opacity(0.08) }
            )
        }
        .clipped()
    }
}

/// A parallelogram: the leading and trailing edges lean by `slant` when set.
private struct SlantedPanel: Shape {
    let slant: CGFloat
    let leadingSlant: Bool
    let trailingSlant: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: leadingSlant ? rect.minX + slant : rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: trailingSlant ? rect.maxX - slant : rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// The hero's text column for a group: when it airs, then one block per show with its
/// logo over its episode, set apart by hairlines.
struct FocusHeroGroupColumn: View {
    let group: FocusHeroGroup
    let textScale: CGFloat
    @Environment(\.locale) private var locale
    @Environment(\.colorScheme) private var colorScheme

    private static let visibleLimit = 5
    private static let headerHeight: CGFloat = 42
    private static let headerGap: CGFloat = 22
    private static let overflowHeight: CGFloat = 44
    /// Two shows get stacked blocks (logo over episode). More get one compact row each, so five
    /// still fit between the tab bar and the row title.
    private var isCompact: Bool { group.entries.count >= 3 }
    private let logoWidth: CGFloat = 380
    private var logoHeight: CGFloat { isCompact ? 52 : 84 }
    private var rowInset: CGFloat { isCompact ? 10 : 16 }
    private let episodeLineHeight: CGFloat = 30
    private var rowHeight: CGFloat {
        (isCompact ? logoHeight : logoHeight + 8 + episodeLineHeight) + rowInset * 2 + 1
    }

    private var contentHeight: CGFloat {
        let shown = CGFloat(min(group.entries.count, Self.visibleLimit))
        let overflow = group.entries.count > Self.visibleLimit ? Self.overflowHeight : 0
        return Self.headerHeight + Self.headerGap + shown * rowHeight + overflow
    }

    /// The column is placed from its top, which suits a short block. Lift taller content so its
    /// bottom stays clear of the row title (the content's own height past what fits below the
    /// column's natural top).
    private var lift: CGFloat { max(0, contentHeight - 250) }

    private var metadataSize: CGFloat { PlozzTypography.heroMetadata.scaled(by: textScale).pointSize }

    var body: some View {
        VStack(alignment: .leading, spacing: Self.headerGap) {
            header
            VStack(alignment: .leading, spacing: 0) {
                let shown = Array(group.entries.prefix(Self.visibleLimit).enumerated())
                ForEach(shown, id: \.offset) { index, entry in
                    if index > 0 { divider }
                    block(entry)
                        .padding(.vertical, rowInset)
                }
                if group.entries.count > Self.visibleLimit {
                    divider
                    Text("+\(group.entries.count - Self.visibleLimit) more", comment: "Hero list overflow: how many more shows air that day. Number is a count and needs plural forms.")
                        .font(.system(size: metadataSize, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.top, rowInset)
                }
            }
            .frame(width: logoWidth, alignment: .leading)
        }
        .modifier(HeroTextLegibilityShadow(colorScheme: colorScheme))
        .offset(y: -lift)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(verbatim: dateLine)
                .font(.system(size: metadataSize, weight: .semibold))
            Text(verbatim: "·").foregroundStyle(.secondary)
            Text("\(group.entries.count) new episodes", comment: "Home hero caption when several shows air on the same day. Number is a count and needs plural forms.")
                .font(.system(size: metadataSize, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20).padding(.vertical, 9)
        .background(.white.opacity(0.14), in: Capsule())
    }

    private var divider: some View {
        Rectangle().fill(.white.opacity(0.22)).frame(height: 1)
    }

    @ViewBuilder
    private func block(_ entry: FocusHeroGroup.Entry) -> some View {
        if isCompact {
            HStack(spacing: 20) {
                logo(entry.item, width: 260)
                    .frame(width: 260, height: logoHeight, alignment: .leading)
                episodeText(entry)
                Spacer(minLength: 0)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                logo(entry.item, width: logoWidth)
                    .frame(width: logoWidth, height: logoHeight, alignment: .leading)
                episodeText(entry)
            }
        }
    }

    private func episodeText(_ entry: FocusHeroGroup.Entry) -> some View {
        Text(verbatim: entry.episode ?? "")
            .font(.system(size: metadataSize, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(height: episodeLineHeight, alignment: .leading)
    }

    private var dateLine: String {
        let cue = UpcomingHomeRow.airCue(for: group.day, now: Date(), locale: locale)
        let date = group.day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().locale(locale))
        return cue == date ? date : "\(cue) · \(date)"
    }

    private func logo(_ item: MediaItem, width: CGFloat) -> some View {
        HeroLogoArtwork(
            references: item.artworkReferences(for: .logo),
            asyncFallbackURL: HomeHeroArtwork.logoFallback(for: item),
            displayedArtworkID: group.id,
            maxWidth: width,
            maxHeight: logoHeight,
            constrainsToBounds: true,
            presentationPolicy: FocusHeroLayout.logoPresentationPolicy,
            haloStyle: .showcase
        ) {
            Text(verbatim: item.title)
                .font(.system(size: PlozzTypography.heroFallbackTitle.scaled(by: textScale).pointSize * 0.7, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }
}
