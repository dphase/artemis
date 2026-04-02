import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Last updated: April 1, 2026")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Artemis does not collect, store, or share any personal data. The app runs entirely on your device with no network requests, no analytics, and no tracking.")

                    Text("No Data Collection")
                        .font(.headline)
                    Text("This app does not collect any information from you or your device. There are no accounts, no sign-ins, and no user-generated content.")

                    Text("No Third-Party Services")
                        .font(.headline)
                    Text("Artemis does not integrate with any third-party services, advertising networks, or analytics platforms.")

                    Text("Contact")
                        .font(.headline)
                    Text("If you have questions about this policy, contact us at privacy@project93.com.")
                }
                .padding()
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
