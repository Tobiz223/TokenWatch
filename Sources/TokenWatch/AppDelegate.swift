import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let store = UsageStore()
    private let settings = Settings()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "TokenWatch")
            button.imagePosition = .imageLeading
            button.action = #selector(togglePopover)
            button.target = self
        }
        updateTitle()

        // Recompute the menu bar figure when spend or the chosen currency changes.
        store.$monthToDate
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateTitle() }
            .store(in: &cancellables)
        settings.$currency
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateTitle() }
            .store(in: &cancellables)

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 460, height: 540)
        popover.contentViewController = NSHostingController(
            rootView: RootView().environmentObject(store).environmentObject(settings))

        store.startWatching()
    }

    private func updateTitle() {
        statusItem?.button?.title = " " + settings.money(store.monthToDate)
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            store.refresh()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
