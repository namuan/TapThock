import SwiftUI

struct SettingsView: View {
    @Bindable var appModel: AppModel
    @State private var previewText = ""

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 14),
    ]

    init(appModel: AppModel) {
        self.appModel = appModel
    }

    var body: some View {
        TabView {
            soundPacksTab
                .tabItem { Label("Sound Packs", systemImage: "music.note.list") }

            playbackTab
                .tabItem { Label("Playback", systemImage: "speaker.wave.2") }

            testKeyboardTab
                .tabItem { Label("Test Keyboard", systemImage: "keyboard") }
        }
        .padding(24)
    }

    private var soundPacksTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                    ForEach(appModel.availablePacks) { pack in
                        Button {
                            appModel.selectPack(pack, preview: true)
                        } label: {
                            SoundPackCard(pack: pack, isSelected: appModel.selectedPackID == pack.id)
                        }
                        .buttonStyle(.plain)
                    .focusEffectDisabled()
                    }
                }
            }
        }
    }

    private var playbackTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    slider(title: "Master Volume", value: $appModel.masterVolume)
                    slider(title: "Keyboard Volume", value: $appModel.keyboardVolume)
                    slider(title: "Mouse Volume", value: $appModel.mouseVolume)
                    slider(title: "Scroll Volume", value: $appModel.scrollVolume)

                    Divider()

                    Toggle("Keyboard Sounds", isOn: $appModel.keyboardEnabled)
                    Toggle("Mouse Click Sounds", isOn: $appModel.mouseEnabled)
                    Toggle("Scroll Wheel Sounds", isOn: $appModel.scrollEnabled)
                }
                .padding(8)
            }
            Spacer()
        }
    }

    private var testKeyboardTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Type in the field below to hear the currently selected pack without leaving settings.")
                .foregroundStyle(.secondary)

            TypingPreviewField(text: $previewText) { event in
                appModel.preview(event: event)
            }
        }
    }

    private func slider(title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text(value.wrappedValue, format: .percent.precision(.fractionLength(0)))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: 0...1)
        }
    }
}

private struct SoundPackCard: View {
    let pack: SoundPack
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(pack.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "play.circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
            Text(pack.id.replacingOccurrences(of: "-", with: " "))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.18), lineWidth: 1)
        )
    }
}
