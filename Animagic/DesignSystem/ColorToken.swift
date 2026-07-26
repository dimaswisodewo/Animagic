//
//  ColorToken.swift
//  AniMagic
//
//  Created by Gogo Figo on 20/07/26.
//

import SwiftUI

extension Color {
    struct Palette {
            // MARK: - Orange Swatch
            static let o50  = Color(red: 255/255, green: 241/255, blue: 230/255)
            static let o75  = Color(red: 255/255, green: 186/255, blue: 150/255)
            static let o100 = Color(red: 254/255, green: 174/255, blue: 107/255)
            static let o200 = Color(red: 254/255, green: 140/255, blue: 43/255)
            static let o300 = Color(red: 254/255, green: 116/255, blue: 0/255)
            static let o400 = Color(red: 178/255, green: 81/255,  blue: 0/255)
            static let o500 = Color(red: 155/255, green: 71/255,  blue: 0/255)
            
            // MARK: - Neutral Swatch
            static let n0   = Color(red: 255/255, green: 255/255, blue: 255/255)
            static let n10  = Color(red: 250/255, green: 251/255, blue: 251/255)
            static let n20  = Color(red: 235/255, green: 237/255, blue: 240/255)
            static let n30  = Color(red: 194/255, green: 199/255, blue: 208/255)
            static let n40  = Color(red: 166/255, green: 174/255, blue: 187/255)
            static let n50  = Color(red: 137/255, green: 147/255, blue: 164/255)
            static let n60  = Color(red: 80/255,  green: 95/255,  blue: 121/255)
            static let n70  = Color(red: 9/255,   green: 30/255,  blue: 66/255)
            
            // MARK: - Blue Swatch
            static let b50  = Color(red: 230/255, green: 238/255, blue: 253/255)
            static let b75  = Color(red: 151/255, green: 190/255, blue: 246/255)
            static let b100 = Color(red: 108/255, green: 163/255, blue: 245/255)
            static let b200 = Color(red: 44/255,  green: 124/255, blue: 241/255)
            static let b300 = Color(red: 1/255,   green: 97/255,  blue: 238/255) // Main
            static let b400 = Color(red: 1/255,   green: 88/255,  blue: 167/255)
            static let b500 = Color(red: 1/255,   green: 55/255,  blue: 145/255)
            
            // MARK: - Yellow Swatch
            static let y50  = Color(red: 255/255, green: 250/255, blue: 230/255)
            static let y75  = Color(red: 255/255, green: 235/255, blue: 150/255)
            static let y100 = Color(red: 255/255, green: 226/255, blue: 107/255)
            static let y200 = Color(red: 255/255, green: 214/255, blue: 43/255)
            static let y300 = Color(red: 255/255, green: 205/255, blue: 0/255)   // Main
            static let y400 = Color(red: 179/255, green: 144/255, blue: 0/255)
            static let y500 = Color(red: 156/255, green: 125/255, blue: 0/255)
            
            // MARK: - Red Swatch
            static let r50  = Color(red: 255/255, green: 230/255, blue: 230/255)
            static let r75  = Color(red: 255/255, green: 164/255, blue: 174/255)
            static let r100 = Color(red: 255/255, green: 123/255, blue: 140/255)
            static let r200 = Color(red: 238/255, green: 67/255,  blue: 95/255)
            static let r300 = Color(red: 231/255, green: 27/255,  blue: 60/255)
            static let r400 = Color(red: 161/255, green: 11/255,  blue: 36/255)
            static let r500 = Color(red: 141/255, green: 5/255,   blue: 27/255)
        
            // MARK: - Green Swatch
               static let g50  = Color(red: 234/255, green: 250/255, blue: 230/255)
               static let g75  = Color(red: 167/255, green: 235/255, blue: 150/255)
               static let g100 = Color(red: 131/255, green: 227/255, blue: 107/255)
               static let g200 = Color(red: 77/255,  green: 215/255, blue: 43/255)
               static let g300 = Color(red: 41/255,  green: 207/255, blue: 0/255)   // Main Green
               static let g400 = Color(red: 29/255,  green: 145/255, blue: 0/255)
               static let g500 = Color(red: 25/255,  green: 126/255, blue: 0/255)
        }
    
    struct Token {
        struct Background {
            static let primary = Color(Palette.y300)
            static let surface = Color(Palette.n0)
        }
        struct Button {
            static let primary = Color(Palette.o200)
            static let secondary = Color(Palette.b200)
            static let outline = Color(Palette.n0)
            static let success = Color(Palette.g200)
            static let error = Color(Palette.n0)
            static let disabled = Color(Palette.n20)
        }
        struct Text {
            static let primary = Color(Palette.n0)
            static let secondary = Color(Palette.n70)
            static let disabled = Color(Palette.n30)
        }
        struct Border {
            static let primary = Color(Palette.o300)
            static let secondary = Color(Palette.b300)
            static let outline = Color(Palette.n20)
            static let alert = Color(Palette.r300)
            static let disabled = Color(Palette.n20)
        }
        struct Icon {
            static let primary = Color(Palette.n0)
            static let disabled = Color(Palette.n30)
            static let alert = Color(Palette.n60)
        }
        struct Card {
            static let primary = Color(Palette.b50)
            static let selected = Color(Palette.o50)
        }
    }
}
