import SwiftUI

struct ARPageView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            // Camera View
            ARViewContainer()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Bar
                HStack(spacing: 16) {
                    TopBarIconButton(icon: "chevron.left") {
                        dismiss()
                    }
                    
                    Spacer()
                    
                    // Stats / Paw count
                    HStack {
                        Text("1")
                        Image(systemName: "pawprint.fill")
                    }
                    .font(.custom("Belanosima-SemiBold", size: 20))
                    .foregroundColor(.black)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 30)
                    .frame(maxWidth: 100)
                    .background(Color(red: 1.0, green: 0.44, blue: 0.0)) // Orange
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.black, lineWidth: 3)
                    )
                    
                    // Capture
                    AnimatedARButton(action: { print("Capture") }) {
                        HStack {
                            Text("Capture")
                            Image(systemName: "camera.viewfinder")
                                .font(.custom("Belanosima-Bold", size: 20))
                        }
                        .font(.custom("Belanosima-SemiBold", size: 20))
                        .foregroundColor(.black)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 30)
                        .frame(maxWidth: 180)
                        .background(Color(red: 1.0, green: 0.44, blue: 0.0)) // Orange
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.black, lineWidth: 3)
                        )
                    }
                    
                    // Motion/Stars
                    AnimatedARButton(action: { print("Motion") }) {
                        HStack {
                            Image(systemName: "figure.walk.motion")
                            Image(systemName: "sparkles")
                        }
                        .font(.custom("Belanosima-Bold", size: 20))
                        .foregroundColor(.black)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 30)
                        .frame(maxWidth: 100)
                        .background(Color(red: 1.0, green: 0.44, blue: 0.0)) // Orange
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.black, lineWidth: 3)
                        )
                    }
                    
                    // Share
                    TopBarIconButton(icon: "square.and.arrow.up") {
                        print("Share")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Color(red: 1.0, green: 0.79, blue: 0.07)) // Yellow #FFC812
                
                Spacer()
                
                // Bottom Bar
                HStack {
                    // My Backpack
                    AnimatedARButton(action: { print("Open Backpack") }) {
                        HStack {
                            Text("My Backpack")
                                .font(.custom("Belanosima-SemiBold", size: 20))
                                .foregroundColor(.black)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 30)
                                .frame(maxWidth: 200)
                                .background(Color(red: 1.0, green: 0.44, blue: 0.0)) // Orange
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.black, lineWidth: 3)
                                )}
                    }
                    
                    Spacer()
                    
                    // Draw More
                    AnimatedARButton(action: {
                        // Navigate to Canvas (pushing onto the stack)
                        appState.navigationPath.append(NavigationRoute.canvas)
                    }) {
                        Text("Draw More!")
                            .font(.custom("Belanosima-SemiBold", size: 20))
                            .foregroundColor(.black)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 30)
                            .frame(maxWidth: 180)
                            .background(Color(red: 1.0, green: 0.44, blue: 0.0)) // Orange
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.black, lineWidth: 3)
                            )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Color(red: 1.0, green: 0.79, blue: 0.07)) // Yellow #FFC812
            }
        }
        .navigationBarHidden(true)
    }
}

struct AnimatedARButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label
    
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
            label()
        }
        .scaleEffect(isPressed ? 0.9 : 1.0)
    }
}

#Preview {
    ARPageView()
        .environmentObject(AppState())
        .previewDevice("iPad Pro (11-inch) (4th generation)")
}
