import Foundation
import IOKit.pwr_mgt

/// Держит Mac бодрым.
///
/// Уровни защиты:
///  1. IOKit power-assertions (`PreventUserIdleSystemSleep` + `PreventSystemSleep`) —
///     не дают системе уснуть по простою и удерживают clamshell **на питании от сети**.
///     Бесплатно, без прав администратора, можно дёргать сколько угодно.
///  2. `pmset disablesleep 1` — единственный способ запретить сон при закрытой крышке
///     **на батарее**. Требует прав администратора. ОТКЛЮЧЕНО по умолчанию и включается
///     только осознанно в настройках; пароль спрашивается максимум один раз за сессию.
final class PowerManager {
    private var idleAssertion: IOPMAssertionID = 0
    private var systemAssertion: IOPMAssertionID = 0
    private(set) var isActive = false

    private(set) var clamshellForced = false
    private var clamshellDenied = false   // пользователь отклонил диалог — больше не спрашиваем

    // MARK: IOKit (без прав админа, можно вызывать часто)

    func start(lidProof: Bool, reason: String) {
        releaseAssertions()
        let reasonCF = reason as CFString
        IOPMAssertionCreateWithName("PreventUserIdleSystemSleep" as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn), reasonCF, &idleAssertion)
        if lidProof {
            IOPMAssertionCreateWithName("PreventSystemSleep" as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn), reasonCF, &systemAssertion)
        }
        isActive = true
    }

    func stop() {
        releaseAssertions()
        isActive = false
    }

    private func releaseAssertions() {
        if idleAssertion != 0 { IOPMAssertionRelease(idleAssertion); idleAssertion = 0 }
        if systemAssertion != 0 { IOPMAssertionRelease(systemAssertion); systemAssertion = 0 }
    }

    // MARK: pmset clamshell (права админа, спрашиваем максимум один раз)

    /// Идемпотентно. Срабатывает только при реальной смене состояния.
    /// Если пользователь один раз отклонил диалог — больше не пристаёт.
    func setClamshell(_ enabled: Bool) {
        guard enabled != clamshellForced else { return }
        if enabled && clamshellDenied { return }
        let ok = runPrivileged("/usr/bin/pmset -a disablesleep \(enabled ? 1 : 0)")
        if ok {
            clamshellForced = enabled
            if !enabled { clamshellDenied = false }
        } else if enabled {
            clamshellDenied = true   // отклонил — не нервируем
        }
    }

    /// Вернуть disablesleep=0 при выходе. Тихо — без повторного диалога, если он уже стоял.
    func shutdown() {
        stop()
        if clamshellForced {
            runPrivileged("/usr/bin/pmset -a disablesleep 0")
            clamshellForced = false
        }
    }

    @discardableResult
    private func runPrivileged(_ command: String) -> Bool {
        let script = "do shell script \"\(command)\" with administrator privileges"
        guard let apple = NSAppleScript(source: script) else { return false }
        var err: NSDictionary?
        apple.executeAndReturnError(&err)
        return err == nil
    }

    deinit { stop() }
}
