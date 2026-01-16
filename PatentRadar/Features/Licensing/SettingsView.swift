import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var patentStore: PatentStore
    @State private var showAPIKey = false
    @State private var showDeleteConfirmation = false
    @State private var hasKey = false
    @State private var showPrivacyPolicy = false

    // MARK: - URLs
    private let anthropicURL = URL(string: "https://console.anthropic.com/")!
    private let nasaPortalURL = URL(string: "https://technology.nasa.gov/")!
    private let nasaLicenseURL = URL(string: "https://technology.nasa.gov/license")!

    var body: some View {
        NavigationStack {
            List {
                // API Key Section
                Section {
                    if hasKey {
                        APIKeyDisplayView(
                            apiKey: patentStore.apiKey,
                            showAPIKey: $showAPIKey,
                            onDelete: { showDeleteConfirmation = true }
                        )
                    } else {
                        APIKeyInputView(onSave: { key in
                            patentStore.setAPIKey(key)
                            hasKey = true
                        })
                    }
                } header: {
                    Text("AI Integration")
                } footer: {
                    Text("Your API key is stored securely in the iOS Keychain and never shared.")
                }
                .onAppear {
                    hasKey = !patentStore.apiKey.isEmpty
                }

                // Get API Key Section
                Section {
                    Link(destination: anthropicURL) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Get Claude API Key")
                                    .font(.headline)
                                Text("Sign up at console.anthropic.com")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                    }
                } header: {
                    Text("Don't have an API key?")
                }

                // About Section
                Section {
                    HStack {
                        Text("Data Source")
                        Spacer()
                        Text("NASA T2 Portal")
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: nasaPortalURL) {
                        HStack {
                            Text("NASA Technology Transfer")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Link(destination: nasaLicenseURL) {
                        HStack {
                            Text("Licensing Information")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("About")
                }

                // Startup NASA Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text("Startup NASA Program")
                                .font(.headline)
                        }

                        Text("Startups can license NASA patents for FREE for up to 3 years. This is a great opportunity for early-stage companies.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Link(destination: nasaLicenseURL) {
                            Text("Learn More")
                                .font(.subheadline.bold())
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Clear Data
                Section {
                    Button("Clear Saved Patents", role: .destructive) {
                        patentStore.savedPatents.removeAll()
                    }
                    .disabled(patentStore.savedPatents.isEmpty)
                } footer: {
                    Text("This will remove all patents from your Saved list.")
                }

                // App Info
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        showPrivacyPolicy = true
                    } label: {
                        HStack {
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .confirmationDialog("Remove API Key?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Remove", role: .destructive) {
                    KeychainService.shared.deleteAPIKey()
                    patentStore.apiKey = ""
                    hasKey = false
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll need to enter your API key again to use AI features.")
            }
        }
    }
}

// MARK: - Isolated Input View (prevents parent re-renders)
private struct APIKeyInputView: View {
    @State private var text = ""
    let onSave: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "key")
                    .foregroundStyle(.blue)
                Text("Claude API Key")
                    .font(.headline)
            }

            Text("Required for AI business analysis")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("sk-ant-api03-...", text: $text)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.password)

            Button("Save API Key") {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    onSave(trimmed)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Display View
private struct APIKeyDisplayView: View {
    let apiKey: String
    @Binding var showAPIKey: Bool
    let onDelete: () -> Void

    private var maskedKey: String {
        if apiKey.count > 12 {
            return String(apiKey.prefix(8)) + "..." + String(apiKey.suffix(4))
        }
        return String(repeating: "*", count: apiKey.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "key.fill")
                    .foregroundStyle(.green)
                Text("Claude API Key")
                    .font(.headline)
            }

            HStack {
                Text(showAPIKey ? apiKey : maskedKey)
                    .font(.system(.caption, design: .monospaced))
                Spacer()
                Button {
                    showAPIKey.toggle()
                } label: {
                    Image(systemName: showAPIKey ? "eye.slash" : "eye")
                }
            }

            Button("Remove API Key", role: .destructive, action: onDelete)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Privacy Policy View
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Group {
                        Text("Last Updated: January 14, 2025")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        section(title: "Overview", content: "PatentRadar helps users discover and analyze NASA patents available for licensing. This privacy policy explains how we handle your data.")

                        section(title: "What We Collect") {
                            VStack(alignment: .leading, spacing: 8) {
                                bullet("Claude API Key: If you enable AI features, you provide your own Anthropic API key")
                                bullet("Saved Patents: Patents you bookmark are stored locally on your device")
                                bullet("Problem History: Your problem-solving queries are stored locally")
                            }
                        }

                        section(title: "What We Don't Collect") {
                            VStack(alignment: .leading, spacing: 8) {
                                bullet("We do not collect personal information")
                                bullet("We do not track your location")
                                bullet("We do not use analytics or tracking")
                                bullet("We do not sell any data")
                            }
                        }
                    }

                    Group {
                        section(title: "Data Storage", content: "All data is stored locally on your device. Your API key is stored securely in iOS Keychain. Saved patents and search history are stored in local app storage. We do not operate any servers or databases.")

                        section(title: "Third-Party Services", content: "Patent data is fetched from NASA's public Technology Transfer Portal (technology.nasa.gov). If you enable AI features, your queries are sent to Anthropic's Claude API using your own API key.")

                        section(title: "Data Deletion", content: "You can delete all app data at any time via Settings or by deleting the app from your device.")

                        section(title: "Children's Privacy", content: "This app is not directed at children under 13. We do not knowingly collect data from children.")

                        section(title: "Contact", content: "For questions about this privacy policy, contact us through the App Store listing or leave a review.")

                        section(title: "Changes", content: "We may update this policy. Changes will be reflected in the \"Last Updated\" date.")

                        Text("PatentRadar is not affiliated with, endorsed by, or sponsored by NASA. Patent data is sourced from NASA's publicly available Technology Transfer Portal.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 10)
                    }
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

    private func section(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func section(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(PatentStore())
}
