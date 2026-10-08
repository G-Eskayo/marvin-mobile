import MarvinCore
import SwiftUI

/// The desktop dashboard's look (MARVIN Metrics: Tailwind neutral palette on #0f1117),
/// so phone and desktop read as one product. Colors are the desktop's Tailwind values.
enum Theme {
    static let background = Color(hex: 0x0F1117)
    static let card = Color(hex: 0x171717)         // neutral-900
    static let raised = Color(hex: 0x262626)       // neutral-800
    static let border = Color(hex: 0x262626)       // neutral-800
    static let text = Color.white
    static let secondary = Color(hex: 0xA3A3A3)    // neutral-400
    static let muted = Color(hex: 0x737373)        // neutral-500
    static let accent = Color(hex: 0xFCD34D)       // amber-300, the desktop's highlight numbers
    static let selected = Color(hex: 0x2563EB)     // blue-600, the desktop's selected chip

    static func color(_ severity: Severity) -> Color {
        switch severity {
        case .red: Color(hex: 0xEF4444)            // red-500
        case .yellow: Color(hex: 0xF59E0B)         // amber-500
        case .green: Color(hex: 0x10B981)          // emerald-500
        case .grey: Color(hex: 0x525252)           // neutral-600
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

/// Small uppercase label, like the desktop's "CALLS" / "FAILED" captions.
struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.medium))
            .tracking(0.8)
            .foregroundStyle(Theme.secondary)
    }
}

/// A bordered dark card.
struct Card<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Theme.card, in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
    }
}

/// Label over a big number over a caption: the desktop's stat tiles.
struct StatCard: View {
    let label: String
    let value: String
    var caption: String?
    var valueColor: Color = Theme.text

    var body: some View {
        Card {
            SectionLabel(label)
            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(valueColor)
            if let caption {
                Text(caption).font(.caption).foregroundStyle(Theme.muted)
            }
        }
    }
}

struct StatusDot: View {
    let severity: Severity
    var size: CGFloat = 8

    var body: some View {
        Circle().fill(Theme.color(severity)).frame(width: size, height: size)
    }
}

/// The dark page every tab sits on, with the desktop-style header and the settings gear.
struct Page<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ConnectionBanner()
                content.frame(maxHeight: .infinity)
            }
            .background(Theme.background)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title.uppercased())
                        .font(.subheadline.weight(.semibold))
                        .tracking(1.2)
                        .foregroundStyle(Theme.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: { Image(systemName: "gearshape") }
                        .tint(Theme.secondary)
                        .accessibilityLabel("Settings")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .sheet(isPresented: $showingSettings) { SettingsView() }
        }
    }
}
