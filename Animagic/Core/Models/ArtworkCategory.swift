import Foundation

enum ArtworkCategory: String, CaseIterable, Identifiable, Codable {
    case skies
    case underwater
    case land

    var id: String { rawValue }

    var title: String {
        switch self {
        case .skies: "Skies"
        case .underwater: "Underwater"
        case .land: "Land"
        }
    }

    static func category(forDoodleLabel label: String?) -> Self {
        switch label?.lowercased() {
        case "bat", "bird", "duck", "flamingo", "owl", "parrot", "penguin", "swan",
             "bee", "butterfly", "mosquito":
            .skies
        case "dolphin", "fish", "shark", "whale", "sea turtle", "octopus", "snail", "crab", "lobster":
            .underwater
        default:
            .land
        }
    }
}

enum DoodleSpecies {
    static let all = [
        "bat", "bird", "duck", "flamingo", "owl", "parrot", "penguin", "swan",
        "ant", "bee", "butterfly", "mosquito", "scorpion", "spider",
        "dolphin", "fish", "shark", "whale",
        "bear", "camel", "cat", "cow", "dog", "elephant", "giraffe", "hedgehog", "horse",
        "kangaroo", "lion", "monkey", "mouse", "panda", "pig", "rabbit", "raccoon",
        "rhinoceros", "sheep", "squirrel", "tiger", "zebra", "crocodile", "sea turtle",
        "snake", "frog", "octopus", "snail", "crab", "lobster", "other"
    ]
}
