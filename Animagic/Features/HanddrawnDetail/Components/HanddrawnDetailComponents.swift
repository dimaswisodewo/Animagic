import PencilKit
import SwiftUI

struct HanddrawnDetailHeader: View {
    let title: String
    let onBack: () -> Void
    let onOpenAR: () -> Void
    let onShare: () -> Void
    let onSave: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            TopBarIconButton(icon: "chevron.left", action: onBack)
            Text(title)
                .font(.custom("Belanosima-Bold", size: 28))
                .foregroundStyle(.black)
            Spacer()
            DetailActionButton(
                icons: ["camera", "sparkles"],
                shape: .capsule,
                action: onOpenAR
            )
            DetailActionButton(icon: "square.and.arrow.up", action: onShare)
            DetailActionButton(icon: "arrow.down.to.line", action: onSave)
            DetailActionButton(
                icon: "trash",
                backgroundColor: AnimagicTheme.pink,
                action: onDelete
            )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(AnimagicTheme.yellow)
    }
}

struct HanddrawnArtworkView: View {
    let drawing: PKDrawing

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            if drawing.bounds.isEmpty {
                Text("Empty Drawing")
                    .font(.custom("Belanosima-Regular", size: 24))
                    .foregroundStyle(.gray)
            } else {
                Image(uiImage: drawing.image(from: drawing.bounds, scale: 1))
                    .resizable()
                    .scaledToFit()
                    .padding(40)
            }
        }
    }
}

private struct DetailActionButton: View {
    enum Shape: Equatable {
        case circle
        case capsule
    }

    let icons: [String]
    var shape: Shape = .circle
    var backgroundColor = AnimagicTheme.orange
    let action: () -> Void

    init(
        icon: String,
        backgroundColor: Color = AnimagicTheme.orange,
        action: @escaping () -> Void
    ) {
        icons = [icon]
        self.backgroundColor = backgroundColor
        self.action = action
    }

    init(
        icons: [String],
        shape: Shape,
        backgroundColor: Color = AnimagicTheme.orange,
        action: @escaping () -> Void
    ) {
        self.icons = icons
        self.shape = shape
        self.backgroundColor = backgroundColor
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                ForEach(icons, id: \.self) { icon in
                    Image(systemName: icon)
                }
            }
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(.black)
            .frame(width: shape == .circle ? 50 : nil, height: 50)
            .padding(.horizontal, shape == .capsule ? 16 : 0)
            .background(backgroundColor)
            .clipShape(shape == .circle ? AnyShape(Circle()) : AnyShape(Capsule()))
            .overlay {
                if shape == .circle {
                    Circle().stroke(.black, lineWidth: 3)
                } else {
                    Capsule().stroke(.black, lineWidth: 3)
                }
            }
        }
        .buttonStyle(.animagicPress)
    }
}
