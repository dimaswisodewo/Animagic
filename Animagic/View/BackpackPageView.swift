import SwiftUI
import PencilKit

struct BackpackPageView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    // Tab selection state
    @State private var selectedTab = "All"
    let tabs = ["All", "Skies", "Underwater", "Land"]
    
    // Scroll tracking state
    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    
    // Search state
    @State private var searchText = ""
    
    var filteredDrawings: [SavedDrawing] {
        var filtered = appState.savedDrawings
        
        if !searchText.isEmpty {
            filtered = filtered.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }
        
        // Example: if you add categories to drawings later:
        // if selectedTab != "All" {
        //     filtered = filtered.filter { $0.category == selectedTab }
        // }
        
        return filtered
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            HStack(spacing: 16) {
                // Back Button & Title
                HStack(spacing: 12) {
                    TopBarIconButton(icon: "chevron.left") {
                        dismiss()
                    }
                    Text("My Backpack")
                        .font(.custom("Belanosima-SemiBold", size: 32))
                        .foregroundColor(.black)
                }
                
                Spacer()
                
                // Draw More Button
                TopBarButton(title: "Draw More!") {
                    appState.navigationPath.append(NavigationRoute.canvas)
                }
                
                // AR View Button
                BackpackARButton {
                    appState.navigationPath.append(NavigationRoute.arView)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 16)
            
            // Tabs
            HStack(spacing: 16) {
                ForEach(tabs, id: \.self) { tab in
                    BackpackTabButton(
                        title: tab,
                        isSelected: selectedTab == tab
                    ) {
                        selectedTab = tab
                    }
                }
                Spacer()
                
                // Search Bar
                HStack {
                    TextField("Search.....", text: $searchText)
                        .font(.custom("Belanosima-Regular", size: 18))
                        .foregroundColor(.black)
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.black)
                        .font(.system(size: 20, weight: .bold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white)
                .clipShape(Capsule())
                .overlay(
                            Capsule()
                                .stroke(Color.black, lineWidth: 3)
                        )
                .frame(width: 300)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            
            // Grid of drawings
            ZStack(alignment: .trailing) {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                        // Display saved drawings
                        ForEach(filteredDrawings) { savedDrawing in
                            Button(action: {
                                appState.navigationPath.append(NavigationRoute.handdrawnDetail(savedDrawing))
                            }) {
                                VStack(spacing: 0) {
                                    if !savedDrawing.drawing.bounds.isEmpty {
                                        Image(uiImage: savedDrawing.drawing.image(from: savedDrawing.drawing.bounds, scale: 1.0))
                                            .resizable()
                                            .scaledToFit()
                                            .padding(16)
                                    } else {
                                        Spacer()
                                        Text("Empty Drawing")
                                            .font(.custom("Belanosima-Regular", size: 16))
                                            .foregroundColor(.gray)
                                        Spacer()
                                    }
                                    
                                    Text(savedDrawing.name.isEmpty ? "Untitled" : savedDrawing.name)
                                        .font(.custom("Belanosima-Bold", size: 20))
                                        .foregroundColor(.black)
                                        .padding(.bottom, 12)
                                }
                                .frame(height: 200)
                                .frame(maxWidth: .infinity)
                                .background(Color.white)
                                .cornerRadius(16)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black, lineWidth: 3))
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .background(GeometryReader { geo -> Color in
                        DispatchQueue.main.async {
                            scrollOffset = geo.frame(in: .named("scroll")).minY
                            contentHeight = geo.size.height
                        }
                        return Color.clear
                    })
                }
                .coordinateSpace(name: "scroll")
                .scrollIndicators(.hidden)
                
                // Custom Scroll Indicator
                if contentHeight > 0 {
                    GeometryReader { geo in
                        let visibleRatio = geo.size.height / max(1, contentHeight)
                        let scrollableRatio = max(0, min(1, -scrollOffset / max(1, contentHeight - geo.size.height)))
                        let indicatorHeight = max(40, geo.size.height * visibleRatio)
                        // Clamp indicatorY between 0 and the max scroll range
                        let indicatorY = max(0, min(geo.size.height - indicatorHeight, scrollableRatio * (geo.size.height - indicatorHeight)))
                        
                        if visibleRatio < 1.0 { // Only show if scrolling is possible
                            Capsule()
                                .fill(Color.black)
                                .frame(width: 8, height: indicatorHeight)
                                .offset(y: indicatorY)
                                .padding(.trailing, 8)
                        }
                    }
                    .frame(width: 16) // Width of the scroll indicator area
                }
            }
        }
        .background(Color(red: 1.0, green: 0.79, blue: 0.07)) // Yellow #FFC812
        .navigationBarHidden(true)
    }
}

// Custom button for AR View with two icons and bounce animation
struct BackpackARButton: View {
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0)) {
                    isPressed = false
                }
                action()
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: "camera")
                Image(systemName: "sparkles")
            }
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(red: 1.0, green: 0.44, blue: 0.0)) // Orange
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.black, lineWidth: 3))
        }
        .scaleEffect(isPressed ? 0.9 : 1.0)
    }
}

// Custom button for Tabs with bounce animation
struct BackpackTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0)) {
                    isPressed = false
                }
                action()
            }
        }) {
            Text(title)
                .font(.custom("Belanosima-Bold", size: 20))
                .foregroundColor(isSelected ? .white : .black)
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(isSelected ? Color(red: 0.05, green: 0.45, blue: 0.98) : Color(red: 1.0, green: 0.45, blue: 0.75))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isSelected ? Color.white : Color.black, lineWidth: 3))
        }
        .scaleEffect(isPressed ? 0.9 : 1.0)
    }
}

#Preview {
    BackpackPageView()
        .environmentObject(AppState())
        .previewDevice("iPad Pro (11-inch) (4th generation)")
}
