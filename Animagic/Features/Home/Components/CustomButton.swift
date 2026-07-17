import SwiftUI

struct CustomButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom("Belanosima-SemiBold", size: 30, relativeTo: .title2))
                .minimumScaleFactor(0.75)
                .lineLimit(1)
                .foregroundColor(.black)
                .padding(.vertical, 16)
                .padding(.horizontal, 48)
                .frame(maxWidth: 280)
                .background(AnimagicTheme.orange)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.black, lineWidth: 4)
                )
        }
        .buttonStyle(.animagicPress)
    }
}

#Preview {
    ZStack {
        Color.yellow.edgesIgnoringSafeArea(.all)
        CustomButton(title: "Let's Draw!") {
            print("Button clicked")
        }
    }
}
