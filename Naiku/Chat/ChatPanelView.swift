import SwiftUI

struct ChatPanelView: View {
    @ObservedObject var session: ChatSessionModel
    let onOpenSettings: @MainActor () -> Void

    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            transcript
            Divider()
            composer
        }
        .frame(minWidth: 400, idealWidth: 430, minHeight: 420, idealHeight: 500)
        .background(.regularMaterial)
        .onAppear { isInputFocused = true }
        .onChange(of: session.focusRequest) { _, _ in
            isInputFocused = true
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "cat.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Naiku")
                    .font(.headline)
                Text(session.providerSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button("New Conversation", systemImage: "plus.bubble") {
                session.newConversation()
                session.requestInputFocus()
            }
            .labelStyle(.iconOnly)
            .help("New conversation")
            .keyboardShortcut("n", modifiers: [.command])
        }
        .padding(12)
    }

    private var transcript: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if session.messages.isEmpty, session.pendingMessage == nil {
                    ContentUnavailableView(
                        "A quiet little cat",
                        systemImage: "sparkles",
                        description: Text("Ask Naiku anything. Short, playful questions are especially welcome.")
                    )
                    .padding(.top, 48)
                }

                ForEach(session.messages) { message in
                    MessageBubble(message: message)
                }

                if let pending = session.pendingMessage {
                    MessageBubble(message: pending)
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Naiku is thinking…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            }
            .padding(14)
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let errorMessage = session.errorMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(errorMessage)
                        .font(.caption)
                    Spacer()
                    Button("Settings") { onOpenSettings() }
                        .controlSize(.small)
                        .keyboardShortcut(",", modifiers: [.command])
                }
            }

            HStack(spacing: 8) {
                TextField("Message Naiku", text: $session.draft)
                    .textFieldStyle(.roundedBorder)
                    .focused($isInputFocused)
                    .disabled(session.isSending)
                    .onSubmit { session.send() }
                    .accessibilityLabel("Message Naiku")

                if session.isSending {
                    Button("Stop", systemImage: "stop.fill") {
                        session.cancel()
                    }
                    .labelStyle(.iconOnly)
                    .help("Stop generating")
                    .keyboardShortcut(.cancelAction)
                } else {
                    Button("Send", systemImage: "arrow.up.circle.fill") {
                        session.send()
                    }
                    .labelStyle(.iconOnly)
                    .help("Send message (Return)")
                    .disabled(session.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            Text("Return sends")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
    }
}

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .assistant {
                bubble
                Spacer(minLength: 42)
            } else {
                Spacer(minLength: 42)
                bubble
            }
        }
    }

    private var bubble: some View {
        Text(message.text)
            .textSelection(.enabled)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(message.role == .assistant ? Color.orange.opacity(0.16) : Color.accentColor.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}
