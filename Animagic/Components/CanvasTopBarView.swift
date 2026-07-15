import SwiftUI
import PencilKit

struct CanvasTopBarView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @Binding var documentTitle: String
    let canvasView: PKCanvasView
    @Binding var showGuidePopup: Bool
    @Binding var isClassifyingDoodle: Bool
    @Binding var hasDrawing: Bool
    @Binding var showEmptyCanvasMessage: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Back Button
            TopBarIconButton(icon: "chevron.left") {
                dismiss()
            }
            
            HStack(spacing: 8) {
                Image(systemName: "pencil")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black.opacity(0.65))
                TextField("Name your drawing", text: $documentTitle)
                    .font(.custom("Belanosima-Regular", size: 22))
                    .foregroundColor(.black)
                    .textInputAutocapitalization(.words)
                    .accessibilityLabel("Drawing name")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.white.opacity(0.78), in: Capsule())
            .overlay(Capsule().stroke(.black.opacity(0.3), lineWidth: 2))
            .frame(maxWidth: 290)
            .accessibilityHint("Tap to name your drawing")
            
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
            TopBarButton(title: "Save", isDisabled: isClassifyingDoodle, isDimmed: !hasDrawing) {
                guard !isClassifyingDoodle else { return }
                guard hasDrawing && !canvasView.drawing.strokes.isEmpty else {
                    showEmptyCanvasMessage = true
                    return
                }
                let bounds = canvasView.drawing.bounds
                guard !bounds.isEmpty else {
                    showEmptyCanvasMessage = true
                    return
                }
                let trimmedTitle = documentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                let newDrawing = SavedDrawing(
                    name: trimmedTitle,
                    drawing: canvasView.drawing,
                    isNameManuallyEdited: !trimmedTitle.isEmpty
                )
                appState.addSavedDrawing(newDrawing)
                
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
                        classificationResult: classificationResult,
                        sourceDrawingID: newDrawing.id
                    )

                    await MainActor.run {
                        appState.updateSavedDrawingClassification(
                            id: newDrawing.id,
                            classification: newCutout.doodleClassification
                        )
                        appState.addCutout(newCutout)
                        appState.clearDrawing()
                        hasDrawing = false
                        isClassifyingDoodle = false
                        appState.navigationPath.append(NavigationRoute.arView)
                    }
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
        classificationResult: Result<DoodleClassification, Error>,
        sourceDrawingID: UUID
    ) -> CutoutAsset {
        switch classificationResult {
        case .success(let classification):
            return CutoutAsset(
                sourceDrawingID: sourceDrawingID,
                image: image,
                originalSize: originalSize,
                doodleClassification: classification,
                doodleOverrideLabel: nil
            )
        case .failure(let error):
            return CutoutAsset(
                sourceDrawingID: sourceDrawingID,
                image: image,
                originalSize: originalSize,
                doodleClassificationError: error.localizedDescription,
                doodleOverrideLabel: nil
            )
        }
    }
}

// Reusable Button components for the Top Bar with bounce animation
struct TopBarButton: View {
    let title: String
    var isDisabled = false
    var isDimmed = false
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
        .opacity(isDimmed ? 0.55 : 1)
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
