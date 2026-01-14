import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var patentStore: PatentStore
    @State private var showAPIKey = false
    @State private var showDeleteConfirmation = false
    @State private var hasKey = false

    // MARK: - URLs
    private let anthropicURL = URL(string: "https://console.anthropic.com/")!
    private let nasaPortalURL = URL(string: "https://technology.nasa.gov/")!
    private let nasaLicenseURL = URL(string: "https://technology.nasa.gov/license")!
    private let privacyPolicyURL = URL(string: "https://riorio3.github.io/NASA/privacy-policy")!

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

                    Link(destination: privacyPolicyURL) {
                        HStack {
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
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

#Preview {
    SettingsView()
        .environmentObject(PatentStore())
}
