//
//  HelpPageView.swift
//  AniMagic
//
//  Created by MorpKnight on 21/07/26.
//

import SwiftUI

struct HelpPageView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HapticFeedbackManager.self) private var haptics

    var body: some View {
        VStack(spacing: 0) {
            HelpPageHeader(onBack: dismiss.callAsFunction)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    introduction
                    hapticsSection
                    safetySection
                    quickStartSection
                    drawingSection
                    backpackSection
                    magicLensSection
                    cameraSection
                    virtualRoomSection
                    cutoutSection
                    permissionsSection
                    troubleshootingSection
                    parentSection
                }
                .frame(maxWidth: 920, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.top, 8)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .background(Color.Token.Background.primary.ignoresSafeArea())
        .navigationBarHidden(true)
        .textSelection(.enabled)
    }

    private var hapticsSection: some View {
        HelpSectionView(title: "Touch feedback", icon: "waveform", accentColor: AnimagicTheme.orange) {
            Toggle("Haptics", isOn: Binding(
                get: { haptics.isEnabled },
                set: { haptics.isEnabled = $0 }
            ))
            .toggleStyle(.animagic)
            .accessibilityHint("Turns AniMagix touch feedback on or off")

            Text("Haptics add gentle touch feedback to drawing milestones, magical transformations, AR placement, and camera controls. All actions still have visual feedback when haptics are off or unavailable.")
        }
    }

    private var introduction: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text("YOUR ADVENTURE GUIDE")
                    .font(.custom("Belanosima-Bold", size: 16, relativeTo: .headline))
                    .tracking(1.4)
                    .foregroundStyle(AnimagicTheme.blue)

                Text("How to use AniMagix")
                    .font(.custom("Belanosima-Bold", size: 40, relativeTo: .largeTitle))
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(AnimagicTheme.darkNavy)
                    .accessibilityAddTraits(.isHeader)

                Text("Turn drawings and photo cutouts into AR characters, explore virtual rooms, and capture your creations.")
                    .font(.custom("Belanosima-Regular", size: 21, relativeTo: .body))
                    .foregroundStyle(Color.Token.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: "questionmark")
                .font(.system(size: 48, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 104, height: 104)
                .background(AnimagicTheme.blue, in: Circle())
                .overlay(Circle().stroke(AnimagicTheme.darkNavy, lineWidth: 5))
                .padding(8)
                .background(.white, in: Circle())
                .accessibilityHidden(true)
        }
        .padding(28)
        .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AnimagicTheme.darkNavy, lineWidth: 5)
        }
    }

    private var safetySection: some View {
        HelpSectionView(
            title: "Stay safe while using AR",
            icon: "figure.walk",
            accentColor: Color.Token.Button.success
        ) {
            BulletedHelpList(items: [
                "Use AniMagix in a clear, well-lit space.",
                "Look around you before moving. Watch for people, furniture, steps, and other obstacles.",
                "Hold your device securely and walk slowly.",
                "Stop looking at the screen whenever you need to move through a busy area.",
                "Ask a parent, guardian, or teacher for help when you need it."
            ])
        }
    }

    private var quickStartSection: some View {
        HelpSectionView(title: "Quick start", icon: "sparkles", accentColor: AnimagicTheme.orange) {
            NumberedHelpList(items: [
                "Make a new drawing, choose a saved drawing from My Backpack, or pick a 3D model.",
                "Open Magic Lens and slowly move your device so AniMagix can find a surface.",
                "Open the backpack, choose an item, then tap a detected surface or use Place It.",
                "Move, resize, or rotate the placed item until it looks right.",
                "Open Camera Mode to take a photo or record a video."
            ])
        }
    }

    private var drawingSection: some View {
        HelpSectionView(title: "Create a drawing", icon: "paintbrush.fill", accentColor: AnimagicTheme.pink) {
            Text("Choose Let’s Draw, or use the brush button in Magic Lens, to open the drawing page.")

            NumberedHelpList(items: [
                "Draw with your finger or Apple Pencil.",
                "Give the drawing a name. Use Guide if you want a little help getting started.",
                "Use Undo or Redo to fix recent changes.",
                "Choose Save when your drawing is ready. AniMagix tries to recognize it on your device and adds it to My Backpack.",
                "If recognition is not correct, you can choose a different character type later."
            ])
        }
    }

    private var backpackSection: some View {
        HelpSectionView(title: "Use My Backpack", icon: "backpack.fill", accentColor: AnimagicTheme.blue) {
            Text("My Backpack keeps your saved drawings and cutouts together.")

            BulletedHelpList(items: [
                "Use Search and category filters to find an item.",
                "Choose an item to see its details.",
                "From the details page, you can open it in Magic Lens, save it to Photos, share it, or delete it.",
                "Choose Draw More when you want to make another drawing."
            ])
        }
    }

    private var magicLensSection: some View {
        HelpSectionView(title: "Use Magic Lens", icon: "camera.viewfinder", accentColor: AnimagicTheme.orange) {
            HelpSubsectionView(title: "Find a surface") {
                Text("Point the camera at a flat area such as a floor or tabletop. Slowly move the device from side to side until the placement guide appears. A bright room and a surface with visible detail work best.")
            }

            HelpSubsectionView(title: "Choose and place an item") {
                NumberedHelpList(items: [
                    "Choose the backpack button to open the inventory without leaving Magic Lens.",
                    "Switch between Doodles and 3D Models, then choose an item.",
                    "Tap a detected surface to place it there, or aim the placement guide and choose Place It.",
                    "Tap a placed item to select it. Drag to move it, pinch to resize it, and rotate with two fingers.",
                    "With Apple Pencil Pro, hover over an item, then squeeze and roll the Pencil to rotate it.",
                    "Choose Done when you finish editing. Use Delete to remove the selected item, or Undo if you removed it by mistake."
                ])
            }

            HelpSubsectionView(title: "Magic Lens controls") {
                BulletedHelpList(items: [
                    "Orange chevron: expand or collapse the action buttons.",
                    "Eye: hide or show the controls so you can see more of the AR scene.",
                    "Brush: open the drawing page.",
                    "Backpack: open or close the inventory on the same page.",
                    "Camera: open Camera Mode.",
                    "Question mark: open this Help page."
                ])
            }
        }
    }

    private var cameraSection: some View {
        HelpSectionView(title: "Take photos and videos", icon: "camera.fill", accentColor: AnimagicTheme.blue) {
            NumberedHelpList(items: [
                "Arrange your AR scene and open Camera Mode.",
                "Press the shutter button once to take a photo.",
                "Press and hold the shutter button to record a video. Release it to stop recording.",
                "Review what you captured. Choose Retake to try again, or Save to add it to Photos.",
                "Use Share only when you decide to send your photo or video to someone else."
            ])
        }
    }

    private var virtualRoomSection: some View {
        HelpSectionView(title: "Explore a Virtual Room", icon: "globe.americas.fill", accentColor: AnimagicTheme.pink) {
            Text("Virtual Room places you inside a digital world instead of placing objects in the room around you.")

            NumberedHelpList(items: [
                "Choose a world, such as Citrus Orchard, Land, or Underwater.",
                "Complete calibration if AniMagix asks you to move your device.",
                "Use Explore to look around and move through the world.",
                "Use Edit to choose a doodle or 3D model and place it in the room.",
                "Select a placed item to change how it moves or to delete it."
            ])
        }
    }

    private var cutoutSection: some View {
        HelpSectionView(title: "Turn a photo into a cutout", icon: "photo.stack.fill", accentColor: AnimagicTheme.orange) {
            NumberedHelpList(items: [
                "Open Cutout Library and choose Add Images.",
                "Choose a photo with a clear subject. AniMagix removes the background on your device.",
                "Wait for processing to finish. Your cutout will appear in the library when it is ready.",
                "Choose a cutout to use it in Magic Lens. Use Undo or Clear if you need to remove imported cutouts."
            ])
        }
    }

    private var permissionsSection: some View {
        HelpSectionView(title: "Permissions and privacy", icon: "hand.raised.fill", accentColor: Color.Token.Button.success) {
            Text("AniMagix asks only for permissions needed by the feature you choose:")

            BulletedHelpList(items: [
                "Camera access is needed for Magic Lens and Camera Mode.",
                "Microphone access is needed when a video records sound.",
                "The system photo picker lets you choose which images to import. Photos access may be requested when you save a photo, video, or drawing."
            ])

            Text("Your drawings, cutouts, recognition results, and captures are processed or stored on your device. AniMagix does not automatically upload or share them. Something leaves the app only when you choose a system sharing option and complete the share yourself.")
        }
    }

    private var troubleshootingSection: some View {
        HelpSectionView(title: "If something is not working", icon: "wrench.and.screwdriver.fill", accentColor: AnimagicTheme.blue) {
            HelpSubsectionView(title: "AniMagix cannot find a surface") {
                Text("Move to a brighter area, point at a surface with visible detail, and move the device slowly. Avoid blank, shiny, or transparent surfaces.")
            }

            HelpSubsectionView(title: "An item will not place") {
                Text("Make sure a doodle or 3D model is selected and wait until the placement guide is ready. Try aiming at a different surface if the button is still unavailable.")
            }

            HelpSubsectionView(title: "The camera or microphone is unavailable") {
                Text("Open the Settings app, find AniMagix, and allow the permission you need. Then return to AniMagix and try again.")
            }

            HelpSubsectionView(title: "A photo or video will not save") {
                Text("Check Photos permission and available device storage, then try Save again.")
            }

            HelpSubsectionView(title: "Tracking was interrupted") {
                Text("Point the camera back at the area you scanned. If the scene still does not line up, leave Magic Lens and open it again to start a new scan.")
            }
        }
    }

    private var parentSection: some View {
        HelpSectionView(title: "For parents and guardians", icon: "person.2.fill", accentColor: AnimagicTheme.pink) {
            Text("Please help children choose a safe play area and understand when the camera, microphone, and Photos permissions are needed. Permissions can be reviewed or changed at any time in the Settings app. AniMagix keeps its drawings and media on the device unless someone deliberately uses a sharing option.")
        }
    }
}

private struct HelpPageHeader: View {
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            AnimagicIconButton(
                icon: "chevron.left",
                backgroundColor: AnimagicTheme.orange,
                action: onBack
            )
            .accessibilityLabel("Back")

            Text("Help")
                .font(.custom("Belanosima-Bold", size: 36, relativeTo: .largeTitle))
                .foregroundStyle(.black)

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color.Token.Background.primary)
    }
}

private struct HelpSectionView<Content: View>: View {
    let title: String
    let icon: String
    let accentColor: Color
    let content: Content

    init(
        title: String,
        icon: String,
        accentColor: Color,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.accentColor = accentColor
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AnimagicTheme.darkNavy)
                    .frame(width: 52, height: 52)
                    .background(accentColor, in: Circle())
                    .overlay(Circle().stroke(AnimagicTheme.darkNavy, lineWidth: 3))

                Text(title)
                    .font(.custom("Belanosima-SemiBold", size: 30, relativeTo: .title2))
                    .foregroundStyle(AnimagicTheme.darkNavy)
                    .accessibilityAddTraits(.isHeader)
            }

            Rectangle()
                .fill(AnimagicTheme.darkNavy.opacity(0.14))
                .frame(height: 2)

            content
                .font(.custom("Belanosima-Regular", size: 20, relativeTo: .body))
                .foregroundStyle(Color.Token.Text.secondary)
        }
        .padding(24)
        .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AnimagicTheme.darkNavy, lineWidth: 4)
        }
    }
}

private struct HelpSubsectionView<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(AnimagicTheme.orange)
                    .frame(width: 6, height: 24)

                Text(title)
                    .font(.custom("Belanosima-SemiBold", size: 22, relativeTo: .headline))
                    .foregroundStyle(AnimagicTheme.darkNavy)
                    .accessibilityAddTraits(.isHeader)
            }

            content
        }
    }
}

private struct BulletedHelpList: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Circle()
                        .fill(AnimagicTheme.orange)
                        .frame(width: 9, height: 9)
                        .overlay(Circle().stroke(AnimagicTheme.darkNavy, lineWidth: 1.5))
                    Text(item)
                }
            }
        }
    }
}

private struct NumberedHelpList: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.custom("Belanosima-Bold", size: 16, relativeTo: .body))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(AnimagicTheme.blue, in: Circle())
                        .overlay(Circle().stroke(AnimagicTheme.darkNavy, lineWidth: 2))
                    Text(item)
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        HelpPageView()
    }
    .environment(HapticFeedbackManager(defaults: UserDefaults(suiteName: "HelpPagePreview")!))
}
#endif
