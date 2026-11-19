import CoreModels
import SwiftUI

/// Tiled artwork for one card that stands for several titles, such as every show
/// airing on the same Upcoming date. Two titles split the card, three give the
/// first the larger half, and four or more fill a grid whose last tile counts
/// the titles that do not fit.
struct UpcomingMontageArtwork: View {
    let items: [MediaItem]
    let artworkPolicy: CardArtworkPolicy

    private static let gap: CGFloat = 6

    var body: some View {
        Group {
            switch items.count {
            case ..<2:
                EmptyView()
            case 2:
                HStack(spacing: Self.gap) {
                    tile(items[0])
                    tile(items[1])
                }
            case 3:
                HStack(spacing: Self.gap) {
                    tile(items[0]).layoutPriority(1)
                    VStack(spacing: Self.gap) {
                        tile(items[1])
                        tile(items[2])
                    }
                }
            default:
                VStack(spacing: Self.gap) {
                    HStack(spacing: Self.gap) { tile(items[0]); tile(items[1]) }
                    HStack(spacing: Self.gap) {
                        tile(items[2])
                        if items.count == 4 { tile(items[3]) } else { overflowTile(items.count - 3) }
                    }
                }
            }
        }
        .background(Color.black)
        .accessibilityHidden(true)
    }

    private func tile(_ item: MediaItem) -> some View {
        Color.clear.overlay {
            FallbackAsyncImage(
                references: artworkPolicy.references(for: item, style: .landscape),
                prefersLandscape: true,
                variant: .landscapeCard,
                pinIdentity: artworkPolicy.pinIdentity(for: item),
                content: { $0.resizable().aspectRatio(contentMode: .fill) },
                placeholder: { Color.white.opacity(0.12) }
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        }
    }

    /// The count over a blurred copy of the fourth show's art.
    private func overflowTile(_ count: Int) -> some View {
        Color.clear.overlay {
            FallbackAsyncImage(
                references: artworkPolicy.references(for: items[3], style: .landscape),
                prefersLandscape: true,
                variant: .landscapeCard,
                pinIdentity: artworkPolicy.pinIdentity(for: items[3]),
                content: { $0.resizable().aspectRatio(contentMode: .fill).blur(radius: 6) },
                placeholder: { Color.white.opacity(0.14) }
            )
        }
        .overlay { Color.black.opacity(0.5) }
        .overlay {
            Text(verbatim: "+\(count)").font(.title3.bold()).foregroundStyle(.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        }
    }
}

#if canImport(UIKit)
import UIKit

/// Supplies a montage to the native tvOS poster, which takes one bitmap rather than a view.
/// Each tile resolves through the normal artwork pipeline; the bitmap is redrawn as tiles arrive.
struct MontageBitmapReader<Content: View>: View {
    let items: [MediaItem]
    let artworkPolicy: CardArtworkPolicy
    /// The card's own width over height, so the bitmap fills it without being stretched or extended.
    let aspectRatio: CGFloat
    @ViewBuilder let content: (UIImage?, String?) -> Content
    @State private var tiles: [String: UIImage] = [:]

    private static var tileCornerRadius: CGFloat { 24 }
    private var canvas: CGSize { CGSize(width: 1280, height: (1280 / max(aspectRatio, 0.1)).rounded()) }

    private var identity: String {
        "montage|" + items.map { "\($0.stablePresentationID):\(tiles[$0.stablePresentationID] == nil ? 0 : 1)" }.joined(separator: ",")
    }

    var body: some View {
        content(composite(), identity)
            .background {
                ForEach(Array(items.prefix(Self.loadedTileCount(for: items.count)).enumerated()), id: \.element.stablePresentationID) { index, item in
                    let portrait = usesPortraitArt(tile: index)
                    FallbackAsyncImage(
                        references: artworkPolicy.references(for: item, style: portrait ? .poster : .landscape),
                        prefersLandscape: !portrait,
                        variant: portrait ? .posterCard : .landscapeCard,
                        pinIdentity: artworkPolicy.pinIdentity(for: item) + (portrait ? "|montage-poster" : ""),
                        content: { _ in Color.clear },
                        placeholder: { Color.clear }
                    )
                    .resolvedBitmap { image, _ in
                        Color.clear.onChange(of: image, initial: true) { _, new in
                            if let new { tiles[item.stablePresentationID] = new }
                        }
                    }
                    .frame(width: 0, height: 0)
                }
            }
    }

    /// Four or more titles draw three tiles and a count; fewer draw one tile each.
    static func drawnTileCount(for total: Int) -> Int { total > 4 ? 3 : total }

    /// The count tile blurs the next show's art, so that show's image loads too.
    static func loadedTileCount(for total: Int) -> Int { total > 4 ? 4 : total }


    /// Where each tile goes. The overflow tile, when there is one, takes the last rect.
    private func tileRects(in size: CGSize) -> [CGRect] {
        let gap: CGFloat = 14
        let halfW = (size.width - gap) / 2, halfH = (size.height - gap) / 2
        switch items.count {
        case ..<2:
            return []
        case 2:
            return [CGRect(x: 0, y: 0, width: halfW, height: size.height),
                    CGRect(x: halfW + gap, y: 0, width: halfW, height: size.height)]
        case 3:
            let big = size.width * 0.58
            return [CGRect(x: 0, y: 0, width: big, height: size.height),
                    CGRect(x: big + gap, y: 0, width: size.width - big - gap, height: halfH),
                    CGRect(x: big + gap, y: halfH + gap, width: size.width - big - gap, height: halfH)]
        default:
            return [CGRect(x: 0, y: 0, width: halfW, height: halfH),
                    CGRect(x: halfW + gap, y: 0, width: halfW, height: halfH),
                    CGRect(x: 0, y: halfH + gap, width: halfW, height: halfH),
                    CGRect(x: halfW + gap, y: halfH + gap, width: halfW, height: halfH)]
        }
    }

    /// Tall tiles take portrait posters, which fit them without cropping people out; wide ones
    /// take landscape art.
    private func usesPortraitArt(tile index: Int) -> Bool {
        let rects = tileRects(in: canvas)
        guard index < rects.count, rects[index].height > 0 else { return false }
        return rects[index].width / rects[index].height < 1.1
    }

    private func composite() -> UIImage? {
        guard items.count > 1 else { return nil }
        let size = canvas
        let drawn = Array(items.prefix(Self.drawnTileCount(for: items.count)))
        let rects = tileRects(in: size)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            for (index, rect) in rects.enumerated() {
                context.cgContext.saveGState()
                context.cgContext.addPath(UIBezierPath(
                    roundedRect: rect, cornerRadius: Self.tileCornerRadius).cgPath)
                context.cgContext.clip()
                defer { context.cgContext.restoreGState() }
                if index < drawn.count {
                    if let image = tiles[drawn[index].stablePresentationID] {
                        context.cgContext.saveGState()
                        context.cgContext.clip(to: rect)
                        image.draw(in: Self.aspectFill(image.size, in: rect))
                        context.cgContext.restoreGState()
                    } else {
                        UIColor(white: 1, alpha: 0.12).setFill()
                        context.fill(rect, blendMode: .normal)
                    }
                } else {
                    if let image = tiles[items[3].stablePresentationID] {
                        Self.drawBlurred(image, in: rect, context: context.cgContext)
                        UIColor(white: 0, alpha: 0.5).setFill()
                        context.fill(rect, blendMode: .normal)
                    } else {
                        UIColor(white: 1, alpha: 0.16).setFill()
                        context.fill(rect, blendMode: .normal)
                    }
                    let text = "+\(items.count - 3)" as NSString
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 96, weight: .bold), .foregroundColor: UIColor.white,
                    ]
                    let textSize = text.size(withAttributes: attributes)
                    text.draw(
                        at: CGPoint(x: rect.midX - textSize.width / 2, y: rect.midY - textSize.height / 2),
                        withAttributes: attributes
                    )
                }
                // A faint rim keeps tiles distinct when their art is dark.
                let rim = UIBezierPath(
                    roundedRect: rect.insetBy(dx: 1.5, dy: 1.5), cornerRadius: Self.tileCornerRadius - 1.5)
                rim.lineWidth = 3
                UIColor(white: 1, alpha: 0.2).setStroke()
                rim.stroke()
            }
        }
    }

    /// A cheap blur: shrink the picture, then stretch it back with smooth interpolation.
    private static func drawBlurred(_ image: UIImage, in rect: CGRect, context: CGContext) {
        let small = CGSize(width: max(rect.width / 8, 1), height: max(rect.height / 8, 1))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let reduced = UIGraphicsImageRenderer(size: small, format: format).image { _ in
            image.draw(in: aspectFill(image.size, in: CGRect(origin: .zero, size: small)))
        }
        context.saveGState()
        context.interpolationQuality = .high
        reduced.draw(in: rect)
        context.restoreGState()
    }

    private static func aspectFill(_ source: CGSize, in rect: CGRect) -> CGRect {
        guard source.width > 0, source.height > 0 else { return rect }
        let scale = max(rect.width / source.width, rect.height / source.height)
        let drawSize = CGSize(width: source.width * scale, height: source.height * scale)
        // Faces sit in the upper part of the picture, so trim from the bottom first.
        let topBias: CGFloat = 0.2
        return CGRect(
            x: rect.midX - drawSize.width / 2,
            y: rect.minY - (drawSize.height - rect.height) * topBias,
            width: drawSize.width, height: drawSize.height
        )
    }
}
#endif
