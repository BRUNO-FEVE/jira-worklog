import SwiftUI

/// The Jira mark, reconstructed as vector paths in a 256×256 canonical space:
/// three cascading "waterfall" pieces, solid #2684FF on top, the two tails
/// fading from #0052CC where they tuck under the piece above.
struct JiraGlyph: View {
    var size: CGFloat = 16

    private static let brightBlue = Color(red: 38 / 255, green: 132 / 255, blue: 255 / 255)
    private static let darkBlue = Color(red: 0 / 255, green: 82 / 255, blue: 204 / 255)

    var body: some View {
        Canvas { ctx, sz in
            let scale = min(sz.width, sz.height) / 256
            // Back-to-front so the solid top-right piece overlaps the tails.
            for index in [2, 1, 0] {
                let dx = -60.871 * CGFloat(index) * scale
                let dy = 61.244 * CGFloat(index) * scale
                let path = Self.piecePath(scale: scale, dx: dx, dy: dy)
                if index == 0 {
                    ctx.fill(path, with: .color(Self.brightBlue))
                } else {
                    ctx.fill(path, with: .linearGradient(
                        Gradient(stops: [
                            .init(color: Self.darkBlue, location: 0.15),
                            .init(color: Self.brightBlue, location: 0.7),
                        ]),
                        startPoint: CGPoint(x: 225 * scale + dx, y: 35 * scale + dy),
                        endPoint: CGPoint(x: 150 * scale + dx, y: 115 * scale + dy)
                    ))
                }
            }
        }
        .frame(width: size, height: size)
    }

    /// One "waterfall" piece: top bar, quarter-pipe drop, step, second
    /// quarter-pipe, straight right edge with a rounded top-right corner.
    private static func piecePath(scale: CGFloat, dx: CGFloat, dy: CGFloat) -> Path {
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x * scale + dx, y: y * scale + dy)
        }
        // Cubic control offset for a circular quarter arc: r * 0.5523
        let k: CGFloat = 55.5 * 0.5523
        let kc: CGFloat = 11.666 * 0.5523

        var p = Path()
        p.move(to: pt(243.658, 0))
        p.addLine(to: pt(121.707, 0))
        // Quarter-pipe: vertical drop curving out to horizontal (center 177.2, 0)
        p.addCurve(to: pt(177.209, 55.502), control1: pt(121.707, k), control2: pt(177.209 - k, 55.502))
        p.addLine(to: pt(199.858, 55.502))
        p.addLine(to: pt(199.858, 77.370))
        // Second quarter-pipe (center 255.3, 77.4)
        p.addCurve(to: pt(255.324, 132.837), control1: pt(199.858, 77.370 + k), control2: pt(255.324 - k, 132.837))
        p.addLine(to: pt(255.324, 11.666))
        // Rounded top-right corner
        p.addCurve(to: pt(243.658, 0), control1: pt(255.324, 11.666 - kc), control2: pt(243.658 + kc, 0))
        p.closeSubpath()
        return p
    }
}
