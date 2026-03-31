import AppKit
import SwiftUI

private final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class FloatingPanelController: NSWindowController {
    init(rootView: some View) {
        let panel = OverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 160), // 更窄的初始尺寸
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        
        panel.setFrameAutosaveName("FocusFloatPanel_v3")

        // 升级为极致通透的液态玻璃材质
        let visualEffect = NSVisualEffectView()
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.material = .fullScreenUI // AppKit 中最接近 ultraThinMaterial 的极致通透材质
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 24 // 缩小圆角，视觉更紧致
        
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        
        // 创建主视图布局
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(visualEffect)
        container.addSubview(hostingView)
        
        panel.contentView = container
        
        visualEffect.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            // 背景填充
            visualEffect.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            visualEffect.topAnchor.constraint(equalTo: container.topAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            
            // 内容填充
            hostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: container.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        super.init(window: panel)
        shouldCascadeWindows = false
        window?.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }
}
