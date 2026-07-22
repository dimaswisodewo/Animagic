import SwiftUI

struct GuideAnimal: Identifiable, Equatable {
    let name: String
    let imageName: String

    var id: String { imageName }
}

enum GuideCatalog {
    static let animals = [
        GuideAnimal(name: "Cat", imageName: "cat"),
        GuideAnimal(name: "Dog", imageName: "dog"),
        GuideAnimal(name: "Bird", imageName: "bird"),
        GuideAnimal(name: "Rabbit", imageName: "hare"),
        GuideAnimal(name: "Fish", imageName: "fish"),
        GuideAnimal(name: "Tortoise", imageName: "tortoise"),
        GuideAnimal(name: "Ladybug", imageName: "ladybug"),
        GuideAnimal(name: "Ant", imageName: "ant"),
        GuideAnimal(name: "Lizard", imageName: "lizard"),
        GuideAnimal(name: "Snail", imageName: "snail")
    ]

    static func animals(matching searchText: String) -> [GuideAnimal] {
        guard !searchText.isEmpty else { return animals }
        return animals.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
}

struct GuidePopupView: View {
    @Binding var isPresented: Bool
    @Binding var selectedAnimal: GuideAnimal?
    @State private var searchText = ""

    private var filteredAnimals: [GuideAnimal] {
        GuideCatalog.animals(matching: searchText)
    }

    var body: some View {
        VStack(spacing: 20) {
            header
            searchField
            animalGrid
        }
        .background(AnimagicTheme.pink)
        .ignoresSafeArea(edges: .bottom)
    }

    private var header: some View {
        HStack {
            Text("Guide")
                .font(.custom("Belanosima-SemiBold", size: 32))
                .foregroundStyle(.white)
            Spacer()
            AnimagicIconButton(
                icon: "xmark",
                backgroundColor: AnimagicTheme.orange,
                iconColor: .white,
                innerBorderColor: Color(red: 0.8, green: 0.35, blue: 0.0),
                action: dismiss
            )
        }
        .padding(.top, 20)
        .padding(.horizontal, 20)
    }

    private var searchField: some View {
        AnimagicTextField(placeholder: "Search.....", text: $searchText)
            .padding(.horizontal, 12)
    }

    private var animalGrid: some View {
        ScrollView {
            LazyVGrid(columns: Self.columns, spacing: 20) {
                ForEach(filteredAnimals) { animal in
                    GuideAnimalButton(animal: animal) {
                        selectedAnimal = animal
                        dismiss()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private func dismiss() {
        isPresented = false
    }

    private static let columns = [GridItem(.flexible()), GridItem(.flexible())]
}

private struct GuideAnimalButton: View {
    let animal: GuideAnimal
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            AnimagicCard(title: animal.name) {
                Image(systemName: animal.imageName)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.gray)
            }
        }
        .buttonStyle(.animagicPress)
    }
}
