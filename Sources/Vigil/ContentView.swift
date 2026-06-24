import SwiftUI

struct ContentView: View {
    @ObservedObject var state: AppState
    @State private var showSettings = false

    private let mono = Font.system(.caption, design: .monospaced)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            divider
            batterySection
            divider
            agentsSection
            divider
            pauseSection
            divider
            footer
        }
        .padding(18)
        .frame(width: 320)
        .background(
            LinearGradient(
                colors: [Color(red: 0.13, green: 0.13, blue: 0.15),
                         Color(red: 0.09, green: 0.09, blue: 0.10)],
                startPoint: .top, endPoint: .bottom)
        )
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) { SettingsView(state: state) }
    }

    // MARK: Header
    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Circle().fill(headerDotColor).frame(width: 8, height: 8)
                        .shadow(color: headerDotColor.opacity(0.8), radius: state.isAwake ? 4 : 0)
                    Text(Brand.appName).font(.system(size: 17, weight: .bold))
                }
                Text(state.statusLine)
                    .font(mono)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { state.isAwake },
                set: { _ in state.toggle() }
            ))
            .toggleStyle(.switch)
            .tint(Brand.accent)
            .labelsHidden()
        }
        .padding(.bottom, 14)
    }

    private var headerDotColor: Color {
        if state.pausedUntil != nil { return .orange }
        if state.isAwake { return Brand.good }
        return Color.white.opacity(0.25)
    }

    // MARK: Battery
    private var batterySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Battery").font(.system(size: 15, weight: .semibold))
            if state.battery.hasBattery {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.12))
                        Capsule().fill(barColor)
                            .frame(width: geo.size.width * CGFloat(max(0, state.battery.percent)) / 100)
                    }
                }
                .frame(height: 8)
                HStack {
                    Text("\(state.battery.percent)% left\(state.battery.isCharging ? " · charging" : "")")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("stops below \(state.batteryFloor)%")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
            } else {
                Text("On AC power — no battery").font(.system(size: 13)).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 14)
    }

    private var barColor: Color {
        if state.battery.percent <= state.batteryFloor { return .orange }
        return Brand.good
    }

    // MARK: Agents
    private var agentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Agents").font(.system(size: 15, weight: .semibold))
                Spacer()
                Text(state.totalSessions == 0 ? "idle" : "\(state.totalSessions) working")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            ForEach(state.agents) { a in
                HStack(spacing: 10) {
                    Image(systemName: a.symbol)
                        .frame(width: 20)
                        .foregroundStyle(a.isActive ? .primary : .secondary)
                    Text(a.name)
                        .font(.system(size: 14, weight: a.isActive ? .semibold : .regular))
                        .foregroundStyle(a.isActive ? .primary : .secondary)
                    Spacer()
                    if a.isActive {
                        Text("\(a.sessions) session\(a.sessions > 1 ? "s" : "")")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                        Circle().fill(Brand.good).frame(width: 7, height: 7)
                    } else {
                        Text("idle").font(.system(size: 12)).foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.vertical, 14)
    }

    // MARK: Pause
    private var pauseSection: some View {
        HStack {
            Text("Pause").font(.system(size: 15, weight: .semibold))
            Spacer()
            pauseButton("30 min", 30)
            pauseButton("1 hour", 60)
        }
        .padding(.vertical, 14)
    }

    private func pauseButton(_ title: String, _ mins: Int) -> some View {
        Button(action: { state.pause(minutes: mins) }) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
    }

    // MARK: Footer
    private var footer: some View {
        VStack(spacing: 2) {
            rowButton("Settings…", shortcut: "⌘,") { showSettings = true }
            rowButton("Quit \(Brand.appName)", shortcut: "⌘Q") { NSApp.terminate(nil) }
        }
        .padding(.top, 12)
    }

    private func rowButton(_ title: String, shortcut: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(.system(size: 14))
                Spacer()
                Text(shortcut).font(mono).foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
    }
}

struct SettingsView: View {
    @ObservedObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("\(Brand.appName) Settings").font(.title2.bold())

            Toggle("Lid-proof (stay awake with the lid closed)", isOn: $state.lidProof)
            Toggle("Auto mode (wake only while an agent is working)", isOn: $state.autoMode)
            Toggle("Notify me when it pauses", isOn: $state.notifyOnPause)

            VStack(alignment: .leading, spacing: 4) {
                Toggle("Force lid-closed wake on battery", isOn: Binding(
                    get: { state.forceClamshell },
                    set: { state.setForceClamshell($0) }
                ))
                Text(state.clamshellSupported
                     ? "Access granted ✓ — works without a password now."
                     : "Asks for your admin password once, then never again. On AC power this isn't needed.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Stop below \(state.batteryFloor)% battery")
                Slider(value: Binding(
                    get: { Double(state.batteryFloor) },
                    set: { state.batteryFloor = Int($0) }
                ), in: 5...50, step: 5).tint(Brand.accent)
            }

            Text("Tip: lid-closed wake works reliably on AC power. On battery, macOS may still sleep in clamshell.")
                .font(.caption).foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 420)
        .preferredColorScheme(.dark)
    }
}
