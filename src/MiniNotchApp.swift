import AppKit
import SwiftUI
import Combine

final class NotchPanel: NSPanel {
    var escape: (() -> Void)?
    override var canBecomeKey: Bool { true }
    // Private AppKit hooks: Liquid Glass frosts when the window loses active appearance (app deactivates); keep it clear.
    @objc(_hasActiveAppearance) var alwaysActiveAppearance: Bool { true }
    @objc(_hasActiveAppearanceIgnoringKeyFocus) var alwaysActiveAppearanceIgnoringKeyFocus: Bool { true }
    @objc(hasKeyAppearance) var alwaysKeyAppearance: Bool { true }
    override func cancelOperation(_ sender: Any?) { escape?() }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let actions = SystemActions()
    private var state = PanelState()
    private var panel: NotchPanel!
    private var notch: CGRect?
    private var pointerInside = false
    private var mouseMonitors: [Any] = []
    private var status: NSStatusItem!
    private var hide: DispatchWorkItem?
    private var subscriptions: Set<AnyCancellable> = []
    private var screen: NSScreen?
    private let settings = GlassSettingsWindow()
    private var alwaysShowItem: NSMenuItem!
    private static let alwaysShowKey = "alwaysShowActions"
    private var settingsItem: NSMenuItem!
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        panel = NotchPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = true
        panel.level = .floating; panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.escape = { [weak self] in self?.dismiss() }
        panel.acceptsMouseMovedEvents = true
        let tracking = NSView()
        let content = NSHostingView(rootView: ControlsView(actions: actions, dismissError: { [weak self] in self?.actions.error = nil }))
        tracking.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: tracking.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: tracking.trailingAnchor),
            content.topAnchor.constraint(equalTo: tracking.topAnchor),
            content.bottomAnchor.constraint(equalTo: tracking.bottomAnchor)
        ])
        panel.contentView = tracking
        let mouseEvents: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: mouseEvents, handler: { [weak self] _ in self?.updatePointer() }) {
            mouseMonitors.append(monitor)
        }
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: mouseEvents, handler: { [weak self] event in
            self?.updatePointer()
            return event
        }) { mouseMonitors.append(monitor) }
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let icon = NSImage(named: "MiniNotch")
        icon?.size = NSSize(width: 18, height: 18)
        icon?.accessibilityDescription = "MiniNotch"
        status.button?.image = icon
        let menu = NSMenu()
        alwaysShowItem = menu.addItem(withTitle: "Always Show Actions", action: #selector(toggleAlwaysShow), keyEquivalent: "")
        settingsItem = menu.addItem(withTitle: "Settings", action: #selector(toggleSettings), keyEquivalent: ",")
        menu.delegate = self
        menu.addItem(.separator()); menu.addItem(withTitle: "Quit MiniNotch", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }; status.menu = menu
        NotificationCenter.default.addObserver(self, selector: #selector(place), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        actions.$error.dropFirst().receive(on: RunLoop.main).sink { [weak self] error in
            guard let self else { return }
            state.hold = error != nil
            if error != nil { state.enter(); state.exit() }
            place(); render(); scheduleHide()
        }.store(in: &subscriptions)
        settings.onVisibilityChange = { [weak self] open in
            guard let self else { return }
            state.previewing = open
            render()
        }
        state.pinned = UserDefaults.standard.bool(forKey: Self.alwaysShowKey)
        place(); render()
    }
    @objc private func place() {
        screen = NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
        let display = screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let display else { notch = nil; panel.orderOut(nil); return }
        let top = screen == nil ? display.visibleFrame.maxY : display.frame.maxY - display.safeAreaInsets.top
        let width: CGFloat = actions.error == nil ? 150 : 320
        let height: CGFloat = actions.error == nil ? 70 : 280
        panel.setFrame(NSRect(x: display.frame.midX - width / 2, y: top - height, width: width, height: height), display: true)
        if let screen {
            let left = screen.auxiliaryTopLeftArea?.maxX ?? (screen.frame.midX - 70)
            let right = screen.auxiliaryTopRightArea?.minX ?? (screen.frame.midX + 70)
            notch = CGRect(x: left, y: top, width: max(1, right - left), height: display.safeAreaInsets.top)
        } else { notch = nil }
        updatePointer()
    }
    private func updatePointer() {
        let inside = pointerInsideActions(NSEvent.mouseLocation, notch: notch, panel: panel.frame, panelVisible: state.visible)
        guard inside != pointerInside else { return }
        pointerInside = inside
        pointer(inside)
    }

    private func pointer(_ entered: Bool) {
        hide?.cancel()
        if entered {
            state.enter()
            render()
        } else { state.exit(); scheduleHide() }
    }
    private func scheduleHide() {
        hide?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.state.expire(); self?.render() }
        hide = work; DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: work)
    }
    private func render() {
        if state.visible {
            guard !panel.isVisible else { return }
            panel.alphaValue = 0; panel.makeKeyAndOrderFront(nil)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.14
                panel.animator().alphaValue = 1
            }
        } else { panel.orderOut(nil) }
    }
    private func dismiss() { state.escape(); render() }
    @objc private func toggleAlwaysShow() {
        state.pinned.toggle()
        UserDefaults.standard.set(state.pinned, forKey: Self.alwaysShowKey)
        render()
    }
    func menuNeedsUpdate(_ menu: NSMenu) {
        alwaysShowItem.state = state.pinned ? .on : .off
        settingsItem.state = settings.isVisible ? .on : .off
    }
    @objc private func toggleSettings() { settings.isVisible ? settings.close() : settings.show() }
    @objc private func quit() { NSApp.terminate(nil) }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if !actions.inFlight.isEmpty { NSSound.beep(); return .terminateCancel }
        return .terminateNow
    }
    func applicationWillTerminate(_ notification: Notification) {
        mouseMonitors.forEach(NSEvent.removeMonitor)
        actions.shutdown()
    }
}
@main struct MiniNotchApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate(); app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
