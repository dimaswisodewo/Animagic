//
//  AnimagicDesignSystem.swift
//  AniMagic
//
//  Created by MorpKnight on 21/07/26.
//

import SwiftUI

enum AnimagicTheme {
    static let yellow = Color(red: 1.0, green: 0.79, blue: 0.07)
    static let orange = Color(red: 1.0, green: 0.44, blue: 0.0)
    static let pink = Color(red: 1.0, green: 0.45, blue: 0.75)
    static let blue = Color(red: 0.05, green: 0.45, blue: 0.98)
    static let darkNavy = Color(red: 0.08, green: 0.14, blue: 0.28)
}

enum AnimagicMotion {
    static let press = Animation.easeOut(duration: 0.14)
    static let selection = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.2)
    static let panelEntrance = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.24)
    static let panelExit = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.18)
    static let reduced = Animation.easeOut(duration: 0.16)
}

struct AnimagicPressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .opacity(configuration.isPressed && reduceMotion ? 0.82 : 1)
            .animation(AnimagicMotion.press, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == AnimagicPressButtonStyle {
    static var animagicPress: AnimagicPressButtonStyle { AnimagicPressButtonStyle() }
}

struct AnimagicIconButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let icon: String
    let backgroundColor: Color
    var iconColor: Color = .white
    var innerBorderColor: Color = .black.opacity(0.2)
    var isSelected: Bool = true
    var scalesWhenUnselected: Bool = true
    let action: () -> Void
    
    var body: some View {
        Button {
            AudioManager.shared.playTap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(iconColor)
                .frame(width: 32, height: 32)
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
        .scaleEffect(isSelected || reduceMotion || !scalesWhenUnselected ? 1 : 0.96)
        .opacity(isSelected ? 1 : 0.72)
        .animation(
            reduceMotion ? AnimagicMotion.reduced : AnimagicMotion.selection,
            value: isSelected
        )
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
        Button {
            AudioManager.shared.playTap()
            action()
        } label: {
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
            
            TextField(
                placeholder,
                text: $text,
                prompt: Text(placeholder)
                    .foregroundColor(textColor.opacity(0.75))
            )
                .font(.custom("Belanosima-Regular", size: 30))
                .foregroundColor(textColor)
                
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

public struct ExpandableButtonItem: Identifiable {
    public let id: String
    let icon: String
    let backgroundColor: Color
    var iconColor: Color = .white
    var innerBorderColor: Color = .black.opacity(0.2)
    var isSelected: Bool = true
    let action: () -> Void
}

struct AnimagicExpandableButtonGroup: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var isExpanded: Bool
    
    let mainIconExpanded: String
    let mainIconCollapsed: String
    let mainColor: Color
    let items: [ExpandableButtonItem]
    
    var body: some View {
        HStack(spacing: 0) {
            if isExpanded {
                HStack(spacing: 8) {
                    ForEach(items) { item in
                        AnimagicIconButton(
                            icon: item.icon,
                            backgroundColor: item.backgroundColor,
                            iconColor: item.iconColor,
                            innerBorderColor: item.innerBorderColor,
                            isSelected: item.isSelected,
                            action: item.action
                        )
                    }
                }
                .padding(.leading, 8)
                .padding(.trailing, 8)
                .transition(expandedContentTransition)
            }
            
            AnimagicIconButton(
                icon: isExpanded ? mainIconExpanded : mainIconCollapsed,
                backgroundColor: mainColor,
                action: {
                    withAnimation(
                        reduceMotion
                            ? AnimagicMotion.reduced
                            : (isExpanded ? AnimagicMotion.panelExit : AnimagicMotion.panelEntrance)
                    ) {
                        isExpanded.toggle()
                    }
                }
            )
        }
        .background(
            Capsule()
                .fill(Color.white.opacity(isExpanded ? 0.9 : 0))
                .shadow(color: isExpanded ? .black.opacity(0.1) : .clear, radius: 5)
        )
    }

    private var expandedContentTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .scale(scale: 0.96, anchor: .trailing).combined(with: .opacity)
    }
}

struct AnimagicSideTabButton: View {
    let icon: String
    let backgroundColor: Color
    var iconColor: Color = .white
    var innerBorderColor: Color = .white
    let action: () -> Void
    
    var body: some View {
        Button {
            AudioManager.shared.playTap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(iconColor)
                .padding(.vertical, 24)
                .padding(.horizontal, 20)
                .background(
                    UnevenRoundedRectangle(topLeadingRadius: 32, bottomLeadingRadius: 32, bottomTrailingRadius: 0, topTrailingRadius: 0)
                        .fill(backgroundColor)
                        .overlay(
                            UnevenRoundedRectangle(topLeadingRadius: 32, bottomLeadingRadius: 32, bottomTrailingRadius: 0, topTrailingRadius: 0)
                                .strokeBorder(innerBorderColor, lineWidth: 4)
                        )
                )
                .padding(.trailing, -4) // Slight overlap to ensure it sits flush against the edge even with borders
        }
        .buttonStyle(.animagicPress)
    }
}
