import Foundation
import IOKit.pwr_mgt

/// Держит Mac бодрым.
///
/// Два уровня защиты:
///  1. IOKit power-assertions (`PreventUserIdleSystemSleep` + `PreventSystemSleep`) —
///     не дают системе уснуть по простою и удерживают clamshell **на питании от сети**.
///  2. `pmset disablesleep 1` — единственный надёжный способ запретить сон при закрытой
///     крышке **на батарее**. Требует прав администратора, поэтому ставится через
///     системный диалог пароля (мы пароль не видим). Включается только когда это реально
///     нужно: lid-proof + работа от батареи.
final class PowerManager {
    private var idleAssertion: IOPMAssertionID = 0
    private var systemAssertion: IOPMAssertionID = 0
    private(set) var isActive = false
    private(set) var clamshellForced = false   // выставлен ли pmset disablesleep 1

    func start(lidProof: Bool, onBattery: Bool, reason: String) {
        releaseAssertions()
        let reasonCF = reason as CFString

        IOPMAssertionCreateWithName("PreventUserIdleSystemSleep" as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn), reasonCF, &idleAssertion)

        if lidProof {
            IOPMAssertionCreateWithName("PreventSystemSleep" as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn), reasonCF, &systemAssertion)
        }
        isActive = true

        // Глубокая clamshell-защита нужна только на батарее.
        setClamshellForced(lidProof && onBattery)
    }

    func stop() {
        releaseAssertions()
        setClamshellForced(false)
        isActive = false
    }

    private func releaseAssertions() {
        if idleAssertion != 0 { IOPMAssertionRelease(idleAssertion); idleAssertion = 0 }
        if systemAssertion != 0 { IOPMAssertionRelease(systemAssertion); systemAssertion = 0 }
    }

    /// Идемпотентно: запрашивает админ-права лишь при реальной смене состояния.
    private func setClamshellForced(_ enabled: Bool) {
        guard enabled != clamshellForced else { return }
        let ok = runPrivileged("/usr/bin/pmset -a disablesleep \(enabled ? 1 : 0)")
        if ok { clamshellForced = enabled }
    }

    /// Запуск команды с правами администратора через нативный диалог macOS.
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
