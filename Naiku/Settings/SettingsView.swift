import Foundation
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    @State private var isReplacingKey = false

    var body: some View {
        Form {
            Section {
                Label("Naiku is happy without a key — chat is an optional power-up.", systemImage: "cat.fill")
                    .font(.callout)
            }

            Section("Naiku") {
                Toggle("Show Naiku over full-screen apps", isOn: fullScreenSelection)
            }

            Section("Chat") {
                Picker("Provider", selection: providerSelection) {
                    ForEach(ChatProviderID.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.segmented)

                Label("Changing provider starts a new conversation.", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("Model", text: modelText)
                    .autocorrectionDisabled()
            }

            keySection

            Section {
                Label("Keys stay in your macOS Keychain and are sent only to the selected provider.", systemImage: "lock.shield")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let statusMessage = model.statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .padding(8)
        .frame(width: 480, height: 500)
        .onChange(of: model.activeProvider) { _, _ in
            isReplacingKey = false
        }
        .onChange(of: model.anthropicModel) { _, _ in
            model.persistModels()
        }
        .onChange(of: model.openAIModel) { _, _ in
            model.persistModels()
        }
    }

    private var keySection: some View {
        Section("\(model.activeProvider.displayName) API key") {
            if isActiveProviderConfigured, !isReplacingKey {
                HStack {
                    Label("Key saved in Keychain", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Spacer()
                    Button("Replace…") {
                        isReplacingKey = true
                    }
                    Button("Remove", role: .destructive) {
                        model.deleteKey(for: model.activeProvider)
                    }
                }
            } else {
                HStack {
                    SecureField("Paste API key", text: keyDraft)
                    Link("Create a key", destination: keyURL(for: model.activeProvider))
                }

                HStack {
                    Button("Save Key") {
                        model.saveKey(for: model.activeProvider)
                        isReplacingKey = false
                    }
                    .disabled(keyDraft.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if isReplacingKey {
                        Button("Cancel") {
                            keyDraft.wrappedValue = ""
                            isReplacingKey = false
                        }
                    }
                }
            }
        }
    }

    private var providerSelection: Binding<ChatProviderID> {
        Binding(
            get: { model.activeProvider },
            set: { model.selectProvider($0) }
        )
    }

    private var fullScreenSelection: Binding<Bool> {
        Binding(
            get: { model.showsOverFullScreenApps },
            set: { model.setShowsOverFullScreenApps($0) }
        )
    }

    private var modelText: Binding<String> {
        switch model.activeProvider {
        case .anthropic: $model.anthropicModel
        case .openAI: $model.openAIModel
        }
    }

    private var keyDraft: Binding<String> {
        switch model.activeProvider {
        case .anthropic: $model.anthropicKeyDraft
        case .openAI: $model.openAIKeyDraft
        }
    }

    private var isActiveProviderConfigured: Bool {
        switch model.activeProvider {
        case .anthropic: model.hasAnthropicKey
        case .openAI: model.hasOpenAIKey
        }
    }

    private func keyURL(for provider: ChatProviderID) -> URL {
        switch provider {
        case .anthropic: URL(string: "https://console.anthropic.com/settings/keys")!
        case .openAI: URL(string: "https://platform.openai.com/api-keys")!
        }
    }
}
