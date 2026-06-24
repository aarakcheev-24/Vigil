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
    @AppStorage("lidProof")       var lidProof = true
    @AppStorage("autoMode")       var autoMode = true
    @AppStorage("batteryFloor")   var batteryFloor = 15        // %
    @AppStorage("notifyOnPause")  var notifyOnPause = true
    /// Запрет сна с закрытой крышкой НА БАТАРЕЕ через pmset (нужны права админа). По умолчанию выкл.
    @AppStorage("forceClamshell") var forceClamshell = false
    @AppStorage("menuIcon")       var menuIconRaw = MenuIcon.eye.rawValue

    var menuIcon: MenuIcon { MenuIcon(rawValue: menuIconRaw) ?? .eye }

    // Состояние
    @Published var isAwake = false
    /// Ручное включение тумблером — имеет приоритет над авто-режимом, не гаснет само.
    @Published var manualOn = false
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
            let lid = lidProof ? "lid-proof" : "screen-on"
            return "Awake — \(lid) · \(elapsedString)"
        }
        return autoMode ? "Auto — sleeps when idle" : "Asleep — sleep allowed"
    }

    var elapsedString: String {
        guard let s = startedAt else { return "0h 0m" }
        let secs = Int(now.timeIntervalSince(s))
        return "\(secs / 3600)h \((secs % 3600) / 60)m"
    }

    func boot() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    // MARK: - Управление

    func toggle() {
        if isAwake {
            manualOn = false
            stopAwake()
        } else {
            manualOn = true          // ручной приоритет — авто-режим не погасит
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
        power.start(lidProof: lidProof,
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
        } else if autoMode {
            // авто-режим: бодрствуем, пока есть рабочие агенты
            let working = totalSessions > 0
            if working && !isAwake { startAwake() }
            else if !working && isAwake { stopAwake() }
        }

        // поддерживать актуальный lid-proof, если настройку поменяли на лету
        if isAwake && power.isActive == false { startAwake() }

        // pmset clamshell — оценивается ОТДЕЛЬНО от мигания авто-режима, идемпотентно,
        // поэтому пароль не дёргается на каждый запуск/остановку агента.
        let wantClamshell = forceClamshell && lidProof && battery.hasBattery && !battery.onAC
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

    /// Включение/выключение «force clamshell». При первом включении один раз спросит
    /// пароль админа и выдаст постоянный доступ (sudoers). Дальше пароль не нужен.
    func setForceClamshell(_ on: Bool) {
        if on && !power.clamshellSupported {
            let granted = power.installClamshellSupport()
            if !granted {
                forceClamshell = false
                notify("Access not granted", "Couldn't set up lid-closed wake on battery.")
                return
            }
        }
        forceClamshell = on
        refresh()
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
