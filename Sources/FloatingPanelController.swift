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
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 200), // 初始大小设小，由内容撑开
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
        
        // 允许窗口根据 SwiftUI 内容自适应大小
        panel.setFrameAutosaveName("FocusFloatPanel_v2")

        // 使用原生 Visual Effect View 提供液态玻璃效果
        let visualEffect = NSVisualEffectView()
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.material = .hudWindow // 深色、通透且具有系统级液态玻璃感
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 32 // 与 SwiftUI 中的圆角对应
        
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
