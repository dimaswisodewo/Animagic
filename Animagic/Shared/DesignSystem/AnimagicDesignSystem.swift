import SwiftUI

enum AnimagicTheme {
    static let yellow = Color(red: 1.0, green: 0.79, blue: 0.07)
    static let orange = Color(red: 1.0, green: 0.44, blue: 0.0)
    static let pink = Color(red: 1.0, green: 0.45, blue: 0.75)
    static let blue = Color(red: 0.05, green: 0.45, blue: 0.98)
    static let darkNavy = Color(red: 0.08, green: 0.14, blue: 0.28)
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

struct AnimagicIconButton: View {
    let icon: String
    let backgroundColor: Color
    var innerBorderColor: Color = .black.opacity(0.2)
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
                .padding(18)
                .background(
                    Circle()
                        .fill(backgroundColor)
                        .overlay(
                            Circle()
                                .strokeBorder(innerBorderColor, lineWidth: 4)
                        )
                )
                .padding(8)
                .background(
                    Circle()
                        .fill(Color.white)
                )
        }
        .buttonStyle(.animagicPress)
    }
}

struct AnimagicLabelButton: View {
    let title: String
    var icon: String? = nil
    let backgroundColor: Color
    var innerBorderColor: Color = .black.opacity(0.2)
    var isDisabled = false
    var isDimmed = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.custom("Belanosima-SemiBold", size: 32))
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 32, weight: .bold))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(backgroundColor)
                    .overlay(
                        Capsule()
                            .strokeBorder(innerBorderColor, lineWidth: 4)
                    )
            )
            .padding(8)
            .background(
                Capsule()
                    .fill(Color.white)
            )
        }
        .buttonStyle(.animagicPress)
        .opacity(isDimmed ? 0.55 : 1)
        .disabled(isDisabled)
    }
}

enum AnimagicTextFieldIconPosition {
    case leading
    case trailing
}

struct AnimagicTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String = "magnifyingglass"
    var iconPosition: AnimagicTextFieldIconPosition = .trailing
    var backgroundColor: Color = .white
    var innerBorderColor: Color = .black.opacity(0.2)
    var textColor: Color = .black
    
    var body: some View {
        HStack(spacing: 8) {
            if iconPosition == .leading {
                Image(systemName: icon)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(textColor.opacity(0.65))
            }
            
            TextField(placeholder, text: $text)
                .font(.custom("Belanosima-Regular", size: 30))
                .foregroundStyle(textColor)
                
            if iconPosition == .trailing {
                Image(systemName: icon)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(textColor)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(
            Capsule()
                .fill(backgroundColor)
                .overlay(
                    Capsule()
                        .strokeBorder(innerBorderColor, lineWidth: 4)
                )
        )
        .padding(8)
        .background(
            Capsule()
                .fill(Color.white)
        )
    }
}

struct AnimagicCard<Content: View>: View {
    let title: String
    var backgroundColor: Color
    var borderColor: Color
    let content: Content
    
    init(
        title: String,
        backgroundColor: Color = Color(red: 0.97, green: 0.98, blue: 0.99), // Very slight off-white
        borderColor: Color = AnimagicTheme.darkNavy,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(backgroundColor)
                
                content
                    .padding(24)
                
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(borderColor, lineWidth: 6)
            }
            .aspectRatio(1, contentMode: .fit) // Ensures the card is square
            
            Text(title)
                .font(.custom("Belanosima-SemiBold", size: 28))
                .minimumScaleFactor(0.75)
                .lineLimit(1)
                .foregroundColor(borderColor)
        }
    }
}
