import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let state = AppState()
    private var onboardingWindow: NSWindow?
    private var lastIconName: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // без иконки в Dock

        state.boot()

        // Попап с SwiftUI
        popover.contentSize = NSSize(width: 320, height: 540)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ContentView(state: state))

        // Иконка в строке меню
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.action = #selector(togglePopover)
            button.target = self
        }
        refreshIcon()

        // Обновляем подсветку иконки в зависимости от состояния
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.refreshIcon()
        }

        // Первый запуск — экран настройки
        if !UserDefaults.standard.bool(forKey: "didOnboard") {
            showOnboarding()
        }
    }

    private func showOnboarding() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 600),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered, defer: false)
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.isMovableByWindowBackground = true
        win.center()
        win.isReleasedWhenClosed = false
        win.delegate = self   // закрытие крестиком тоже отметит онбординг пройденным
        win.contentViewController = NSHostingController(
            rootView: OnboardingView(state: state) { [weak self] in self?.finishOnboarding() })
        onboardingWindow = win
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }

    private func finishOnboarding() {
        UserDefaults.standard.set(true, forKey: "didOnboard")
        onboardingWindow?.close()
        onboardingWindow = nil
    }

    private func refreshIcon() {
        guard let button = statusItem.button else { return }
        // Тот же глаз, что и в иконке приложения: контур в покое, заливка когда держим бодрым.
        let key = state.isAwake ? "active" : "idle"
        guard key != lastIconName else { return }   // не переустанавливаем зря → нет мигания
        button.image = Self.eyeImage(filled: state.isAwake)
        button.imagePosition = .imageOnly
        button.contentTintColor = nil
        lastIconName = key
    }

    /// Рисует глаз-страж (как в иконке приложения) как template-картинку для строки меню.
    static func eyeImage(filled: Bool) -> NSImage {
        let w: CGFloat = 22, h: CGFloat = 16
        let img = NSImage(size: NSSize(width: w, height: h))
        img.lockFocus()
        let ctx = NSGraphicsContext.current!.cgContext
        let cx = w/2, cy = h/2
        let halfW = w*0.46, lid = h*0.40
        let eye = CGMutablePath()
        eye.move(to: CGPoint(x: cx - halfW, y: cy))
        eye.addQuadCurve(to: CGPoint(x: cx + halfW, y: cy), control: CGPoint(x: cx, y: cy + lid))
        eye.addQuadCurve(to: CGPoint(x: cx - halfW, y: cy), control: CGPoint(x: cx, y: cy - lid))
        ctx.setStrokeColor(NSColor.black.cgColor)
        ctx.setFillColor(NSColor.black.cgColor)
        if filled {
            ctx.addPath(eye); ctx.fillPath()
        } else {
            ctx.setLineWidth(1.7); ctx.setLineCap(.round); ctx.setLineJoin(.round)
            ctx.addPath(eye); ctx.strokePath()
            let r = h*0.17
            ctx.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: 2*r, height: 2*r)); ctx.fillPath()
        }
        img.unlockFocus()
        img.isTemplate = true   // система сама красит: белый на тёмном, чёрный на светлом
        return img
    }

    func applicationWillTerminate(_ notification: Notification) {
        state.shutdown()
    }

    // Закрыли окно онбординга (в т.ч. крестиком) — больше не показывать.
    func windowWillClose(_ notification: Notification) {
        UserDefaults.standard.set(true, forKey: "didOnboard")
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            state.refresh()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
