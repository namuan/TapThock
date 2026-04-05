import SwiftUI

struct OnboardingStepView<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content
    let primaryActionTitle: String
    let primaryAction: () -> Void
    let primaryDisabled: Bool
    let secondaryActionTitle: String?
    let secondaryAction: (() -> Void)?

    init(
        title: String,
        subtitle: String,
        primaryActionTitle: String,
        primaryDisabled: Bool = false,
        secondaryActionTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content,
        primaryAction: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.primaryActionTitle = primaryActionTitle
        self.primaryDisabled = primaryDisabled
        self.secondaryActionTitle = secondaryActionTitle
        self.secondaryAction = secondaryAction
        self.content = content()
        self.primaryAction = primaryAction
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(size: 32, weight: .bold))
                Text(subtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content

            Spacer()

            HStack {
                if let secondaryActionTitle, let secondaryAction {
                    Button(secondaryActionTitle, action: secondaryAction)
                        .buttonStyle(.plain)
                }
                Spacer()
                Button(primaryActionTitle, action: primaryAction)
                    .keyboardShortcut(.defaultAction)
                    .disabled(primaryDisabled)
            }
        }
        .padding(32)
    }
}
