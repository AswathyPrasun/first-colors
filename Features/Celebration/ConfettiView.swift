import SwiftUI

/// Falling confetti in the kid palette. With Reduce Motion it is a still scatter instead.
/// Stops after a few seconds so it doesn't run (and use battery) forever.
struct ConfettiView: View {
    var pieceCount = 70
    var duration: TimeInterval = 5

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    private struct Piece {
        let x: CGFloat          // 0…1
        let delay: Double
        let speed: CGFloat      // screen heights per second
        let drift: CGFloat
        let spin: Double
        let size: CGSize
        let color: Color
        let isCircle: Bool
    }

    private let pieces: [Piece] = {
        var rng = SeededGenerator(seed: 42)
        return (0..<70).map { index in
            Piece(x: .random(in: 0...1, using: &rng),
                  delay: .random(in: 0...1.2, using: &rng),
                  speed: .random(in: 0.22...0.42, using: &rng),
                  drift: .random(in: -30...30, using: &rng),
                  spin: .random(in: -4...4, using: &rng),
                  size: CGSize(width: .random(in: 8...14, using: &rng), height: .random(in: 12...20, using: &rng)),
                  color: KidPalette.colors[index % KidPalette.colors.count].color,
                  isCircle: index % 4 == 0)
        }
    }()

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let elapsed = reduceMotion ? 0 : timeline.date.timeIntervalSince(start)
            Canvas { context, size in
                for piece in pieces.prefix(pieceCount) {
                    let t = elapsed - piece.delay
                    let y: CGFloat
                    let opacity: Double
                    if reduceMotion {
                        // Still scatter across the top half.
                        y = size.height * 0.5 * CGFloat(piece.delay / 1.2)
                        opacity = 0.9
                    } else {
                        guard t > 0 else { continue }
                        y = -20 + CGFloat(t) * piece.speed * size.height
                        opacity = max(0, min(1, (duration - elapsed) / 1.0))
                        if y > size.height + 20 { continue }
                    }
                    let x = piece.x * size.width + piece.drift * CGFloat(sin(max(t, 0) * 2))
                    var ctx = context
                    ctx.opacity = opacity
                    ctx.translateBy(x: x, y: y)
                    ctx.rotate(by: .radians(reduceMotion ? piece.spin : piece.spin * max(t, 0)))
                    let rect = CGRect(x: -piece.size.width / 2, y: -piece.size.height / 2,
                                      width: piece.size.width, height: piece.size.height)
                    let shape = piece.isCircle ? Path(ellipseIn: rect.insetBy(dx: 0, dy: 3))
                                               : Path(roundedRect: rect, cornerRadius: 3)
                    ctx.fill(shape, with: .color(piece.color))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { start = Date() }
    }
}

/// Small deterministic RNG so confetti looks the same every time (and in tests/screenshots).
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
