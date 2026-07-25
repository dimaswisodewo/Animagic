//
//  CreationCategory.swift
//  AniMagic
//
//  Created by Meynabel Dimas Wisodewo on 07/07/26.
//

import Foundation

public enum CreationCategory: String, CaseIterable, Identifiable, Codable {
    case skies
    case underwater
    case land

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .skies: "Skies"
        case .underwater: "Underwater"
        case .land: "Land"
        }
    }

    public static func category(forDoodleLabel label: String?) -> Self {
        guard let label,
              let species = DoodleSpecies(rawValue: label.lowercased()) else {
            return .land
        }
        return switch species {
        case .bat, .bird, .duck, .flamingo, .owl, .parrot, .penguin, .swan,
             .bee, .butterfly, .mosquito:
            .skies
        case .dolphin, .fish, .shark, .whale, .seaTurtle, .octopus, .snail, .crab, .lobster:
            .underwater
        default:
            .land
        }
    }
}

public enum DoodleSpecies: String, CaseIterable, Identifiable, Codable {
    case bat, bird, duck, flamingo, owl, parrot, penguin, swan
    case ant, bee, butterfly, mosquito, scorpion, spider
    case dolphin, fish, shark, whale
    case bear, camel, cat, cow, dog, elephant, giraffe, hedgehog, horse
    case kangaroo, lion, monkey, mouse, panda, pig, rabbit, raccoon
    case rhinoceros, sheep, squirrel, tiger, zebra, crocodile
    case seaTurtle = "sea turtle"
    case snake, frog, octopus, snail, crab, lobster, other

    public var id: String { rawValue }

    public var title: String { rawValue.capitalized }
}
