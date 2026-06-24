import SwiftUI
import UserNotifications

/// Первый запуск: шаг 1 — разрешения, шаг 2 — пошаговый гайд (в стиле Apple).
struct OnboardingView: View {
    @ObservedObject var state: AppState
    var onFinish: () -> Void

    @State private var page = 0
    @State private var notifGranted = false
    @State private var loginOn = false
    @State private var clamshellOn = false

    // Пуллим статусы, чтобы зелёная галочка появлялась после выдачи доступа
    // (в т.ч. если разрешение дали в Системных настройках).
    private let ticker = Timer.publish(every: 1.2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            if page == 0 { permissionsPage } else { guidePage }

            // Точки-индикаторы страниц
            HStack(spacing: 6) {
                ForEach(0..<2) { i in
                    Circle().fill(i == page ? Color.white : Color.white.opacity(0.25))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.bottom, 18)
        }
        .frame(width: 440, height: 600)
        .background(
            LinearGradient(colors: [Color(red: 0.13, green: 0.14, blue: 0.17),
                                    Color(red: 0.08, green: 0.08, blue: 0.10)],
                           startPoint: .top, endPoint: .bottom))
        .preferredColorScheme(.dark)
        .onAppear { refreshStatuses() }
        .onReceive(ticker) { _ in refreshStatuses() }
    }

    // MARK: Страница 1 — разрешения

    private var permissionsPage: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Image(nsImage: appIcon)
                    .resizable().frame(width: 84, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                Text("Welcome to \(Brand.appName)").font(.system(size: 22, weight: .bold))
                Text("Keeps your Mac awake while your AI agents work — even with the lid closed.")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 30).padding(.horizontal, 32)

            VStack(spacing: 12) {
                permissionRow(icon: "bell.badge", title: "Notifications",
                    subtitle: "So Vigil can tell you when it pauses or stops on low battery.",
                    done: notifGranted, action: requestNotifications)
                permissionRow(icon: "power", title: "Launch at login",
                    subtitle: "Start Vigil automatically and stay out of your way.",
                    done: loginOn,
                    action: { state.setLaunchAtLogin(true); loginOn = state.launchAtLogin })
                permissionRow(icon: "macbook.and.iphone", title: "Lid-closed wake on battery",
                    subtitle: "Optional. Enter your admin password once so the switch can keep the Mac awake with the lid shut on battery.",
                    done: clamshellOn || state.clamshellSupported, optional: true,
                    action: { state.grantClamshell(); clamshellOn = state.clamshellSupported })
            }
            .padding(24)

            Spacer(minLength: 0)

            Button(action: { withAnimation { page = 1 } }) {
                Text("Continue")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity).padding(.vertical, 9)
            }
            .buttonStyle(.borderedProminent).tint(Brand.accent)
            .padding(.horizontal, 32).padding(.bottom, 14)
        }
    }

    // MARK: Страница 2 — пошаговый гайд

    private var guidePage: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("How \(Brand.appName) works").font(.system(size: 22, weight: .bold))
                Text("Three things to know.").font(.system(size: 13)).foregroundStyle(.secondary)
            }
            .padding(.top, 34)

            VStack(spacing: 18) {
                guideStep(icon: "eye", tint: Brand.accent,
                    title: "It lives in your menu bar",
                    text: "Click the eye to open Vigil, pause it, or flip the switch by hand.")
                guideStep(icon: "bolt.fill", tint: Brand.good,
                    title: "It wakes your Mac automatically",
                    text: "While Claude Code, Codex or another agent is running, Vigil keeps your Mac awake — then lets it sleep when they finish.")
                guideStep(icon: "macbook.and.iphone", tint: .orange,
                    title: "Close the lid, keep working",
                    text: "On battery it stays awake with the lid shut while an agent works. Turn the switch off and your Mac sleeps as usual.")
            }
            .padding(.horizontal, 28).padding(.top, 22)

            Spacer(minLength: 0)

            Button(action: onFinish) {
                Text("Get Started")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity).padding(.vertical, 9)
            }
            .buttonStyle(.borderedProminent).tint(Brand.accent)
            .padding(.horizontal, 32).padding(.bottom, 14)
        }
    }

    // MARK: Кусочки UI

    private func permissionRow(icon: String, title: String, subtitle: String,
                               done: Bool, optional: Bool = false,
                               action: @escaping () -> Void) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon).font(.system(size: 18)).frame(width: 30)
                .foregroundStyle(done ? Brand.good : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if done {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20)).foregroundStyle(Brand.good)
            } else {
                Button("Allow", action: action).buttonStyle(.bordered)
            }
        }
        .padding(13)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }

    private func guideStep(icon: String, tint: Color, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(tint.opacity(0.18)).frame(width: 44, height: 44)
                Image(systemName: icon).font(.system(size: 20, weight: .semibold)).foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 15, weight: .semibold))
                Text(text).font(.system(size: 12)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Логика

    private func requestNotifications() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { s in
            switch s.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { ok, _ in
                    DispatchQueue.main.async { notifGranted = ok }
                }
            case .denied:
                DispatchQueue.main.async {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                        NSWorkspace.shared.open(url)
                    }
                }
            default:
                DispatchQueue.main.async { notifGranted = true }
            }
        }
    }

    private func refreshStatuses() {
        loginOn = state.launchAtLogin
        clamshellOn = state.clamshellSupported
        UNUserNotificationCenter.current().getNotificationSettings { s in
            DispatchQueue.main.async { notifGranted = (s.authorizationStatus == .authorized) }
        }
    }

    private var appIcon: NSImage {
        NSApp.applicationIconImage ?? NSImage(systemSymbolName: "eye.fill", accessibilityDescription: nil)!
    }
}
