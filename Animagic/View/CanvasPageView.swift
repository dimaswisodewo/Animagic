import SwiftUI
import PencilKit

struct CanvasPageView: View {
    @EnvironmentObject var appState: AppState
    @State private var documentTitle: String = "Untitled"
    @State private var canvasView = PKCanvasView()
    
    @State private var showGuidePopup = false
    @State private var selectedGuideAnimal: GuideAnimal? = nil
    @State private var isClassifyingDoodle = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    // Top Bar
                    CanvasTopBarView(
                        documentTitle: $documentTitle,
                        canvasView: canvasView,
                        showGuidePopup: $showGuidePopup,
                        isClassifyingDoodle: $isClassifyingDoodle
                    )
                    
                    // Drawing Area
                    ZStack {
                        Color.white // Ensure white background at the very back
                            .ignoresSafeArea()
                        
                        // The tracing guide underneath the transparent canvas
                        if let animal = selectedGuideAnimal {
                            Image(systemName: animal.imageName)
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(Color.gray.opacity(0.15))
                                .padding(100)
                        }
                        
                        DrawingView(canvasView: $canvasView, isToolPickerVisible: !showGuidePopup)
                    }
                }
                
                // Side popup
                if showGuidePopup {
                    HStack(spacing: 0) {
                        Spacer()
                        GuidePopupView(isPresented: $showGuidePopup, selectedAnimal: $selectedGuideAnimal)
                            .frame(width: geometry.size.width * 0.45) // Takes ~45% of width
                            .shadow(radius: 10)
                    }
                    .transition(.move(edge: .trailing))
                    .zIndex(1)
                }

                if isClassifyingDoodle {
                    DoodleClassificationOverlay()
                        .zIndex(2)
                }
            }
            .animation(.easeInOut, value: showGuidePopup)
            .navigationBarHidden(true)
        .ignoresSafeArea(.keyboard)
        .onAppear {
            if appState.drawing.strokes.isEmpty {
                // If AppState drawing is empty, ensure canvas is blank
                canvasView.drawing = PKDrawing()
            } else {
                // Load existing drawing from state
                canvasView.drawing = appState.drawing
            }
        }
        .onDisappear {
            // Save the drawing to state when leaving
            appState.drawing = canvasView.drawing
        }
        }
    }
}

private struct DoodleClassificationOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.34)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.black)
                Text("AniMagic is recognizing your doodle…")
                    .font(.custom("Belanosima-SemiBold", size: 28))
                    .multilineTextAlignment(.center)
                Text("Preparing it for AR")
                    .font(.custom("Belanosima-Regular", size: 20))
                    .foregroundStyle(.secondary)
            }
            .padding(36)
            .background(.white, in: RoundedRectangle(cornerRadius: 28))
            .padding(32)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("AniMagic is recognizing your doodle")
    }
}

#Preview {
    CanvasPageView()
        .environmentObject(AppState())
        .previewDevice("iPad Pro (11-inch) (4th generation)")
}
