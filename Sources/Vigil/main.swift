import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let state = AppState()
    private var monitorClick: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // без иконки в Dock

        state.boot()

        // Попап с SwiftUI
        popover.contentSize = NSSize(width: 320, height: 520)
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
    }

    private func refreshIcon() {
        guard let button = statusItem.button else { return }
        let name = state.isAwake ? "laptopcomputer.and.arrow.down" : Brand.menuBarSymbol
        let cfg = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        let img = NSImage(systemSymbolName: name, accessibilityDescription: Brand.appName)?
            .withSymbolConfiguration(cfg)
        // template = автоматически белый в тёмной строке меню, чёрный в светлой
        img?.isTemplate = true
        button.image = img
        // подсветим зелёным только когда реально не даём спать
        button.contentTintColor = state.isAwake ? NSColor(Brand.good) : nil
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
