import Cocoa
import QuartzCore

@_cdecl("show_hud")
public func showHUD(windowNumber: Int) {
    DispatchQueue.main.async {
        LoadingHudManager.shared.showHud(windowNumber: windowNumber)
    }
}

@_cdecl("close_hud")
public func hideHUD(windowNumber: Int) {
    DispatchQueue.main.async {
        LoadingHudManager.shared.closeHud(windowNumber: windowNumber)
    }
}

@MainActor
class LoadingHudManager {
    
    static let shared = LoadingHudManager();
    
    var streamerMap: [Int: LoadingHUD] = [:]
    
    public func showHud(windowNumber: Int) {
        let parentWindow = NSApp.window(withWindowNumber: windowNumber)!;
        parentWindow.ignoresMouseEvents = true
        let hud = LoadingHUD(parent: parentWindow, message: nil)
        streamerMap[windowNumber] = hud
        
    }
    
    public func closeHud(windowNumber: Int) {
        let parentWindow = NSApp.window(withWindowNumber: windowNumber)!
        if let cachedHud = streamerMap[windowNumber] {
            cachedHud.hide()
        }
        streamerMap[windowNumber] = nil
    }
}

final class LoadingHUD: NSWindowController {
    
    /// Show HUD as a sheet on `parent` (or on mainWindow if parent nil)
    func show(on parent: NSWindow? = nil, message: String? = nil) -> LoadingHUD {
        let parentWindow = parent ?? NSApp.mainWindow
        let hud = LoadingHUD(parent: parentWindow, message: message)
        return hud
    }
    
    /// Hide HUD if visible
    func hide() {
        hideAnimated()
    }
    
    private let hudSize = NSSize(width: 158, height: 98) // Apple-like
        private weak var parentWindow: NSWindow?
        private var messageLabel: NSTextField?
        private var spinner: NSProgressIndicator!

        // Views
        private var roundedContainer: NSView!    // real rounded view (clips)
        private var blurView: NSVisualEffectView! // rectangular VEV underneath
        private var overlayLayer: CALayer!       // dark overlay to tune brightness
        private var innerHighlightLayer: CALayer!// subtle inner highlight / glow

        // keep a reference to the frame-change observer so we can remove it if needed
        private var frameObserver: Any?

        // MARK: - Init
        init(parent: NSWindow?, message: String?) {
            // Create borderless panel
            let rect = NSRect(origin: .zero, size: hudSize)
            let panel = NSPanel(contentRect: rect,
                                styleMask: [.borderless],
                                backing: .buffered,
                                defer: false)
            panel.isOpaque = false
            panel.backgroundColor = .clear

            // IMPORTANT: disable the system window shadow (the big "extra" shadow you saw)
            panel.hasShadow = false

            panel.level = .modalPanel
            panel.ignoresMouseEvents = false

            self.parentWindow = parent
            super.init(window: panel)

            // Build UI
            buildHierarchy(message: message)
            layoutConstraints()
            configureLayers()
            appearAnimated()

            if let parent = parent {
                let frame = parent.frame
                let origin = NSPoint(
                    x: frame.midX - rect.width / 2,
                    y: frame.midY - rect.height / 2
                )
                panel.setFrameOrigin(origin)
            } else if let screen = NSScreen.main?.frame {
                let origin = NSPoint(
                    x: screen.midX - rect.width / 2,
                    y: screen.midY - rect.height / 2
                )
                panel.setFrameOrigin(origin)
            }

            panel.orderFrontRegardless()
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        @MainActor
        deinit {
            // remove observer if any
            if let obs = frameObserver {
                NotificationCenter.default.removeObserver(obs)
                frameObserver = nil
            }
        }

        // MARK: - Build view hierarchy
        private func buildHierarchy(message: String?) {
            guard let panel = window else { return }

            // 1) Rounded container — THIS is clipped to corner radius (prevents VEV sampling from leaking)
            roundedContainer = NSView(frame: panel.contentView!.bounds)
            roundedContainer.translatesAutoresizingMaskIntoConstraints = true
            roundedContainer.autoresizingMask = [.width, .height]
            roundedContainer.wantsLayer = true
            roundedContainer.layer?.cornerRadius = 12          // use 12 for Sonoma IAP look
            roundedContainer.layer?.masksToBounds = true
            // Note: we intentionally do NOT set panel.hasShadow = true (we disabled it above)
            panel.contentView = roundedContainer

            // 2) VisualEffectView — full-bleed rectangular (no corner radius)
            blurView = NSVisualEffectView(frame: roundedContainer.bounds)
            blurView.material = .fullScreenUI
            blurView.state = .active
            blurView.blendingMode = .behindWindow
            blurView.autoresizingMask = [.width, .height]
            roundedContainer.addSubview(blurView, positioned: .below, relativeTo: nil)

            // 3) Overlay layers (CALayer on roundedContainer.layer)
            overlayLayer = CALayer()
            overlayLayer.backgroundColor = NSColor.black.withAlphaComponent(0.16).cgColor
            overlayLayer.frame = roundedContainer.bounds
            overlayLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            roundedContainer.layer?.addSublayer(overlayLayer)

            // 4) Inner subtle highlight (very thin top gradient to mimic commerce HUD highlight)
            innerHighlightLayer = CAGradientLayer()
            innerHighlightLayer.frame = CGRect(x: 0, y: roundedContainer.bounds.height - 18, width: roundedContainer.bounds.width, height: 18)
            innerHighlightLayer.autoresizingMask = [.layerWidthSizable, .layerMinYMargin]
            (innerHighlightLayer as! CAGradientLayer).colors = [
                NSColor.white.withAlphaComponent(0.035).cgColor,
                NSColor.clear.cgColor
            ]
            roundedContainer.layer?.addSublayer(innerHighlightLayer)

            // 5) Spinner
            spinner = NSProgressIndicator()
            spinner.style = .spinning
            spinner.controlSize = .regular
            spinner.translatesAutoresizingMaskIntoConstraints = false
            spinner.startAnimation(nil)
            roundedContainer.addSubview(spinner)

            // 6) Optional message label (Apple IAP sometimes shows none; keep subtle)
            if let text = message {
                let lbl = NSTextField(labelWithString: text)
                lbl.font = NSFont.systemFont(ofSize: 12, weight: .regular)
                lbl.alignment = .center
                lbl.textColor = NSColor.controlTextColor.withAlphaComponent(0.9)
                lbl.translatesAutoresizingMaskIntoConstraints = false
                roundedContainer.addSubview(lbl)
                messageLabel = lbl
            }

            // Observe frame changes of roundedContainer so we can update shadowPath precisely
            roundedContainer.postsFrameChangedNotifications = true
            frameObserver = NotificationCenter.default.addObserver(
                forName: NSView.frameDidChangeNotification,
                object: roundedContainer,
                queue: .main
            ) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateShadowPath()
                }
            }
        }

        // MARK: - Constraints & positions
        private func layoutConstraints() {
            guard let container = roundedContainer else { return }

            // spinner center, slight upward nudge (-1 px) to match Apple's visual tuning
            spinner.centerXAnchor.constraint(equalTo: container.centerXAnchor).isActive = true
            spinner.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -1).isActive = true

            if let lbl = messageLabel {
                // place label under spinner with small spacing
                lbl.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 8).isActive = true
                lbl.centerXAnchor.constraint(equalTo: container.centerXAnchor).isActive = true
            }
        }

        // MARK: - Layer tweaks (shadow, subtle outlines)
        private func configureLayers() {
            guard let layer = roundedContainer.layer else { return }

            // IMPORTANT: draw shadow on roundedContainer.layer (not window). We will use shadowPath
            layer.shadowColor = NSColor.black.cgColor
            layer.shadowOpacity = 0.32
            layer.shadowRadius = 10.0    // tune this to match visual size
            layer.shadowOffset = CGSize(width: 0, height: -2)
//            layer.masksToBounds = false  // must be false for outer shadow to render

            // subtle border
            let border = CALayer()
            border.frame = layer.bounds
            border.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            border.backgroundColor = NSColor.clear.cgColor
            border.borderColor = NSColor.white.withAlphaComponent(0.03).cgColor
            border.borderWidth = 0.5
            layer.addSublayer(border)

            // set the initial shadowPath
            updateShadowPath()
        }

        // Update the shadowPath to exactly match the rounded rect of the container.
        // This constrains the shadow to the shape and avoids extra window-edge shadow.
        private func updateShadowPath() {
            guard let layer = roundedContainer.layer else { return }
            let bounds = roundedContainer.bounds
            let radius = layer.cornerRadius
            // inset slightly so shadow does not extend more than desired (tweak inset if needed)
            let insetForPath: CGFloat = 0.0
            let rectForPath = bounds.insetBy(dx: insetForPath, dy: insetForPath)
            let path = CGPath(roundedRect: rectForPath, cornerWidth: radius, cornerHeight: radius, transform: nil)
            layer.shadowPath = path
        }

        // MARK: - Appear / hide animations (close to system)
        private func appearAnimated() {
            guard let w = window else { return }

            // Initial state
            w.alphaValue = 0.0
            w.contentView?.layer?.transform = CATransform3DMakeScale(0.96, 0.96, 1)
            // slight vertical offset like Apple comes up a little
            let originalOrigin = w.frame.origin
            w.setFrameOrigin(NSPoint(x: originalOrigin.x, y: originalOrigin.y - 4))

            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.18
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                w.animator().alphaValue = 1.0
                w.contentView?.layer?.transform = CATransform3DIdentity
                w.animator().setFrameOrigin(NSPoint(x: originalOrigin.x, y: originalOrigin.y))
            }, completionHandler: nil)
        }

        private func hideAnimated() {
            guard let parent = window?.sheetParent else {
                // not a sheet: just close window
                guard let w = window else { return }
                NSAnimationContext.runAnimationGroup({ ctx in
                    ctx.duration = 0.15
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                    w.animator().alphaValue = 0.0
                }, completionHandler: {
                    DispatchQueue.main.async {
                        self.parentWindow?.ignoresMouseEvents = false
                        w.orderOut(nil)
                    }
                })
                return
            }

            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.15
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                self.window?.animator().alphaValue = 0.0
            }, completionHandler: {
                DispatchQueue.main.async {
                    self.parentWindow?.ignoresMouseEvents = false
                    parent.endSheet(self.window!)
                }
            })
        }

        // MARK: - Utilities
        private func update(message: String?) {
            if let msg = message {
                if messageLabel == nil {
                    // create label
                    let lbl = NSTextField(labelWithString: msg)
                    lbl.font = NSFont.systemFont(ofSize: 12, weight: .regular)
                    lbl.alignment = .center
                    lbl.textColor = NSColor.controlTextColor.withAlphaComponent(0.9)
                    lbl.translatesAutoresizingMaskIntoConstraints = false
                    roundedContainer.addSubview(lbl)
                    messageLabel = lbl
                    layoutConstraints()
                } else {
                    messageLabel?.stringValue = msg
                }
            } else {
                // hide label if nil requested
                messageLabel?.removeFromSuperview()
                messageLabel = nil
            }
        }
}
