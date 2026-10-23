import SwiftUI

// one colour per wheel, used everywhere so a glance tells which hotkey an action lives on
extension WheelKind {
    var tint: Color {
        switch self {
        case .shift: return .blue
        case .command: return .purple
        case .control: return .orange
        }
    }

    var title: String {
        switch self {
        case .shift: return "Shift"
        case .command: return "Command"
        case .control: return "Control"
        }
    }

    var purpose: String {
        switch self {
        case .shift: return "Convert"
        case .command: return "Tools"
        case .control: return "File"
        }
    }

    var keySymbol: String {
        switch self {
        case .shift: return "shift"
        case .command: return "command"
        case .control: return "control"
        }
    }
}

enum SettingsLayout {
    static let width: CGFloat = 960
    static let sidebar: CGFloat = 200
    static let preview: CGFloat = 300
}

struct SettingsTools {
    let openActions: () -> Void
    let reload: () -> Void
    let openPacksFolder: () -> Void
}

private enum SettingsPage: Hashable {
    case wheel(WheelKind)
    case packs
}

struct SettingsView: View {
    @ObservedObject var registry: ActionRegistry
    let tools: SettingsTools
    @State private var page: SettingsPage

    // tab: "shift", "command", "control" or "packs"
    init(registry: ActionRegistry, tab: String? = nil, tools: SettingsTools) {
        self.registry = registry
        self.tools = tools
        let page: SettingsPage = tab == "packs" ? .packs : .wheel(WheelKind(rawValue: tab ?? "") ?? .shift)
        _page = State(initialValue: page)
    }

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(registry: registry, page: $page, tools: tools)
                .frame(width: SettingsLayout.sidebar)
            Divider()
            Group {
                switch page {
                case .wheel(let kind): WheelPage(registry: registry, wheel: kind).id(kind)
                case .packs: PacksPage(registry: registry, openPacksFolder: tools.openPacksFolder)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: SettingsLayout.width)
        .frame(minHeight: 580, idealHeight: 640)
    }
}

// MARK: sidebar

private struct SettingsSidebar: View {
    @ObservedObject var registry: ActionRegistry
    @Binding var page: SettingsPage
    let tools: SettingsTools

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("WHEELS").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                .padding(.horizontal, 10).padding(.top, 4)
            ForEach([WheelKind.shift, .command, .control], id: \.self) { kind in
                let all = registry.actions.filter { $0.wheel == kind }
                let on = all.filter { !registry.hidden.contains($0.id) }.count
                SidebarRow(symbol: kind.keySymbol, tint: kind.tint, title: kind.title, subtitle: kind.purpose,
                           trailing: "\(on)/\(all.count)", selected: page == .wheel(kind)) { page = .wheel(kind) }
                    .help("\(on) of \(all.count) \(kind.title) actions are on")
            }
            Text("LIBRARY").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                .padding(.horizontal, 10).padding(.top, 14)
            SidebarRow(symbol: "shippingbox", tint: .indigo, title: "Packs", subtitle: "Extra actions",
                       trailing: "\(registry.enabledPacks.count)/\(registry.packs.count)", selected: page == .packs) { page = .packs }
            Spacer()
            VStack(alignment: .leading, spacing: 6) {
                Button { tools.openActions() } label: { Label("Open actions.json", systemImage: "doc.badge.gearshape") }
                Button { tools.reload() } label: { Label("Reload actions", systemImage: "arrow.clockwise") }
            }
            .buttonStyle(.borderless)
            .font(.callout)
            .padding(10)
        }
        .padding(10)
        .background(.regularMaterial)
    }
}

private struct SidebarRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let subtitle: String
    let trailing: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(tint.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(.callout.weight(.medium))
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(trailing).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(selected ? Color.accentColor.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: wheel page

private struct PreviewSample: Identifiable, Hashable {
    let title: String
    let ext: String
    var id: String { ext }

    static let all = [
        PreviewSample(title: "Image (png)", ext: "png"), PreviewSample(title: "Video (mp4)", ext: "mp4"),
        PreviewSample(title: "Audio (mp3)", ext: "mp3"), PreviewSample(title: "PDF", ext: "pdf"),
        PreviewSample(title: "Text (txt)", ext: "txt"), PreviewSample(title: "JSON", ext: "json"),
    ]
}

private struct WheelPage: View {
    @ObservedObject var registry: ActionRegistry
    let wheel: WheelKind
    @State private var search = ""
    @State private var filter: FileKind?
    @State private var sample = PreviewSample.all[0]

    private var actions: [WheelAction] { registry.actions.filter { $0.wheel == wheel } }

    private var on: Int { actions.filter { !registry.hidden.contains($0.id) }.count }

    private var filtered: [WheelAction] {
        actions.filter { action in
            (filter.map { FileKind.kinds(for: action.accepts).contains($0) } ?? true)
                && (search.isEmpty || [action.label, action.description ?? "", action.id, action.accepts.joined(separator: " ")]
                    .contains { $0.localizedCaseInsensitiveContains(search) })
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                header
                controls
                if filtered.isEmpty {
                    Text(actions.isEmpty ? "No actions on this wheel" : "No actions match")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(filtered) { action in
                                ActionRow(action: action, origin: registry.origin(of: action),
                                          visible: !registry.hidden.contains(action.id)) {
                                    registry.setHidden(action.id, !registry.hidden.contains(action.id))
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            Divider()
            PreviewPane(registry: registry, wheel: wheel, sample: $sample)
                .frame(width: SettingsLayout.preview)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: wheel.keySymbol)
                .font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(wheel.tint.gradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(wheel.title) · \(wheel.purpose)").font(.title2.weight(.semibold))
                Text("Hold \(wheel.title) while dragging a file. A wheel shows the first \(ActionRegistry.maxPerWheel) actions that fit the file, in the order below.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search actions", text: $search).textFieldStyle(.plain)
                if !search.isEmpty {
                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).foregroundStyle(.secondary)
                }
            }
            .padding(8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text("\(on) of \(actions.count) actions on" + (filtered.count == actions.count ? "" : " · showing \(filtered.count)"))
                .font(.caption).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    FilterChip(title: "All", symbol: nil, selected: filter == nil) { filter = nil }
                    ForEach(FileKind.allCases) { kind in
                        FilterChip(title: kind.shortTitle, symbol: kind.symbol, selected: filter == kind) { filter = filter == kind ? nil : kind }
                    }
                }
            }
        }
    }
}

private struct FilterChip: View {
    let title: String
    let symbol: String?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let symbol { Image(systemName: symbol).font(.system(size: 10)) }
                Text(title).font(.caption).lineLimit(1)
            }
            .fixedSize()
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(selected ? Color.accentColor : Color.primary.opacity(0.08), in: Capsule())
            .foregroundStyle(selected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: rows

private struct ActionRow: View {
    let action: WheelAction
    let origin: ActionOrigin
    let visible: Bool
    let toggle: () -> Void

    private var kinds: [FileKind] { FileKind.kinds(for: action.accepts) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: ActionIcon.symbol(for: action))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(action.wheel.tint.gradient, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(action.label).font(.headline)
                    OriginBadge(origin: origin)
                }
                if let description = action.description {
                    Text(description).font(.callout).foregroundStyle(.secondary)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 5) {
                    ForEach(kinds) { KindChip(kind: $0) }
                    if kinds != [.any] {
                        Text(action.accepts.joined(separator: " "))
                            .font(.caption2).foregroundStyle(.tertiary).lineLimit(1).truncationMode(.tail)
                            .layoutPriority(-1)
                    }
                }
            }
            Spacer(minLength: 8)
            Toggle("", isOn: Binding(get: { visible }, set: { _ in toggle() }))
                .toggleStyle(.switch).labelsHidden()
                .help(visible ? "Shown on the wheel" : "Hidden from the wheel")
        }
        .padding(10)
        .background(Color.primary.opacity(visible ? 0.05 : 0.02), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(visible ? action.wheel.tint.opacity(0.35) : Color.primary.opacity(0.06), lineWidth: 1))
        .opacity(visible ? 1 : 0.55)
    }
}

private struct KindChip: View {
    let kind: FileKind

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: kind.symbol).font(.system(size: 9))
            Text(kind.shortTitle).font(.caption2).lineLimit(1)
        }
        .fixedSize()
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(Color.primary.opacity(0.08), in: Capsule())
        .foregroundStyle(.secondary)
    }
}

private struct OriginBadge: View {
    let origin: ActionOrigin

    private var tint: Color {
        switch origin {
        case .builtIn: return .gray
        case .custom: return .teal
        case .pack: return .indigo
        }
    }

    var body: some View {
        Text(origin.label)
            .font(.system(size: 9, weight: .semibold))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(tint.opacity(0.18), in: Capsule())
            .foregroundStyle(tint)
    }
}

// MARK: preview

private struct PreviewPane: View {
    @ObservedObject var registry: ActionRegistry
    let wheel: WheelKind
    @Binding var sample: PreviewSample

    private var files: [URL] { [URL(fileURLWithPath: "/preview/sample.\(sample.ext)")] }
    // every action that is on for this wheel splits into: on the wheel, cut by the limit, or not for this file type
    private var on: [WheelAction] { registry.actions.filter { $0.wheel == wheel && !registry.hidden.contains($0.id) } }
    private var usable: [WheelAction] { registry.usableActions(for: wheel, files: files) }
    private var shown: [WheelAction] { Array(usable.prefix(ActionRegistry.maxPerWheel)) }
    private var cut: [WheelAction] { Array(usable.dropFirst(ActionRegistry.maxPerWheel)) }
    private var elsewhere: [WheelAction] { on.filter { action in !usable.contains { $0.id == action.id } } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wheel preview").font(.headline)
            Picker("File", selection: $sample) {
                ForEach(PreviewSample.all) { Text($0.title).tag($0) }
            }
            .labelsHidden()
            Group {
                if shown.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "circle.dashed").font(.largeTitle).foregroundStyle(.tertiary)
                        Text("Nothing on \(wheel.title) for this file type").font(.callout).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(height: 230)
                } else {
                    WheelPreview(actions: shown).id(shown.map(\.id))
                }
            }
            .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(shown.count) of \(ActionRegistry.maxPerWheel) slots used").font(.callout.weight(.medium))
                Text("\(on.count) on = \(shown.count) on the wheel" + (cut.isEmpty ? "" : " + \(cut.count) cut") + " + \(elsewhere.count) for other file types")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !cut.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("\(cut.count) cut by the \(ActionRegistry.maxPerWheel)-slot limit", systemImage: "exclamationmark.triangle.fill")
                        .font(.callout.weight(.medium)).foregroundStyle(.orange)
                    Text(cut.map(\.label).joined(separator: ", ")).font(.caption).foregroundStyle(.secondary)
                    Text("Turn off an action to bring these in.").font(.caption).foregroundStyle(.secondary)
                }
            }
            if !elsewhere.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Not for \(sample.title)").font(.caption.weight(.medium))
                    Text(elsewhere.map(\.label).joined(separator: ", ")).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(16)
        .background(.regularMaterial)
    }
}

// the real wheel view, scaled down; rebuilt (via .id) whenever the list of actions changes
private struct WheelPreview: View {
    let actions: [WheelAction]
    @StateObject private var state: WheelState
    private static let scale: CGFloat = 0.62

    init(actions: [WheelAction]) {
        self.actions = actions
        let state = WheelState()
        state.actions = actions
        state.shown = true
        _state = StateObject(wrappedValue: state)
    }

    var body: some View {
        let side = RadialWheelView.size(count: actions.count) * Self.scale
        RadialWheelView(state: state)
            .scaleEffect(Self.scale)
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity)
    }
}

// MARK: packs

private struct PacksPage: View {
    @ObservedObject var registry: ActionRegistry
    let openPacksFolder: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "shippingbox").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.indigo.gradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Packs").font(.title2.weight(.semibold))
                    Text("A pack adds actions from its own file, so actions.json stays yours. If both define an id, actions.json wins.")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button("Open packs folder", action: openPacksFolder)
            }
            if registry.packs.isEmpty {
                Text("No packs found").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(registry.packs) { pack in
                            PackRow(pack: pack, enabled: registry.enabledPacks.contains(pack.id)) {
                                registry.setPack(pack.id, enabled: $0)
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
    }
}

private struct PackRow: View {
    let pack: ActionPack
    let enabled: Bool
    let setEnabled: (Bool) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(pack.title).font(.headline)
                    Text(pack.bundled ? "Built in" : "Yours")
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background((pack.bundled ? Color.gray : Color.teal).opacity(0.18), in: Capsule())
                        .foregroundStyle(pack.bundled ? Color.gray : Color.teal)
                }
                if let description = pack.description {
                    Text(description).font(.callout).foregroundStyle(.secondary)
                }
                // each action is tagged with its wheel colour
                FlowChips(items: pack.actions)
            }
            Spacer()
            Toggle("", isOn: Binding(get: { enabled }, set: setEnabled)).toggleStyle(.switch).labelsHidden()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(enabled ? 0.06 : 0.03), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(enabled ? Color.indigo.opacity(0.5) : Color.primary.opacity(0.08), lineWidth: 1))
    }
}

private struct FlowChips: View {
    let items: [WheelAction]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 6, alignment: .leading)], alignment: .leading, spacing: 6) {
            ForEach(items) { action in
                HStack(spacing: 4) {
                    Image(systemName: action.wheel.keySymbol).font(.system(size: 9, weight: .bold))
                    Text(action.label).font(.caption).lineLimit(1)
                }
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(action.wheel.tint.opacity(0.16), in: Capsule())
                .foregroundStyle(action.wheel.tint)
                .help(action.description ?? action.label)
            }
        }
    }
}
