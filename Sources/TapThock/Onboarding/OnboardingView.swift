import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case accessibility
    case launchAtLogin
    case finish
}

struct OnboardingView: View {
    @Bindable var appModel: AppModel
    @Bindable var permissionChecker: PermissionChecker
    @State private var currentStep: OnboardingStep

    init(appModel: AppModel) {
        self.appModel = appModel
        permissionChecker = appModel.permissionChecker
        _currentStep = State(initialValue: appModel.initialOnboardingStep())
    }

    var body: some View {
        VStack(spacing: 0) {
            progressHeader
            Divider()
            stepBody
        }
        .frame(minWidth: 760, minHeight: 520)
        .background(.background)
        .onChange(of: currentStep) { _, newStep in
            appModel.setOnboardingStep(newStep)
        }
    }

    private var progressHeader: some View {
        HStack(spacing: 10) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                Circle()
                    .fill(step.rawValue <= currentStep.rawValue ? Color.accentColor : Color.secondary.opacity(0.2))
                    .frame(width: 10, height: 10)
            }
            Spacer()
            Button("Remind Me Later") {
                appModel.deferOnboarding()
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
    }

    @ViewBuilder
    private var stepBody: some View {
        switch currentStep {
        case .welcome:
            OnboardingStepView(
                title: "Welcome to TapThock",
                subtitle: "Thocky mechanical typing + mouse clicks that feel alive",
                primaryActionTitle: "Get Started",
                secondaryActionTitle: "Skip for Now",
                secondaryAction: appModel.deferOnboarding
            ) {
                VStack(alignment: .leading, spacing: 18) {
                    featureBullet("Global keyboard, mouse-click, and scroll-wheel sounds")
                    featureBullet("20+ built-in sound packs with subtle per-press variation")
                    featureBullet("Swift-native onboarding and menu bar controls")
                }
            } primaryAction: {
                currentStep = .accessibility
            }
        case .accessibility:
            OnboardingStepView(
                title: "Grant Accessibility Access",
                subtitle: "TapThock needs Accessibility permission so it can hear your key presses anywhere on your Mac and play sounds instantly.",
                primaryActionTitle: "I've Granted It",
                primaryDisabled: !permissionChecker.isTrusted,
                secondaryActionTitle: "Skip for Now",
                secondaryAction: appModel.deferOnboarding
            ) {
                VStack(alignment: .leading, spacing: 18) {
                    statusRow(title: "Status", value: permissionChecker.isTrusted ? "Granted" : "Not Granted", tint: permissionChecker.isTrusted ? .green : .orange)
                    Button("Grant Accessibility Access") {
                        permissionChecker.requestAccessibilityAccess()
                    }
                    Text("After enabling TapThock in System Settings > Privacy & Security > Accessibility, return here and the button above becomes available automatically.")
                        .foregroundStyle(.secondary)
                }
            } primaryAction: {
                currentStep = .launchAtLogin
            }
        case .launchAtLogin:
            OnboardingStepView(
                title: "Launch at Login",
                subtitle: "Keep TapThock ready in the menu bar every time you sign in.",
                primaryActionTitle: "Continue",
                secondaryActionTitle: "Not Now",
                secondaryAction: {
                    currentStep = .finish
                }
            ) {
                VStack(alignment: .leading, spacing: 18) {
                    Toggle("Start TapThock Automatically When I Log In", isOn: $appModel.launchAtLogin)
                        .toggleStyle(.switch)
                    Text("You can change this later in Settings.")
                        .foregroundStyle(.secondary)
                }
            } primaryAction: {
                currentStep = .finish
            }
        case .finish:
            OnboardingStepView(
                title: "You're Ready to Thock",
                subtitle: "Everything is set. Try typing or clicking anywhere on your Mac, then adjust packs and levels from the menu bar whenever you like.",
                primaryActionTitle: "Finish"
            ) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Current Pack")
                        .font(.headline)
                    Text(appModel.currentPackName)
                    Button("Play Demo Sound") {
                        appModel.previewCurrentPack()
                    }
                }
            } primaryAction: {
                appModel.completeOnboarding()
            }
        }
    }

    private func featureBullet(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(.title3)
    }

    private func statusRow(title: String, value: String, tint: Color) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(tint)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}
