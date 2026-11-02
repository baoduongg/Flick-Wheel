import SwiftUI

struct LinesView: View {
    @ObservedObject var model: LinesModel
    let copy: () -> Void
    let close: () -> Void
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 26))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lines of code").font(.headline)
                    Text(model.folder.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }
            content
            HStack {
                if !model.scanning && !model.stats.isEmpty {
                    Text("\(model.totalLines.formatted()) lines in \(model.totalFiles.formatted()) files")
                        .font(.callout.weight(.medium))
                }
                Spacer()
                Button("Close", action: close).keyboardShortcut(.cancelAction)
                Button(copied ? "Copied" : "Copy") {
                    copy()
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(model.scanning || model.stats.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    @ViewBuilder private var content: some View {
        if model.scanning {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Counting…").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 280)
        } else if model.stats.isEmpty {
            Text("No source files found")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 280)
        } else {
            let most = Double(model.stats.first?.lines ?? 1)
            ScrollView {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    GridRow {
                        Text("Language")
                        Text("Lines").gridColumnAlignment(.trailing)
                        Text("Files").gridColumnAlignment(.trailing)
                        Text("")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    ForEach(model.stats) { stat in
                        GridRow {
                            Text(stat.name)
                            Text(stat.lines.formatted()).monospacedDigit()
                            Text(stat.files.formatted()).monospacedDigit().foregroundStyle(.secondary)
                            ProgressView(value: Double(stat.lines), total: max(most, 1)).frame(width: 110)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 280)
            .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}
