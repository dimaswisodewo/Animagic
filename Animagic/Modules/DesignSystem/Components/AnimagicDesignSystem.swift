//
//  AnimagicDesignSystem.swift
//  AniMagic
//
//  Created by MorpKnight on 21/07/26.
//

import AniMagicSupport
import SwiftUI

public enum AnimagicTheme {
    public static let yellow = Color(red: 1.0, green: 0.79, blue: 0.07)
    public static let orange = Color(red: 1.0, green: 0.44, blue: 0.0)
    public static let pink = Color(red: 1.0, green: 0.45, blue: 0.75)
    public static let blue = Color(red: 0.05, green: 0.45, blue: 0.98)
    public static let darkNavy = Color(red: 0.08, green: 0.14, blue: 0.28)
}

public enum AnimagicMotion {
    public static let press = Animation.easeOut(duration: 0.14)
    public static let selection = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.2)
    public static let sidebar = Animation.spring(response: 0.35, dampingFraction: 1, blendDuration: 0.1)
    public static let panelEntrance = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.24)
    public static let panelExit = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.18)
    public static let reduced = Animation.easeOut(duration: 0.16)
}

public struct AnimagicPressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .opacity(configuration.isPressed && reduceMotion ? 0.82 : 1)
            .animation(AnimagicMotion.press, value: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == AnimagicPressButtonStyle {
    static var animagicPress: AnimagicPressButtonStyle { AnimagicPressButtonStyle() }
}

public struct AnimagicToggleStyle: ToggleStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 16) {
                configuration.label
                    .font(.custom("Belanosima-SemiBold", size: 22, relativeTo: .headline))
                    .foregroundStyle(AnimagicTheme.darkNavy)

                Spacer(minLength: 12)

                toggleTrack(isOn: configuration.isOn)
            }
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.animagicPress)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
    }

    private func toggleTrack(isOn: Bool) -> some View {
        HStack(spacing: 6) {
            if isOn {
                Text("On")
                    .font(.custom("Belanosima-SemiBold", size: 18, relativeTo: .subheadline))
                    .foregroundStyle(.white)
                    .padding(.leading, 8)
                Spacer(minLength: 0)
            }

            Image(systemName: isOn ? "waveform" : "waveform.slash")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(isOn ? AnimagicTheme.orange : Color.Palette.n70)
                .frame(width: 34, height: 34)
                .background(Color.white, in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(Color.black.opacity(0.2), lineWidth: 2)
                }

            if !isOn {
                Spacer(minLength: 0)
                Text("Off")
                    .font(.custom("Belanosima-SemiBold", size: 18, relativeTo: .subheadline))
                    .foregroundStyle(Color.Palette.n70)
                    .padding(.trailing, 8)
            }
        }
        .padding(6)
        .frame(width: 112, height: 52)
        .background(
            Capsule()
                .fill(isOn ? AnimagicTheme.orange : Color(Color.Palette.n20))
                .overlay {
                    Capsule()
                        .strokeBorder(Color.black.opacity(0.2), lineWidth: 4)
                }
        )
        .padding(6)
        .background(Capsule().fill(Color.white))
        .animation(
            reduceMotion ? AnimagicMotion.reduced : AnimagicMotion.selection,
            value: isOn
        )
    }
}

public extension ToggleStyle where Self == AnimagicToggleStyle {
    static var animagic: AnimagicToggleStyle { AnimagicToggleStyle() }
}

public struct AnimagicIconButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let icon: String
    let backgroundColor: Color
    var iconColor: Color = .white
    var innerBorderColor: Color = .black.opacity(0.2)
    var isSelected: Bool = true
    var scalesWhenUnselected: Bool = true
    let action: () -> Void

    public init(
        icon: String,
        backgroundColor: Color,
        iconColor: Color = .white,
        innerBorderColor: Color = .black.opacity(0.2),
        isSelected: Bool = true,
        scalesWhenUnselected: Bool = true,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.backgroundColor = backgroundColor
        self.iconColor = iconColor
        self.innerBorderColor = innerBorderColor
        self.isSelected = isSelected
        self.scalesWhenUnselected = scalesWhenUnselected
        self.action = action
    }
    
    public var body: some View {
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

public struct AnimagicLabelButton: View {
    let title: String
    var icon: String? = nil
    let backgroundColor: Color
    var innerBorderColor: Color = .black.opacity(0.2)
    var isDisabled = false
    var isDimmed = false
    let action: () -> Void

    public init(
        title: String,
        icon: String? = nil,
        backgroundColor: Color,
        innerBorderColor: Color = .black.opacity(0.2),
        isDisabled: Bool = false,
        isDimmed: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.backgroundColor = backgroundColor
        self.innerBorderColor = innerBorderColor
        self.isDisabled = isDisabled
        self.isDimmed = isDimmed
        self.action = action
    }
    
    public var body: some View {
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

public struct AnimagicEmptyState: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var actionIcon: String? = nil
    var actionColor: Color = AnimagicTheme.orange
    var isCompact = false
    var action: (() -> Void)? = nil

    public init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        actionIcon: String? = nil,
        actionColor: Color = AnimagicTheme.orange,
        isCompact: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.actionIcon = actionIcon
        self.actionColor = actionColor
        self.isCompact = isCompact
        self.action = action
    }

    public var body: some View {
        VStack(spacing: isCompact ? 14 : 20) {
            Image(systemName: icon)
                .font(.system(size: isCompact ? 34 : 44, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: isCompact ? 68 : 84, height: isCompact ? 68 : 84)
                .background(AnimagicTheme.blue, in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(AnimagicTheme.darkNavy, lineWidth: 4)
                }

            VStack(spacing: 8) {
                Text(title)
                    .font(.custom(
                        "Belanosima-SemiBold",
                        size: isCompact ? 24 : 32,
                        relativeTo: isCompact ? .title3 : .title2
                    ))
                    .foregroundStyle(AnimagicTheme.darkNavy)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(message)
                    .font(.custom(
                        "Belanosima-Regular",
                        size: isCompact ? 17 : 20,
                        relativeTo: .body
                    ))
                    .foregroundStyle(Color.Token.Text.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let actionTitle, let action {
                AnimagicLabelButton(
                    title: actionTitle,
                    icon: actionIcon,
                    backgroundColor: actionColor,
                    innerBorderColor: AnimagicTheme.darkNavy.opacity(0.3),
                    action: action
                )
            }
        }
        .padding(isCompact ? 18 : 28)
        .frame(maxWidth: 460)
        .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(AnimagicTheme.darkNavy, lineWidth: 4)
        }
        .shadow(color: AnimagicTheme.darkNavy.opacity(0.14), radius: 12, y: 5)
    }
}

public enum AnimagicTextFieldIconPosition {
    case leading
    case trailing
}

public struct AnimagicTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String = "magnifyingglass"
    var iconPosition: AnimagicTextFieldIconPosition = .trailing
    var backgroundColor: Color = .white
    var innerBorderColor: Color = .black.opacity(0.2)
    var textColor: Color = .black

    public init(
        placeholder: String,
        text: Binding<String>,
        icon: String = "magnifyingglass",
        iconPosition: AnimagicTextFieldIconPosition = .trailing,
        backgroundColor: Color = .white,
        innerBorderColor: Color = .black.opacity(0.2),
        textColor: Color = .black
    ) {
        self.placeholder = placeholder
        _text = text
        self.icon = icon
        self.iconPosition = iconPosition
        self.backgroundColor = backgroundColor
        self.innerBorderColor = innerBorderColor
        self.textColor = textColor
    }
    
    public var body: some View {
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
                .autocorrectionDisabled(true)
                
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

public struct AnimagicCard<Content: View>: View {
    let title: String
    var backgroundColor: Color
    var borderColor: Color
    let content: Content
    
    public init(
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
    
    public var body: some View {
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

    public init(
        id: String,
        icon: String,
        backgroundColor: Color,
        iconColor: Color = .white,
        innerBorderColor: Color = .black.opacity(0.2),
        isSelected: Bool = true,
        action: @escaping () -> Void
    ) {
        self.id = id
        self.icon = icon
        self.backgroundColor = backgroundColor
        self.iconColor = iconColor
        self.innerBorderColor = innerBorderColor
        self.isSelected = isSelected
        self.action = action
    }
}

public struct AnimagicExpandableButtonGroup: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var isExpanded: Bool
    
    let mainIconExpanded: String
    let mainIconCollapsed: String
    let mainColor: Color
    let items: [ExpandableButtonItem]

    public init(
        isExpanded: Binding<Bool>,
        mainIconExpanded: String,
        mainIconCollapsed: String,
        mainColor: Color,
        items: [ExpandableButtonItem]
    ) {
        _isExpanded = isExpanded
        self.mainIconExpanded = mainIconExpanded
        self.mainIconCollapsed = mainIconCollapsed
        self.mainColor = mainColor
        self.items = items
    }
    
    public var body: some View {
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

public struct AnimagicSideTabButton: View {
    let icon: String
    let backgroundColor: Color
    var iconColor: Color = .white
    var innerBorderColor: Color = .white
    let action: () -> Void

    public init(
        icon: String,
        backgroundColor: Color,
        iconColor: Color = .white,
        innerBorderColor: Color = .white,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.backgroundColor = backgroundColor
        self.iconColor = iconColor
        self.innerBorderColor = innerBorderColor
        self.action = action
    }
    
    public var body: some View {
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
