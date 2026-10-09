import AppKit
import SwiftUI

enum GlassTint {
    static let key = "glassTint"
    static let defaultValue = 0.3
    static let range = 0.0...0.8
    static func tile(for panel: Double) -> Double { panel * 2 / 3 }
}

struct GlassSettingsView: View {
    @AppStorage(GlassTint.key) private var tint = GlassTint.defaultValue

    var body: some View {
        Form {
            Section {
                preview
                Slider(value: $tint, in: GlassTint.range) {
                    Text("Liquid Glass")
                } minimumValueLabel: {
                    Text("Clear")
                } maximumValueLabel: {
                    Text("Tinted")
                }
                .accessibilityValue("\(Int(tint / GlassTint.range.upperBound * 100)) percent tinted")
            } header: {
                Text("Liquid Glass")
            } footer: {
                Text("Clear is more transparent, revealing what's behind it. Tinted increases opacity and adds more contrast.")
                    .foregroundStyle(.secondary)
            }
            Section {
                Button("Reset to Default") { tint = GlassTint.defaultValue }
                    .disabled(tint == GlassTint.defaultValue)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .fixedSize()
    }

    private var preview: some View {
        ZStack {
            LinearGradient(colors: [.white, Color(white: 0.85), .orange.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Text("Quick actions")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 150, height: 44)
                .glassEffect(.clear.tint(.black.opacity(tint)), in: RoundedRectangle(cornerRadius: 14))
                .colorScheme(.dark)
        }
        .frame(height: 90)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityHidden(true)
    }
}

@MainActor final class GlassSettingsWindow {
    private var window: NSWindow?
    var onVisibilityChange: ((Bool) -> Void)?
    var isVisible: Bool { window?.isVisible == true }

    func close() { window?.close() }

    func show() {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: GlassSettingsView()))
            window.title = "MiniNotch Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.onVisibilityChange?(false) }
            }
            self.window = window
        }
        onVisibilityChange?(true)
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
