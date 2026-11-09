import SwiftUI

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

struct Theme {
    let kind: ThemeKind
    var classic: Bool { kind == .classic }

    let face: Color
    let faceText: Color
    let hi: Color
    let light: Color
    let shadow: Color
    let dark: Color
    let listBg: Color
    let listText: Color
    let secondaryText: Color
    let cursorBg: Color
    let cursorText: Color
    let inactiveCursor: Color
    let markedText: Color
    let cursorMarkedText: Color
    let captionStart: Color
    let captionEnd: Color
    let captionText: Color
    let pathActiveBg: Color
    let pathActiveText: Color
    let pathInactiveBg: Color
    let pathInactiveText: Color
    let folder: Color
    let accent: Color
    let accent2: Color
    let headerBg: Color
    let radius: CGFloat
    let rowHeight: CGFloat
    let fontSize: CGFloat
    let fontDesign: Font.Design
    /// Faktor aus der Einstellung Schriftgroesse (Klein / Normal / Gross).
    var scale: CGFloat = 1

    func font(_ size: CGFloat? = nil, weight: Font.Weight = .regular) -> Font {
        .system(size: size.map { $0 * scale } ?? fontSize, weight: weight, design: fontDesign)
    }

    var captionGradient: LinearGradient {
        LinearGradient(colors: [captionStart, captionEnd], startPoint: .leading, endPoint: .trailing)
    }

    static func make(_ k: ThemeKind, scale s: CGFloat = 1) -> Theme {
        switch k {
        case .classic:
            return Theme(kind: k,
                         face: Color(hex: 0xC0C0C0), faceText: .black,
                         hi: .white, light: Color(hex: 0xDFDFDF), shadow: Color(hex: 0x808080), dark: .black,
                         listBg: .white, listText: .black, secondaryText: Color(hex: 0x404040),
                         cursorBg: Color(hex: 0x000080), cursorText: .white, inactiveCursor: Color(hex: 0x000080),
                         markedText: Color(hex: 0xFF0000), cursorMarkedText: Color(hex: 0xFFFF00),
                         captionStart: Color(hex: 0x000080), captionEnd: Color(hex: 0x1084D0), captionText: .white,
                         pathActiveBg: Color(hex: 0x000080), pathActiveText: .white,
                         pathInactiveBg: Color(hex: 0x808080), pathInactiveText: Color(hex: 0xDFDFDF),
                         folder: Color(hex: 0xE8B923), accent: Color(hex: 0x000080), accent2: Color(hex: 0x1084D0),
                         headerBg: Color(hex: 0xC0C0C0),
                         radius: 0, rowHeight: (30 * s).rounded(), fontSize: 15 * s, fontDesign: .default, scale: s)
        case .nacht:
            return Theme(kind: k,
                         face: Color(hex: 0x0B0E14), faceText: Color(hex: 0xE6E9F2),
                         hi: Color.white.opacity(0.10), light: Color.white.opacity(0.05), shadow: Color.black.opacity(0.5), dark: .black,
                         listBg: Color(hex: 0x121722), listText: Color(hex: 0xE6E9F2), secondaryText: Color(hex: 0x8A93A6),
                         cursorBg: Color(hex: 0x8B7BFF, alpha: 0.32), cursorText: .white, inactiveCursor: Color(hex: 0x8B7BFF, alpha: 0.55),
                         markedText: Color(hex: 0xFFB84D), cursorMarkedText: Color(hex: 0xFFD27A),
                         captionStart: Color(hex: 0x8B7BFF), captionEnd: Color(hex: 0x4CC9F0), captionText: .white,
                         pathActiveBg: Color(hex: 0x8B7BFF, alpha: 0.22), pathActiveText: .white,
                         pathInactiveBg: Color.white.opacity(0.04), pathInactiveText: Color(hex: 0x8A93A6),
                         folder: Color(hex: 0x4CC9F0), accent: Color(hex: 0x8B7BFF), accent2: Color(hex: 0x4CC9F0),
                         headerBg: Color.white.opacity(0.03),
                         radius: 16, rowHeight: (34 * s).rounded(), fontSize: 15 * s, fontDesign: .rounded, scale: s)
        }
    }
}

enum BevelStyle { case raised, sunken, field }

/// Der typische 3D-Rand der alten Windows-Oberflaeche.
struct BevelLines: View {
    let theme: Theme
    let style: BevelStyle

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            func line(_ pts: [CGPoint], _ c: Color) {
                var p = Path()
                p.addLines(pts)
                ctx.stroke(p, with: .color(c), lineWidth: 1)
            }
            let tlOuter: Color, tlInner: Color, brOuter: Color, brInner: Color
            switch style {
            case .raised:
                tlOuter = theme.hi; tlInner = theme.light; brOuter = theme.dark; brInner = theme.shadow
            case .sunken, .field:
                tlOuter = theme.shadow; tlInner = theme.dark; brOuter = theme.hi; brInner = theme.light
            }
            line([CGPoint(x: 0.5, y: h - 0.5), CGPoint(x: 0.5, y: 0.5), CGPoint(x: w - 0.5, y: 0.5)], tlOuter)
            line([CGPoint(x: 0.5, y: h - 0.5), CGPoint(x: w - 0.5, y: h - 0.5), CGPoint(x: w - 0.5, y: 0.5)], brOuter)
            line([CGPoint(x: 1.5, y: h - 1.5), CGPoint(x: 1.5, y: 1.5), CGPoint(x: w - 1.5, y: 1.5)], tlInner)
            line([CGPoint(x: 1.5, y: h - 1.5), CGPoint(x: w - 1.5, y: h - 1.5), CGPoint(x: w - 1.5, y: 1.5)], brInner)
        }
        .allowsHitTesting(false)
    }
}

struct BevelModifier: ViewModifier {
    let theme: Theme
    let style: BevelStyle
    var radius: CGFloat? = nil

    @ViewBuilder
    func body(content: Content) -> some View {
        if theme.classic {
            content.overlay(BevelLines(theme: theme, style: style))
        } else {
            let r = radius ?? (style == .raised ? theme.radius : max(theme.radius - 6, 8))
            content
                .clipShape(RoundedRectangle(cornerRadius: r, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: r, style: .continuous)
                        .strokeBorder(Color.white.opacity(style == .raised ? 0.10 : 0.06), lineWidth: 1)
                        .allowsHitTesting(false)
                )
        }
    }
}

extension View {
    func bevel(_ theme: Theme, _ style: BevelStyle = .raised, radius: CGFloat? = nil) -> some View {
        modifier(BevelModifier(theme: theme, style: style, radius: radius))
    }
}

/// Knopf im Stil des jeweiligen Designs.
struct PanelButtonStyle: ButtonStyle {
    let theme: Theme
    var prominent = false
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .font(theme.font(compact ? 13 : nil, weight: prominent && !theme.classic ? .semibold : .regular))
            .foregroundStyle(theme.classic ? theme.faceText : (prominent ? Color.white : theme.faceText))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, compact ? 6 : 12)
            .padding(.vertical, compact ? 3 : 6)
            .frame(minHeight: compact ? 30 : 34)
            .background(background(pressed))
            .bevel(theme, pressed ? .sunken : .raised, radius: theme.classic ? nil : 10)
            .offset(x: theme.classic && pressed ? 1 : 0, y: theme.classic && pressed ? 1 : 0)
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private func background(_ pressed: Bool) -> some View {
        if theme.classic {
            theme.face
        } else if prominent {
            LinearGradient(colors: [theme.accent, theme.accent2], startPoint: .topLeading, endPoint: .bottomTrailing)
                .opacity(pressed ? 0.7 : 1)
        } else {
            Color.white.opacity(pressed ? 0.14 : 0.06)
        }
    }
}
