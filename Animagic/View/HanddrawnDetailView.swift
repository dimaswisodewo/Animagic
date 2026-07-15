import SwiftUI
import PencilKit

struct HanddrawnDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    let drawing: SavedDrawing
    
    @State private var showDeleteConfirmation = false
    @State private var showShareSheet = false
    @State private var showSaveSuccess = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            HStack(spacing: 16) {
                // Back Button
                TopBarIconButton(icon: "chevron.left") {
                    dismiss()
                }
                
                // Title
                Text(drawing.name.isEmpty ? "Untitled" : drawing.name)
                    .font(.custom("Belanosima-Bold", size: 28))
                    .foregroundColor(.black)
                
                Spacer()
                
                // Magic Lens Button
                DetailActionButton(icon: "camera", secondaryIcon: "sparkles", bgColor: Color(red: 1.0, green: 0.44, blue: 0.0)) {
                    guard !drawing.drawing.bounds.isEmpty else { return }
                    let image = drawing.drawing.image(from: drawing.drawing.bounds, scale: 1.0)
                    let newCutout = CutoutAsset(image: image, originalSize: image.size)
                    appState.cutoutLibrary.append(newCutout)
                    appState.navigationPath.append(NavigationRoute.arView)
                }
                
                // Share Button
                DetailActionButton(icon: "square.and.arrow.up", bgColor: Color(red: 1.0, green: 0.44, blue: 0.0)) {
                    showShareSheet = true
                }
                
                // Save Button
                DetailActionButton(icon: "arrow.down.to.line", bgColor: Color(red: 1.0, green: 0.44, blue: 0.0)) {
                    saveToGallery()
                }
                
                // Trash Button
                DetailActionButton(icon: "trash", bgColor: Color(red: 1.0, green: 0.45, blue: 0.75)) {
                    showDeleteConfirmation = true
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 16)
            .background(Color(red: 1.0, green: 0.79, blue: 0.07)) // Yellow #FFC812
            
            // Image Content
            ZStack {
                Color.white.ignoresSafeArea()
                
                if !drawing.drawing.bounds.isEmpty {
                    Image(uiImage: drawing.drawing.image(from: drawing.drawing.bounds, scale: 1.0))
                        .resizable()
                        .scaledToFit()
                        .padding(40)
                } else {
                    Text("Empty Drawing")
                        .font(.custom("Belanosima-Regular", size: 24))
                        .foregroundColor(.gray)
                }
            }
        }
        .navigationBarHidden(true)
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("Delete Drawing"),
                message: Text("Are you sure you want to delete '\(drawing.name.isEmpty ? "Untitled" : drawing.name)'?"),
                primaryButton: .destructive(Text("Yes")) {
                    deleteDrawing()
                },
                secondaryButton: .cancel()
            )
        }
        .alert("Saved Successfully", isPresented: $showSaveSuccess) {
            Button("OK", role: .cancel) { }
        }
        .sheet(isPresented: $showShareSheet) {
            let imageToShare = drawing.drawing.bounds.isEmpty ? UIImage() : drawing.drawing.image(from: drawing.drawing.bounds, scale: 1.0)
            ShareSheet(activityItems: [imageToShare])
        }
    }
    
    private func saveToGallery() {
        guard !drawing.drawing.bounds.isEmpty else { return }
        let imageToSave = drawing.drawing.image(from: drawing.drawing.bounds, scale: 1.0)
        let imageSaver = ImageSaver()
        imageSaver.successHandler = {
            showSaveSuccess = true
        }
        imageSaver.writeToPhotoAlbum(image: imageToSave)
    }
    
    private func deleteDrawing() {
        appState.savedDrawings.removeAll { $0.id == drawing.id }
        dismiss()
    }
}

class ImageSaver: NSObject {
    var successHandler: (() -> Void)?
    
    func writeToPhotoAlbum(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveCompleted), nil)
    }

    @objc func saveCompleted(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if error == nil {
            successHandler?()
        }
    }
}

// Custom button for Action with bounce animation
struct DetailActionButton: View {
    let icon: String
    var secondaryIcon: String? = nil
    let bgColor: Color
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
            if let sec = secondaryIcon {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                    Image(systemName: sec)
                }
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(bgColor)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.black, lineWidth: 3))
            } else {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 50, height: 50)
                    .background(bgColor)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.black, lineWidth: 3))
            }
        }
        .scaleEffect(isPressed ? 0.9 : 1.0)
    }
}

#Preview {
    HanddrawnDetailView(drawing: SavedDrawing(name: "Test", drawing: PKDrawing()))
        .environmentObject(AppState())
}
