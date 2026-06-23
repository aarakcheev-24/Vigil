import Foundation

struct AgentDef: Identifiable {
    let id: String
    let name: String
    let symbol: String        // SF Symbol для иконки
    let matchers: [String]    // подстроки в командной строке процесса
}

struct AgentStatus: Identifiable {
    let id: String
    let name: String
    let symbol: String
    let sessions: Int
    var isActive: Bool { sessions > 0 }
}

/// Сканирует запущенные процессы и считает активные сессии AI-агентов.
final class AgentMonitor {
    /// Список известных агентов — легко расширять.
    static let known: [AgentDef] = [
        .init(id: "claude",   name: "Claude Code",     symbol: "a.circle",        matchers: ["/claude", " claude", "claude-code"]),
        .init(id: "codex",    name: "OpenAI Codex CLI", symbol: "chevron.left.forwardslash.chevron.right", matchers: ["codex"]),
        .init(id: "opencode", name: "OpenCode",        symbol: "square.stack.3d.up", matchers: ["opencode"]),
        .init(id: "gemini",   name: "Gemini CLI",      symbol: "sparkle",          matchers: ["gemini"]),
        .init(id: "aider",    name: "Aider",           symbol: "terminal",         matchers: ["aider"]),
        .init(id: "cursor",   name: "Cursor Agent",    symbol: "cursorarrow.rays", matchers: ["cursor-agent", "cursor agent"]),
    ]

    func scan() -> [AgentStatus] {
        let lines = runPS()
        return Self.known.map { def in
            let count = lines.filter { line in
                def.matchers.contains { line.contains($0) }
            }.count
            return AgentStatus(id: def.id, name: def.name, symbol: def.symbol, sessions: count)
        }
    }

    private func runPS() -> [String] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-axo", "command="]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            guard let out = String(data: data, encoding: .utf8) else { return [] }
            // отфильтруем сам наш процесс/ps, чтобы не считать ложные совпадения
            return out.split(separator: "\n").map(String.init).filter {
                !$0.contains("/bin/ps") && !$0.contains("Vigil")
            }
        } catch {
            return []
        }
    }
}
