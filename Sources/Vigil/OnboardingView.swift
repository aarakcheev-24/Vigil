import SwiftUI
import UserNotifications

/// Первый запуск: приветствие + запрос разрешений (как в Bartender).
/// Окно ждёт, пока пользователь выдаст доступы и нажмёт «Continue» → открывает Settings.
struct OnboardingView: View {
    @ObservedObject var state: AppState
    var onFinish: () -> Void

    @State private var notifGranted = false
    @State private var loginOn = false
    @State private var clamshellOn = false

    var body: some View {
        VStack(spacing: 0) {
            // Шапка
            VStack(spacing: 10) {
                Image(nsImage: appIcon)
                    .resizable().frame(width: 84, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                Text("Welcome to \(Brand.appName)").font(.system(size: 22, weight: .bold))
                Text("Keeps your Mac awake while your AI agents work — even with the lid closed.")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 30).padding(.horizontal, 32)

            // Шаги-разрешения
            VStack(spacing: 12) {
                permissionRow(
                    icon: "bell.badge",
                    title: "Notifications",
                    subtitle: "So Vigil can tell you when it pauses or stops on low battery.",
                    done: notifGranted,
                    action: requestNotifications)

                permissionRow(
                    icon: "power",
                    title: "Launch at login",
                    subtitle: "Start Vigil automatically and stay out of your way.",
                    done: loginOn,
                    action: { state.setLaunchAtLogin(true); loginOn = state.launchAtLogin })

                permissionRow(
                    icon: "macbook.and.iphone",
                    title: "Lid-closed wake on battery",
                    subtitle: "Optional. Asks for your admin password once, then never again.",
                    done: clamshellOn || state.clamshellSupported,
                    optional: true,
                    action: { state.setForceClamshell(true); clamshellOn = state.clamshellSupported })
            }
            .padding(24)

            Spacer(minLength: 0)

            // Низ
            VStack(spacing: 8) {
                Button(action: onFinish) {
                    Text("Continue to Settings")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                }
                .buttonStyle(.borderedProminent)
                .tint(Brand.accent)

                Text("You can change all of this later in Settings.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32).padding(.bottom, 24)
        }
        .frame(width: 440, height: 600)
        .background(
            LinearGradient(colors: [Color(red: 0.13, green: 0.14, blue: 0.17),
                                    Color(red: 0.08, green: 0.08, blue: 0.10)],
                           startPoint: .top, endPoint: .bottom))
        .preferredColorScheme(.dark)
        .onAppear { refreshStatuses() }
    }

    private func permissionRow(icon: String, title: String, subtitle: String,
                               done: Bool, optional: Bool = false,
                               action: @escaping () -> Void) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .frame(width: 30)
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
                Button(optional ? "Allow" : "Allow", action: action)
                    .buttonStyle(.bordered)
            }
        }
        .padding(13)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }

    private func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { ok, _ in
            DispatchQueue.main.async { notifGranted = ok }
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
