import SwiftUI

struct CloneView: View {
    @ObservedObject var model: CloneModel
    let reveal: () -> Void
    let openTerminal: () -> Void
    let close: () -> Void
    @FocusState private var urlFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Clone a repository").font(.headline)
                    Text(model.parent.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                TextField("https://github.com/owner/repo.git or git@github.com:owner/repo.git", text: $model.url)
                    .textFieldStyle(.roundedBorder)
                    .focused($urlFocused)
                    .onSubmit { model.start() }
                HStack {
                    Text("Folder").foregroundStyle(.secondary).frame(width: 44, alignment: .leading)
                    TextField(model.defaultName.isEmpty ? "repo" : model.defaultName, text: $model.customName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { model.start() }
                }
            }
            .disabled(model.running)
            if let problem = model.problem {
                Label(problem, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            logPane
            statusLine
            buttons
        }
        .padding(20)
        .frame(width: 560)
        .onAppear { urlFocused = true }
    }

    private var logPane: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(model.log.text.isEmpty ? "git output appears here" : model.log.text)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(model.log.text.isEmpty ? .tertiary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                    Color.clear.frame(height: 1).id("end")
                }
                .padding(8)
            }
            .onChange(of: model.log.text) { _ in proxy.scrollTo("end", anchor: .bottom) }
        }
        .frame(height: 190)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder private var statusLine: some View {
        switch model.state {
        case .running:
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: model.fraction)
                Text(model.phase.isEmpty ? "Starting…" : model.phase).font(.caption).foregroundStyle(.secondary)
                Label("You can close this window. The clone keeps going in the menu bar.", systemImage: "menubar.arrow.up.rectangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .done:
            Label("Cloned into \(model.folderName)", systemImage: "checkmark.circle.fill")
                .font(.callout).foregroundStyle(.green)
        case .failed(let message):
            Label(message, systemImage: "xmark.octagon.fill")
                .font(.callout).foregroundStyle(.red).lineLimit(2)
        case .idle:
            EmptyView()
        }
    }

    private var buttons: some View {
        HStack {
            Spacer()
            switch model.state {
            case .running:
                Button("Stop") { model.cancel() }
            case .done:
                Button("Reveal in Finder", action: reveal)
                Button("Open in Terminal", action: openTerminal)
                Button("Done", action: close).keyboardShortcut(.defaultAction)
            case .idle, .failed:
                Button("Close", action: close).keyboardShortcut(.cancelAction)
                Button("Clone") { model.start() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.canStart)
            }
        }
    }
}
