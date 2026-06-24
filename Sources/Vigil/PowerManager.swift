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

    private let sudoersPath = "/etc/sudoers.d/vigil"

    /// Одноразовый «грант доступа» уже выдан? (как разрешение в Конфиденциальности)
    var clamshellSupported: Bool {
        FileManager.default.fileExists(atPath: sudoersPath)
    }

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

    // MARK: pmset clamshell (грант доступа выдаётся ОДИН РАЗ)

    /// Первая настройка: один диалог пароля админа ставит правило sudoers, которое
    /// разрешает запускать ровно `pmset … disablesleep` без пароля. Дальше — без запросов.
    /// Возвращает true, если доступ выдан.
    @discardableResult
    func installClamshellSupport() -> Bool {
        if clamshellSupported { return true }
        let user = NSUserName()
        let rule = "\(user) ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep *"
        // пишем правило, выставляем права 0440 и проверяем синтаксис visudo
        let cmd = "/bin/echo '\(rule)' > \(sudoersPath) && /bin/chmod 0440 \(sudoersPath) " +
                  "&& /usr/sbin/visudo -cf \(sudoersPath)"
        let ok = runAdmin(cmd)
        if !ok { try? FileManager.default.removeItem(atPath: sudoersPath) }
        return ok
    }

    /// Идемпотентно. Если доступ выдан — выполняется тихо, без пароля.
    func setClamshell(_ enabled: Bool) {
        guard enabled != clamshellForced else { return }
        guard clamshellSupported else { return }   // нет гранта — молча ничего не делаем
        if runSudoNoPrompt("disablesleep \(enabled ? 1 : 0)") {
            clamshellForced = enabled
        }
    }

    /// Вернуть disablesleep=0 при выходе. Тихо.
    func shutdown() {
        stop()
        if clamshellForced, clamshellSupported {
            _ = runSudoNoPrompt("disablesleep 0")
            clamshellForced = false
        }
    }

    /// `sudo -n` — без интерактивного запроса пароля (работает благодаря правилу sudoers).
    private func runSudoNoPrompt(_ args: String) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        p.arguments = ["-n", "/usr/bin/pmset", "-a"] + args.split(separator: " ").map(String.init)
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do { try p.run(); p.waitUntilExit(); return p.terminationStatus == 0 }
        catch { return false }
    }

    /// Разовый запрос прав администратора через нативный диалог macOS.
    private func runAdmin(_ command: String) -> Bool {
        let script = "do shell script \"\(command)\" with administrator privileges"
        guard let apple = NSAppleScript(source: script) else { return false }
        var err: NSDictionary?
        apple.executeAndReturnError(&err)
        return err == nil
    }

    deinit { stop() }
}
