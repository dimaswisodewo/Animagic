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
        GuideAnimal(name: "Ant", imageName: "ant")
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
            Spacer()
            Text("Guide")
                .font(.custom("Belanosima-Bold", size: 28))
                .foregroundStyle(.white)
            Spacer()
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(10)
                    .background(AnimagicTheme.orange)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.black, lineWidth: 2))
            }
            .buttonStyle(.animagicPress)
        }
        .padding(.top, 20)
        .padding(.horizontal, 20)
    }

    private var searchField: some View {
        HStack {
            TextField("Search.....", text: $searchText)
                .font(.custom("Belanosima-Regular", size: 18))
                .foregroundStyle(.black)
            Spacer()
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.black)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.white)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(.black, lineWidth: 3))
        .padding(.horizontal, 20)
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
        withAnimation { isPresented = false }
    }

    private static let columns = [GridItem(.flexible()), GridItem(.flexible())]
}

private struct GuideAnimalButton: View {
    let animal: GuideAnimal
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: animal.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 50)
                    .foregroundStyle(.gray)
                Text(animal.name)
                    .font(.custom("Belanosima-SemiBold", size: 20))
                    .foregroundStyle(.black)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}
