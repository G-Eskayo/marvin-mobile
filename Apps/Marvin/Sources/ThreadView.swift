import MarvinCore
import SwiftUI

/// The one continuous Thread (ADR 0044): history from the backend, plus Chat.
struct ThreadView: View {
    @Environment(AppModel.self) private var model
    @State private var draft = ""
    @FocusState private var composing: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ConnectionBanner()
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            if let error = model.threadError, model.messages.isEmpty {
                                Text(error).font(.footnote).foregroundStyle(.secondary)
                            }
                            ForEach(model.messages) { message in
                                Bubble(text: message.text, isUser: message.role == .user)
                            }
                            if let reply = model.streaming {
                                Bubble(text: reply.text.isEmpty ? "Thinking…" : reply.text, isUser: false)
                                    .opacity(0.7)
                            }
                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .padding()
                    }
                    .defaultScrollAnchor(.bottom)
                    .onChange(of: model.messages.count) { proxy.scrollTo("bottom") }
                    .onChange(of: model.streaming?.text) { proxy.scrollTo("bottom") }
                }
                composer
            }
            .navigationTitle("MARVIN")
            .navigationBarTitleDisplayMode(.inline)
            .task { await model.loadThread() }
            .refreshable { await model.loadThread() }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom) {
            TextField("Message MARVIN", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .focused($composing)
                .padding(10)
                .background(.fill.tertiary, in: .rect(cornerRadius: 18))
            Button {
                let text = draft
                draft = ""
                Task { await model.send(text) }
            } label: {
                Image(systemName: "arrow.up.circle.fill").font(.system(size: 32))
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isSending)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
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
                .padding(12)
                .foregroundStyle(isUser ? .white : .primary)
                .background(isUser ? AnyShapeStyle(.tint) : AnyShapeStyle(.fill.secondary), in: .rect(cornerRadius: 18))
            if !isUser { Spacer(minLength: 48) }
        }
    }
}
