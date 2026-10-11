import SwiftUI

enum AppColors {
    static let paper = Color(hex: 0xfaf7ee)
    static let ink = Color(hex: 0x353f35)
    static let muted = Color(hex: 0x737869)
    static let line = Color(hex: 0xd3d5c5)
    static let sage = Color(hex: 0xdce4c8)
    static let coral = Color(hex: 0xedaa92)
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}

enum AppFonts {
    static func pixel(_ size: CGFloat) -> Font { .system(size: size, weight: .regular, design: .monospaced) }
}

struct PixelButtonStyle: ButtonStyle {
    var fill: Color = AppColors.paper
    var shadow: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFonts.pixel(14))
            .foregroundStyle(AppColors.ink)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(fill)
            .overlay(Rectangle().strokeBorder(AppColors.ink, lineWidth: 2))
            .background(AppColors.ink.offset(y: shadow && !configuration.isPressed ? 3 : 0))
            .offset(y: configuration.isPressed ? 2 : 0)
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 10, design: .monospaced))
            .tracking(2).foregroundStyle(AppColors.muted)
    }
}

struct GamePanel<Content: View>: View {
    var fill: Color = AppColors.paper
    var padding: CGFloat = 20
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(padding).frame(maxWidth: .infinity, alignment: .leading)
            .background(fill).overlay(Rectangle().strokeBorder(AppColors.line))
    }
}

struct Reticle: View {
    var body: some View {
        ZStack {
            VStack { Rectangle().frame(width: 2, height: 10); Spacer(); Rectangle().frame(width: 2, height: 10) }
            HStack { Rectangle().frame(width: 10, height: 2); Spacer(); Rectangle().frame(width: 10, height: 2) }
        }.frame(width: 32, height: 32).accessibilityHidden(true)
    }
}

struct PixelSpark: Shape {
    func path(in rect: CGRect) -> Path {
        let points: [(CGFloat, CGFloat)] = [(0.4,0),(0.6,0),(0.6,0.2),(0.8,0.2),(0.8,0.4),(1,0.4),(1,0.6),(0.8,0.6),(0.8,0.8),(0.6,0.8),(0.6,1),(0.4,1),(0.4,0.8),(0.2,0.8),(0.2,0.6),(0,0.6),(0,0.4),(0.2,0.4),(0.2,0.2),(0.4,0.2)]
        return Path { path in
            path.addLines(points.map { CGPoint(x: $0.0 * rect.width, y: $0.1 * rect.height) })
            path.closeSubpath()
        }
    }
}
