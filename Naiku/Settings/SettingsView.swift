import Foundation
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    @State private var pendingProvider: ChatProviderID?
    @State private var isConfirmingProviderChange = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Welcome to Naiku", systemImage: "cat.fill")
                        .font(.headline)
                    Text("Naiku is a desktop pet first: close this window and the cat will happily follow your pointer without an API key.")
                    Text("Chat is bring-your-own-key (BYOK). Choose Anthropic or OpenAI below; your key is stored in macOS Keychain and is sent only to that provider.")
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
                .accessibilityElement(children: .combine)
            }

            Section("Conversation") {
                Picker("Provider", selection: providerSelection) {
                    ForEach(ChatProviderID.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.segmented)

                Label("Changing provider starts a new conversation.", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Models") {
                TextField("Anthropic model", text: $model.anthropicModel)
                TextField("OpenAI model", text: $model.openAIModel)
                Button("Save Model Choices") {
                    model.saveModels()
                }
            }

            credentialSection(
                provider: .anthropic,
                isConfigured: model.hasAnthropicKey,
                draft: $model.anthropicKeyDraft,
                keyURL: URL(string: "https://console.anthropic.com/settings/keys")!
            )

            credentialSection(
                provider: .openAI,
                isConfigured: model.hasOpenAIKey,
                draft: $model.openAIKeyDraft,
                keyURL: URL(string: "https://platform.openai.com/api-keys")!
            )

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
        .frame(width: 500, height: 640)
        .alert("Start a new conversation?", isPresented: $isConfirmingProviderChange) {
            Button("Cancel", role: .cancel) {
                pendingProvider = nil
            }
            Button("Switch Provider") {
                if let pendingProvider {
                    model.selectProvider(pendingProvider)
                }
                pendingProvider = nil
            }
        } message: {
            Text("Naiku will clear the current chat before using another provider.")
        }
    }

    private var providerSelection: Binding<ChatProviderID> {
        Binding(
            get: { model.activeProvider },
            set: { provider in
                guard provider != model.activeProvider else { return }
                pendingProvider = provider
                isConfirmingProviderChange = true
            }
        )
    }

    @ViewBuilder
    private func credentialSection(
        provider: ChatProviderID,
        isConfigured: Bool,
        draft: Binding<String>,
        keyURL: URL
    ) -> some View {
        Section("\(provider.displayName) API Key") {
            HStack {
                Label(
                    isConfigured ? "Configured" : "Not configured",
                    systemImage: isConfigured ? "checkmark.circle.fill" : "circle"
                )
                .foregroundStyle(isConfigured ? Color.green : Color.secondary)
                Spacer()
                Link("Create a key", destination: keyURL)
            }

            SecureField(isConfigured ? "Paste a replacement key" : "Paste API key", text: draft)

            HStack {
                Button(isConfigured ? "Replace Key" : "Save Key") {
                    model.saveKey(for: provider)
                }
                .disabled(draft.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if isConfigured {
                    Button("Remove", role: .destructive) {
                        model.deleteKey(for: provider)
                    }
                }
            }
        }
    }
}
