import SwiftUI

struct TranslateView: View {
    @ObservedObject var model: TranslateModel
    let copy: () -> Void
    let save: () -> Void
    let reveal: () -> Void
    let openSettings: () -> Void
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "character.bubble.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Translate").font(.headline)
                    Text(model.file.lastPathComponent).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            HStack {
                Picker("To", selection: $model.language) {
                    ForEach(TranslateLanguage.common) { Text($0.name).tag($0) }
                    Divider()
                    Text(TranslateLanguage.custom.name).tag(TranslateLanguage.custom)
                }
                .frame(width: 260)
                if model.language == .custom {
                    TextField("Language, e.g. Tagalog", text: $model.customName).textFieldStyle(.roundedBorder)
                }
                Spacer()
            }
            .disabled(model.translating)
            pane
            statusLine
            buttons
        }
        .padding(20)
        .frame(width: 640)
    }

    private var pane: some View {
        let showingResult = !model.result.isEmpty
        return VStack(alignment: .leading, spacing: 4) {
            Text(showingResult ? (model.translating ? "Translation (so far)" : "Translation") : "Source")
                .font(.caption).foregroundStyle(.secondary)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(showingResult ? model.result : String((model.source ?? "").prefix(4000)))
                            .font(.system(size: 12))
                            .foregroundStyle(showingResult ? .primary : .secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                        Color.clear.frame(height: 1).id("end")
                    }
                    .padding(8)
                }
                // follow the translation as it grows
                .onChange(of: model.result) { _ in
                    if model.translating { proxy.scrollTo("end", anchor: .bottom) }
                }
            }
            .frame(height: 280)
            .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder private var statusLine: some View {
        switch model.state {
        case .translating(let done, let total):
            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: Double(done), total: Double(max(total, 1)))
                HStack {
                    Text("Part \(min(done + 1, total)) of \(total)  ·  \(Int(Double(done) / Double(max(total, 1)) * 100))%")
                    Spacer()
                    timing(done: done, total: total)
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                if !model.note.isEmpty {
                    Label(model.note, systemImage: "hourglass").font(.caption).foregroundStyle(.orange)
                }
                Label("You can close this window. The translation keeps going in the menu bar and is saved beside the file.",
                      systemImage: "menubar.arrow.up.rectangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .done:
            if let saved = model.savedURL {
                Label("Saved as \(saved.lastPathComponent)", systemImage: "checkmark.circle.fill")
                    .font(.callout).foregroundStyle(.green)
            }
        case .failed(let message):
            HStack {
                Label(message, systemImage: "xmark.octagon.fill").font(.callout).foregroundStyle(.red).lineLimit(3)
                if model.missingKey { Button("Open Settings", action: openSettings) }
            }
        case .idle:
            EmptyView()
        }
    }

    private func timing(done: Int, total: Int) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = context.date.timeIntervalSince(model.startedAt ?? context.date)
            let left = done > 0 ? elapsed / Double(done) * Double(total - done) : nil
            Text(left.map { "\(Self.clock(elapsed)) elapsed  ·  about \(Self.clock($0)) left" } ?? "\(Self.clock(elapsed)) elapsed")
        }
    }

    private static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private var buttons: some View {
        HStack {
            Spacer()
            Button("Close", action: close).keyboardShortcut(.cancelAction)
            if model.translating {
                Button("Stop") { model.cancel() }
            } else {
                if model.state == .done {
                    Button("Copy", action: copy)
                    if model.savedURL == nil {
                        Button("Save", action: save)
                    } else {
                        Button("Reveal", action: reveal)
                    }
                }
                Button(model.state == .done ? "Translate again" : "Translate") { model.start() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.canStart)
            }
        }
    }
}
