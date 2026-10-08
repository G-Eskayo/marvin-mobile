import SwiftUI

/// Three dots bouncing in turn, in an assistant bubble: MARVIN is replying.
/// Shown until the first words of the reply arrive, so a slow Claude Code turn
/// still feels like a conversation.
struct TypingIndicator: View {
    var body: some View {
        HStack {
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                HStack(spacing: 5) {
                    ForEach(0..<3) { i in
                        Circle()
                            .frame(width: 8, height: 8)
                            .offset(y: Self.bounce(t, delay: Double(i) * 0.15))
                            .opacity(0.5 - Self.bounce(t, delay: Double(i) * 0.15) / 12)
                    }
                }
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
            .background(.fill.secondary, in: .rect(cornerRadius: 18))
            .accessibilityLabel("MARVIN is replying")
            Spacer(minLength: 48)
        }
    }

    /// Vertical offset: a 0.3s hop up per 1.2s cycle, staggered per dot.
    private static func bounce(_ t: Double, delay: Double) -> Double {
        let phase = (t - delay).truncatingRemainder(dividingBy: 1.2)
        guard phase >= 0, phase < 0.3 else { return 0 }
        return -6 * sin(phase / 0.3 * .pi)
    }
}

#Preview {
    TypingIndicator().padding()
}
