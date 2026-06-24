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
        // Один и тот же глаз: контур в покое, заливка когда держим Mac бодрым.
        let name = state.isAwake ? "eye.fill" : "eye"
        guard name != lastIconName else { return }   // не переустанавливаем зря → нет мигания
        let cfg = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        guard let img = NSImage(systemSymbolName: name, accessibilityDescription: Brand.appName)?
            .withSymbolConfiguration(cfg) else { return }   // nil → оставляем прежний (не квадрат)
        img.isTemplate = true   // система красит белым на тёмной панели, чёрным на светлой
        button.image = img
        button.imagePosition = .imageOnly
        button.contentTintColor = nil
        lastIconName = name
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
