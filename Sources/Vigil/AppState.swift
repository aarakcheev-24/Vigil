import SwiftUI
import Combine
import UserNotifications
import ServiceManagement

enum AwakeMode: String {
    case manual   // включено пользователем тумблером
    case auto     // включается само, пока работает агент
}

final class AppState: ObservableObject {
    // Настройки (с сохранением)
    @AppStorage("autoMode")       var autoMode = true
    @AppStorage("batteryFloor")   var batteryFloor = 15        // %
    @AppStorage("notifyOnPause")  var notifyOnPause = true

    // Состояние
    @Published var isAwake = false
    /// Ручное включение тумблером — имеет приоритет над авто-режимом, не гаснет само.
    @Published var manualOn = false
    /// Ручное выключение тумблером — подавляет авто-режим, пока идут текущие сессии.
    /// Сбрасывается, когда все агенты простаивают (следующая новая сессия снова включит авто).
    @Published var autoSuppressed = false
    @Published var battery = BatterySnapshot(percent: -1, isCharging: false, onAC: true, hasBattery: false)
    @Published var agents: [AgentStatus] = []
    @Published var startedAt: Date? = nil
    @Published var pausedUntil: Date? = nil
    @Published var now = Date()

    private let power = PowerManager()
    private let monitor = AgentMonitor()
    private var timer: Timer?

    var workingAgents: [AgentStatus] { agents.filter { $0.isActive } }
    var totalSessions: Int { agents.reduce(0) { $0 + $1.sessions } }

    var statusLine: String {
        if let until = pausedUntil, until > now {
            let mins = Int(until.timeIntervalSince(now) / 60) + 1
            return "Paused — \(mins)m left"
        }
        if isAwake {
            return "Awake — lid-proof · \(elapsedString)"
        }
        if autoSuppressed { return "Off — you turned it off" }
        return autoMode ? "Auto — sleeps when idle" : "Asleep — sleep allowed"
    }

    var elapsedString: String {
        guard let s = startedAt else { return "0m 0s" }
        let secs = max(0, Int(now.timeIntervalSince(s)))
        let h = secs / 3600, m = (secs % 3600) / 60, sec = secs % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m \(sec)s"
    }

    private var tick = 0

    func boot() {
        // Разрешение на уведомления НЕ просим здесь — иначе системный диалог
        // съедается до онбординга и кнопка Allow потом «ничего не делает».
        power.syncOffAtLaunch()   // сбросить возможный залипший запрет сна
        refresh()
        // Тик раз в секунду — таймер идёт плавно. Тяжёлый скан (ps/батарея) — раз в 5 сек.
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.now = Date()
            self.tick += 1
            if self.tick % 5 == 0 { self.refresh() }
        }
        RunLoop.main.add(t, forMode: .common)   // .common — работает и при открытом попапе
        timer = t
    }

    // MARK: - Управление

    func toggle() {
        if isAwake {
            manualOn = false
            autoSuppressed = true    // явно выключили — авто-режим не включит обратно
            stopAwake()
        } else {
            manualOn = true          // ручной приоритет — авто-режим не погасит
            autoSuppressed = false
            pausedUntil = nil
            startAwake()
        }
    }

    func pause(minutes: Int) {
        manualOn = false
        pausedUntil = Date().addingTimeInterval(Double(minutes) * 60)
        stopAwake()
        notify("Paused for \(minutes >= 60 ? "\(minutes/60)h" : "\(minutes)m")",
               "\(Brand.appName) won't keep your Mac awake until then.")
    }

    private func startAwake() {
        power.start(lidProof: true,
                    reason: "\(Brand.appName): \(totalSessions) agent session(s) running")
        isAwake = true
        if startedAt == nil { startedAt = Date() }
    }

    private func stopAwake() {
        power.stop()
        isAwake = false
        startedAt = nil
    }

    // MARK: - Опрос

    func refresh() {
        now = Date()
        battery = BatteryMonitor.read()
        agents = monitor.scan()

        // снять паузу по истечении
        if let until = pausedUntil, until <= now { pausedUntil = nil }

        // авто-стоп по низкому заряду (батарея, не на зарядке) — перебивает даже ручной режим
        if isAwake, battery.hasBattery, !battery.onAC, battery.percent >= 0,
           battery.percent <= batteryFloor {
            manualOn = false
            stopAwake()
            pausedUntil = Date().addingTimeInterval(300) // не дёргаться 5 минут
            notify("Stopped — battery \(battery.percent)%",
                   "Below your \(batteryFloor)% floor. Plug in to keep going.")
            return
        }

        guard pausedUntil == nil else { return }

        if manualOn {
            // ручной приоритет: держим бодрым независимо от агентов
            if !isAwake { startAwake() }
        } else if autoMode && !autoSuppressed {
            // авто-режим: бодрствуем, пока есть рабочие агенты.
            // Выключили вручную (autoSuppressed) — авто молчит до ручного включения.
            let working = totalSessions > 0
            if working && !isAwake { startAwake() }
            else if !working && isAwake { stopAwake() }
        }

        // pmset clamshell привязан К ТУМБЛЕРУ: запрет сна с закрытой крышкой действует,
        // только пока Vigil реально держит Mac бодрым (isAwake) и мы на батарее.
        // Тумблер выключен → disablesleep=0 → крышка закрыта → Mac спит как обычно.
        let wantClamshell = isAwake && battery.hasBattery && !battery.onAC
        power.setClamshell(wantClamshell)
    }

    var clamshellSupported: Bool { power.clamshellSupported }

    // MARK: - Автозапуск при логине

    var launchAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() }
            else  { try SMAppService.mainApp.unregister() }
        } catch {
            notify("Login item failed", error.localizedDescription)
        }
        objectWillChange.send()
    }

    /// Разовая выдача доступа к clamshell (онбординг): один раз пароль админа → sudoers.
    /// Дальше запрет сна включается/выключается вместе с тумблером без паролей.
    @discardableResult
    func grantClamshell() -> Bool {
        power.installClamshellSupport()
    }

    /// Вызывается при выходе — снимает запрет сна.
    func shutdown() {
        power.shutdown()
    }

    private func notify(_ title: String, _ body: String) {
        guard notifyOnPause else { return }
        let c = UNMutableNotificationContent()
        c.title = title
        c.body = body
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil)
        )
    }
}
