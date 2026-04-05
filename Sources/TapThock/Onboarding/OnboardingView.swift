import SwiftUI

struct OnboardingView: View {
    @Bindable var appModel: AppModel
    @Bindable var permissionChecker: PermissionChecker

    init(appModel: AppModel) {
        self.appModel = appModel
        permissionChecker = appModel.permissionChecker
    }

    var body: some View {
        OnboardingStepView(
            title: "Welcome to TapThock",
            subtitle: "TapThock needs Accessibility permission to hear your key presses anywhere on your Mac and play sounds instantly.",
            primaryActionTitle: "Get Started",
            primaryDisabled: !permissionChecker.isTrusted,
            secondaryActionTitle: "Remind Me Later",
            secondaryAction: appModel.deferOnboarding
        ) {
            VStack(alignment: .leading, spacing: 18) {
                statusRow(
                    title: "Status",
                    value: permissionChecker.isTrusted ? "Granted" : "Not Granted",
                    tint: permissionChecker.isTrusted ? .green : .orange
                )
                if !permissionChecker.isTrusted {
                    Button("Grant Accessibility Access") {
                        permissionChecker.requestAccessibilityAccess()
                    }
                    Text("After enabling TapThock in System Settings > Privacy & Security > Accessibility, return here and the button above becomes available automatically.")
                        .foregroundStyle(.secondary)
                }
            }
        } primaryAction: {
            appModel.completeOnboarding()
        }
        .frame(minWidth: 760, minHeight: 520)
        .background(.background)
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
