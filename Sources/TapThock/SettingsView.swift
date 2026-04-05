import SwiftUI

struct SettingsView: View {
    @Bindable var appModel: AppModel
    @Bindable var permissionChecker: PermissionChecker
    @State private var previewText = ""

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 14),
    ]

    init(appModel: AppModel) {
        self.appModel = appModel
        permissionChecker = appModel.permissionChecker
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                soundPackSection
                volumeSection
                typingPreviewSection
                advancedSection
            }
            .padding(24)
        }
        .background(.background)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TapThock")
                .font(.largeTitle.weight(.semibold))
            Text("Thocky mechanical typing + mouse clicks that feel alive")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var soundPackSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Sound Packs")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Preview Current Pack") {
                    appModel.previewCurrentPack()
                }
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                ForEach(appModel.availablePacks) { pack in
                    Button {
                        appModel.selectPack(pack, preview: true)
                    } label: {
                        SoundPackCard(pack: pack, isSelected: appModel.selectedPackID == pack.id)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Playback")
                .font(.title2.weight(.semibold))

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
        }
    }

    private var typingPreviewSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Test Keyboard")
                .font(.title2.weight(.semibold))
            Text("Type in the field below to hear the currently selected pack without leaving settings.")
                .foregroundStyle(.secondary)

            TypingPreviewField(text: $previewText) { event in
                appModel.preview(event: event)
            }
            .frame(height: 180)
        }
    }

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Advanced")
                .font(.title2.weight(.semibold))

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Launch at Login", isOn: $appModel.launchAtLogin)
                    Toggle("Show in Dock", isOn: $appModel.showDockIcon)

                    if !permissionChecker.isTrusted {
                        Button("Grant Accessibility Access") {
                            permissionChecker.requestAccessibilityAccess()
                        }
                    }

                    if let statusMessage = appModel.statusMessage {
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(8)
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
        VStack(alignment: .leading, spacing: 10) {
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
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.1))
                .frame(height: 16)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.45))
                        .frame(width: isSelected ? 120 : 84)
                }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 106, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.18), lineWidth: 1)
        )
    }
}
