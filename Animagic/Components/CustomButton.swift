import SwiftUI

struct CustomButton: View {
    let title: String
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0)) {
                isPressed = true
            }
            
            // Add a small delay to reverse the animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0)) {
                    isPressed = false
                }
                action()
            }
        }) {
            Text(title)
                .font(.custom("Belanosima-SemiBold", size: 30))
                .foregroundColor(.black)
                .padding(.vertical, 16)
                .padding(.horizontal, 48)
                .frame(maxWidth: 280)
                .background(Color(red: 1.0, green: 0.44, blue: 0.0)) // Orange
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.black, lineWidth: 4)
                )
        }
        .scaleEffect(isPressed ? 0.9 : 1.0)
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
