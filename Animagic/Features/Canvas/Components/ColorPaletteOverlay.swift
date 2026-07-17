//
//  ColorPaletteOverlay.swift
//  AniMagic
//
//  Created by Antigravity on 17/07/26.
//

import SwiftUI
import PencilKit

struct ColorPaletteOverlay: View {
    @Binding var isPresented: Bool
    @Binding var canvasView: PKCanvasView
    
    let colors: [Color] = [.black, .red, .orange, .yellow, .green, .blue, .purple, .pink]
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Colors")
                .font(.custom("Belanosima-SemiBold", size: 16))
                .foregroundColor(.black.opacity(0.8))
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                ForEach(colors, id: \.self) { color in
                    Button(action: {
                        selectColor(color)
                    }) {
                        Circle()
                            .fill(color)
                            .frame(width: 44, height: 44)
                            .overlay(Circle().stroke(Color.black.opacity(0.2), lineWidth: 2))
                            .shadow(radius: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .frame(width: 240)
        .background(.white, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.black.opacity(0.1), lineWidth: 1))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
    }
    
    private func selectColor(_ color: Color) {
        if let currentInkingTool = canvasView.tool as? PKInkingTool {
            canvasView.tool = PKInkingTool(currentInkingTool.inkType, color: UIColor(color), width: currentInkingTool.width)
        } else {
            // Default to pen if they were using eraser
            canvasView.tool = PKInkingTool(.pen, color: UIColor(color), width: 5)
        }
        withAnimation {
            isPresented = false
        }
    }
}
