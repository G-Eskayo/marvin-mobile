import MarvinCore
import SwiftUI

/// The one continuous Thread (ADR 0044): history from the backend, plus Chat.
struct ThreadView: View {
    @Environment(AppModel.self) private var model
    @State private var draft = ""
    @FocusState private var composing: Bool

    var body: some View {
        Page(title: "MARVIN") {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            // The banner already explains offline / not-allowlisted; don't say it twice.
                            if let error = model.threadError, model.messages.isEmpty, model.connection.status == .online {
                                Text(error).font(.footnote).foregroundStyle(Theme.muted)
                            }
                            ForEach(model.messages) { message in
                                Bubble(text: message.text, isUser: message.role == .user)
                            }
                            if let reply = model.streaming {
                                if reply.text.isEmpty {
                                    TypingIndicator()
                                } else {
                                    Bubble(text: reply.text, isUser: false)
                                }
                            }
                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .padding()
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .defaultScrollAnchor(.bottom)
                    .onChange(of: model.messages.count) { proxy.scrollTo("bottom") }
                    .onChange(of: model.streaming?.text) { proxy.scrollTo("bottom") }
                }
                composer
            }
            .task {
                await model.loadThread()
                // `-demoPrompt "<text>"` (demo mode only): send on launch, to screenshot the typing indicator.
                if model.isDemo, let prompt = UserDefaults.standard.string(forKey: "demoPrompt") {
                    await model.send(prompt)
                }
            }
            .refreshable { await model.loadThread() }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Message MARVIN", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .focused($composing)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Theme.card, in: .rect(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border))
            Button {
                let text = draft
                draft = ""
                Task { await model.send(text) }
            } label: {
                Image(systemName: "arrow.up.circle.fill").font(.system(size: 34))
            }
            .tint(Theme.selected)
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isSending)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Theme.background)
    }
}

private struct Bubble: View {
    let text: String
    let isUser: Bool

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 48) }
            Text(text)
                .textSelection(.enabled)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .foregroundStyle(.white)
                .background(isUser ? Theme.selected : Theme.raised, in: .rect(cornerRadius: 18))
            if !isUser { Spacer(minLength: 48) }
        }
    }
}
