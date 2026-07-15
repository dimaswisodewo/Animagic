import SwiftUI

enum AnimagicTheme {
    static let yellow = Color(red: 1.0, green: 0.79, blue: 0.07)
    static let orange = Color(red: 1.0, green: 0.44, blue: 0.0)
    static let pink = Color(red: 1.0, green: 0.45, blue: 0.75)
    static let blue = Color(red: 0.05, green: 0.45, blue: 0.98)
}

struct AnimagicPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(
                .spring(response: 0.3, dampingFraction: 0.5),
                value: configuration.isPressed
            )
    }
}

extension ButtonStyle where Self == AnimagicPressButtonStyle {
    static var animagicPress: AnimagicPressButtonStyle { AnimagicPressButtonStyle() }
}
