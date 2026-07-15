import SwiftUI

struct GuideAnimal: Identifiable {
    let id = UUID()
    let name: String
    let imageName: String
}

let mockGuideAnimals = [
    GuideAnimal(name: "Cat", imageName: "cat"),
    GuideAnimal(name: "Dog", imageName: "dog"),
    GuideAnimal(name: "Bird", imageName: "bird"),
    GuideAnimal(name: "Rabbit", imageName: "hare"),
    GuideAnimal(name: "Fish", imageName: "fish"),
    GuideAnimal(name: "Tortoise", imageName: "tortoise"),
    GuideAnimal(name: "Ladybug", imageName: "ladybug"),
    GuideAnimal(name: "Ant", imageName: "ant")
]

struct GuidePopupView: View {
    @Binding var isPresented: Bool
    @Binding var selectedAnimal: GuideAnimal?
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Spacer()
                Text("Guide")
                    .font(.custom("Belanosima-Bold", size: 28))
                    .foregroundColor(.white)
                Spacer()
                
                Button(action: {
                    withAnimation {
                        isPresented = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                        .padding(10)
                        .background(Color(red: 1.0, green: 0.44, blue: 0.0)) // Orange
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.black, lineWidth: 2))
                }
            }
            .padding(.top, 20)
            .padding(.horizontal, 20)
            
            // Search Bar
            HStack {
                TextField("Search.....", text: $searchText)
                    .font(.custom("Belanosima-Regular", size: 18))
                    .foregroundColor(.black)
                Spacer()
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.black)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.white)
            .clipShape(Capsule())
            .overlay(
                        Capsule()
                            .stroke(Color.black, lineWidth: 3)
                    )
            .padding(.horizontal, 20)
            
            // Grid
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                    ForEach(mockGuideAnimals.filter { searchText.isEmpty ? true : $0.name.localizedCaseInsensitiveContains(searchText) }) { animal in
                        Button(action: {
                            selectedAnimal = animal
                            withAnimation {
                                isPresented = false
                            }
                        }) {
                            VStack {
                                Image(systemName: animal.imageName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 50)
                                    .foregroundColor(.gray)
                                Text(animal.name)
                                    .font(.custom("Belanosima-SemiBold", size: 20))
                                    .foregroundColor(.black)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 120)
                            .background(Color.white)
                            .cornerRadius(16)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .background(Color(red: 1.0, green: 0.45, blue: 0.75)) // Pink
        .edgesIgnoringSafeArea(.bottom)
    }
}
