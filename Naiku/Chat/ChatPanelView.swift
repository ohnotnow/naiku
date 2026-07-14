import SwiftUI

struct ChatPanelView: View {
    @ObservedObject var session: ChatSessionModel
    let onOpenSettings: @MainActor () -> Void
    let onCloseRequest: @MainActor () -> Void

    @FocusState private var isInputFocused: Bool

    private static let panelShape = RoundedRectangle(cornerRadius: 32, style: .continuous)

    var body: some View {
        VStack(spacing: 0) {
            header
            transcript
            composer
        }
        .fontDesign(.rounded)
        .frame(minWidth: 340, idealWidth: 380, minHeight: 500, idealHeight: 640)
        .clipShape(Self.panelShape)
        .glassEffect(.regular, in: Self.panelShape)
        .onAppear { isInputFocused = true }
        .onChange(of: session.focusRequest) { _, _ in
            isInputFocused = true
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button("Close", systemImage: "xmark") {
                onCloseRequest()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.small)
            .help("Close chat")
            .keyboardShortcut("w", modifiers: [.command])

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
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .help("New conversation")
            .keyboardShortcut("n", modifiers: [.command])
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 10)
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
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
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
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.thinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(.quaternary))
                    .focused($isInputFocused)
                    .disabled(session.isSending)
                    .onSubmit { session.send() }
                    .accessibilityLabel("Message Naiku")

                if session.isSending {
                    Button("Stop", systemImage: "stop.fill") {
                        session.cancel()
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .help("Stop generating")
                    .keyboardShortcut(.cancelAction)
                } else {
                    Button("Send", systemImage: "arrow.up") {
                        session.send()
                    }
                    .labelStyle(.iconOnly)
                    .fontWeight(.bold)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.circle)
                    .tint(NaikuChatStyle.userBubbleColor)
                    .help("Send message (Return)")
                    .disabled(session.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            Text("Return sends")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }
}

/// Shared colours for the chat's cutesy look. Both bubbles use fixed colours
/// rather than adaptive tints so they stay warm and high-contrast on top of
/// the glass, whatever is behind the window.
private enum NaikuChatStyle {
    static let userBubbleColor = Color(red: 0.83, green: 0.29, blue: 0.45)
    static let assistantBubbleColor = Color(red: 1.0, green: 0.78, blue: 0.52)
    static let assistantTextColor = Color(red: 0.29, green: 0.18, blue: 0.05)
}

private struct MessageBubble: View {
    let message: ChatMessage

    private var isAssistant: Bool { message.role == .assistant }

    var body: some View {
        HStack {
            if isAssistant {
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
            .foregroundStyle(isAssistant ? NaikuChatStyle.assistantTextColor : Color.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(background)
            .clipShape(shape)
    }

    private var background: some View {
        Rectangle().fill(
            (isAssistant ? NaikuChatStyle.assistantBubbleColor : NaikuChatStyle.userBubbleColor).gradient
        )
    }

    /// iMessage-style bubbles: fully rounded except a smaller "tail" corner
    /// on the side the speaker sits.
    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 20,
            bottomLeadingRadius: isAssistant ? 6 : 20,
            bottomTrailingRadius: isAssistant ? 20 : 6,
            topTrailingRadius: 20,
            style: .continuous
        )
    }
}
