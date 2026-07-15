import SwiftUI
import PencilKit

struct CanvasTopBarView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @Binding var documentTitle: String
    let canvasView: PKCanvasView
    @Binding var showGuidePopup: Bool
    @Binding var isClassifyingDoodle: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Back Button
            TopBarIconButton(icon: "chevron.left") {
                dismiss()
            }
            
            // Title TextField
            TextField("Untitled", text: $documentTitle)
                .font(.custom("Belanosima-Regular", size: 24))
                .foregroundColor(.black)
            
            Spacer()
            
            // Guide Button
            TopBarButton(title: "Guide") {
                withAnimation {
                    showGuidePopup = true
                }
            }
            
            // Undo Button
            TopBarIconButton(icon: "arrow.uturn.backward") {
                canvasView.undoManager?.undo()
            }
            
            // Redo Button
            TopBarIconButton(icon: "arrow.uturn.forward") {
                canvasView.undoManager?.redo()
            }
            
            // Save Button (Navigates to AR Page)
            TopBarButton(title: "Save", isDisabled: isClassifyingDoodle) {
                guard !isClassifyingDoodle else { return }
                appState.drawing = canvasView.drawing
                
                let newDrawing = SavedDrawing(name: documentTitle, drawing: canvasView.drawing)
                appState.savedDrawings.append(newDrawing)
                
                let bounds = canvasView.drawing.bounds
                if !bounds.isEmpty {
                    let image = canvasView.drawing.image(from: bounds, scale: 1.0)
                    isClassifyingDoodle = true
                    Task.detached(priority: .userInitiated) {
                        let startedAt = DispatchTime.now().uptimeNanoseconds
                        let classificationResult = Result {
                            try DoodleClassificationService().classify(image).get()
                        }
                        let elapsed = DispatchTime.now().uptimeNanoseconds - startedAt
                        let minimumDuration: UInt64 = 1_200_000_000
                        if elapsed < minimumDuration {
                            try? await Task.sleep(nanoseconds: minimumDuration - elapsed)
                        }
                        let newCutout = Self.makeCutoutAsset(
                            image: image,
                            originalSize: bounds.size,
                            classificationResult: classificationResult
                        )

                        await MainActor.run {
                            appState.cutoutLibrary.append(newCutout)
                            isClassifyingDoodle = false
                            appState.navigationPath.append(NavigationRoute.arView)
                        }
                    }
                } else {
                    appState.navigationPath.append(NavigationRoute.arView)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(red: 1.0, green: 0.79, blue: 0.07)) // Yellow #FFC812
    }

    private static func makeCutoutAsset(
        image: UIImage,
        originalSize: CGSize,
        classificationResult: Result<DoodleClassification, Error>
    ) -> CutoutAsset {
        switch classificationResult {
        case .success(let classification):
            return CutoutAsset(
                image: image,
                originalSize: originalSize,
                doodleClassification: classification
            )
        case .failure(let error):
            return CutoutAsset(
                image: image,
                originalSize: originalSize,
                doodleClassificationError: error.localizedDescription
            )
        }
    }
}

// Reusable Button components for the Top Bar with bounce animation
struct TopBarButton: View {
    let title: String
    var isDisabled = false
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
        }){
            Text(title)
                .font(.custom("Belanosima-SemiBold", size: 20))
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color(red: 1.0, green: 0.44, blue: 0.0)) // Orange
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color.black, lineWidth: 3)
                )
        }
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .disabled(isDisabled)
    }
}

struct TopBarIconButton: View {
    let icon: String
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
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.black)
                .padding(12)
                .background(Color(red: 1.0, green: 0.44, blue: 0.0)) // Orange
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(Color.black, lineWidth: 3)
                )
        }
        .scaleEffect(isPressed ? 0.9 : 1.0)
    }
}
