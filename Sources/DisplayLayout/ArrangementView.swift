import AppKit
import CoreGraphics

class ArrangementViewController: NSViewController {
    private let arrangementView = ArrangementView()
    private let descriptionLabel = NSTextField(labelWithString: "ドラッグで配置を変更")

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 300))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.wantsLayer = true

        let footerHeight: CGFloat = 36
        let contentHeight = view.frame.height - footerHeight

        arrangementView.frame = NSRect(x: 0, y: footerHeight, width: view.frame.width, height: contentHeight)
        arrangementView.autoresizingMask = [.width, .height]
        view.addSubview(arrangementView)

        let separator = NSBox()
        separator.boxType = .separator
        separator.frame = NSRect(x: 0, y: footerHeight, width: view.frame.width, height: 1)
        separator.autoresizingMask = [.width]
        view.addSubview(separator)

        let footer = NSView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: footerHeight))
        footer.autoresizingMask = [.width]
        view.addSubview(footer)

        descriptionLabel.font = NSFont.systemFont(ofSize: 11)
        descriptionLabel.textColor = NSColor.secondaryLabelColor
        descriptionLabel.frame = NSRect(x: 12, y: 8, width: 200, height: 20)
        footer.addSubview(descriptionLabel)
    }

    func reload() {
        arrangementView.reload()
    }
}

class ArrangementView: NSView {
    private var displays: [DisplayInfo] = []
    private var dragIndex: Int? = nil
    private var dragOffset: CGPoint = .zero
    private var scale: CGFloat = 1.0
    private var drawingOrigin: CGPoint = .zero
    private let padding: CGFloat = 24

    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func screensChanged() {
        reload()
    }

    func reload() {
        displays = DisplayManager.activeDisplays()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard !displays.isEmpty else { return }

        computeTransform()

        for (i, display) in displays.enumerated() {
            let rect = displayRect(for: display)
            let isDragging = dragIndex == i

            let path = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)

            if display.isMain {
                NSColor.controlAccentColor.withAlphaComponent(0.25).setFill()
            } else {
                NSColor.unemphasizedSelectedContentBackgroundColor.setFill()
            }
            path.fill()

            if isDragging {
                NSColor.controlAccentColor.setStroke()
                path.lineWidth = 2.5
            } else {
                NSColor.separatorColor.setStroke()
                path.lineWidth = 1.0
            }
            path.stroke()

            if display.isMain {
                let menuBarHeight: CGFloat = 3
                let menuBar = NSRect(x: rect.minX + 1, y: rect.minY + 1, width: rect.width - 2, height: menuBarHeight)
                let menuPath = NSBezierPath(roundedRect: menuBar, xRadius: 3, yRadius: 3)
                NSColor.white.withAlphaComponent(0.8).setFill()
                menuPath.fill()
            }

            let labelFont = NSFont.systemFont(ofSize: min(11, rect.height * 0.2))
            let attrs: [NSAttributedString.Key: Any] = [
                .font: labelFont,
                .foregroundColor: display.isMain ? NSColor.controlAccentColor : NSColor.secondaryLabelColor
            ]
            let str = NSAttributedString(string: display.name, attributes: attrs)
            let strSize = str.size()
            if strSize.width <= rect.width - 8 {
                let strRect = NSRect(
                    x: rect.midX - strSize.width / 2,
                    y: rect.midY - strSize.height / 2,
                    width: strSize.width,
                    height: strSize.height
                )
                str.draw(in: strRect)
            } else {
                let strRect = NSRect(
                    x: rect.minX + 4,
                    y: rect.midY - strSize.height / 2,
                    width: rect.width - 8,
                    height: strSize.height
                )
                str.draw(in: strRect)
            }
        }
    }

    private func computeTransform() {
        guard !displays.isEmpty else { return }

        var union = displays[0].bounds
        for d in displays.dropFirst() {
            union = union.union(d.bounds)
        }

        let availableWidth = bounds.width - padding * 2
        let availableHeight = bounds.height - padding * 2

        let scaleX = availableWidth / union.width
        let scaleY = availableHeight / union.height
        scale = min(scaleX, scaleY)

        let scaledWidth = union.width * scale
        let scaledHeight = union.height * scale

        let offsetX = padding + (availableWidth - scaledWidth) / 2 - union.minX * scale
        let offsetY = padding + (availableHeight - scaledHeight) / 2 - union.minY * scale
        drawingOrigin = CGPoint(x: offsetX, y: offsetY)
    }

    private func displayRect(for display: DisplayInfo) -> CGRect {
        CGRect(
            x: display.bounds.origin.x * scale + drawingOrigin.x,
            y: display.bounds.origin.y * scale + drawingOrigin.y,
            width: display.bounds.width * scale,
            height: display.bounds.height * scale
        )
    }

    private func modelPoint(from viewPoint: CGPoint) -> CGPoint {
        CGPoint(
            x: (viewPoint.x - drawingOrigin.x) / scale,
            y: (viewPoint.y - drawingOrigin.y) / scale
        )
    }

    override func mouseDown(with event: NSEvent) {
        guard displays.count > 1 else { return }
        computeTransform()
        let loc = convert(event.locationInWindow, from: nil)

        dragIndex = nil
        for i in stride(from: displays.count - 1, through: 0, by: -1) {
            let rect = displayRect(for: displays[i])
            if rect.contains(loc) {
                dragIndex = i
                let modelLoc = modelPoint(from: loc)
                dragOffset = CGPoint(
                    x: modelLoc.x - displays[i].bounds.origin.x,
                    y: modelLoc.y - displays[i].bounds.origin.y
                )
                break
            }
        }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let idx = dragIndex else { return }
        let loc = convert(event.locationInWindow, from: nil)
        let modelLoc = modelPoint(from: loc)

        var newOrigin = CGPoint(
            x: modelLoc.x - dragOffset.x,
            y: modelLoc.y - dragOffset.y
        )

        newOrigin = applySnap(movingIndex: idx, proposedOrigin: newOrigin)
        displays[idx].bounds.origin = newOrigin
        needsDisplay = true
    }

    private func applySnap(movingIndex: Int, proposedOrigin: CGPoint) -> CGPoint {
        let snapThreshold = 12.0 / scale
        var origin = proposedOrigin
        let movingBounds = CGRect(origin: proposedOrigin, size: displays[movingIndex].bounds.size)

        for (i, other) in displays.enumerated() {
            guard i != movingIndex else { continue }
            let otherBounds = other.bounds

            let movingLeft = movingBounds.minX
            let movingRight = movingBounds.maxX
            let movingTop = movingBounds.minY
            let movingBottom = movingBounds.maxY

            let otherLeft = otherBounds.minX
            let otherRight = otherBounds.maxX
            let otherTop = otherBounds.minY
            let otherBottom = otherBounds.maxY

            // Snap right edge of moving to left edge of other
            if abs(movingRight - otherLeft) < snapThreshold {
                origin.x = otherLeft - movingBounds.width
                // Align top/bottom edges
                if abs(movingTop - otherTop) < snapThreshold { origin.y = otherTop }
                else if abs(movingBottom - otherBottom) < snapThreshold { origin.y = otherBottom - movingBounds.height }
            }
            // Snap left edge of moving to right edge of other
            else if abs(movingLeft - otherRight) < snapThreshold {
                origin.x = otherRight
                if abs(movingTop - otherTop) < snapThreshold { origin.y = otherTop }
                else if abs(movingBottom - otherBottom) < snapThreshold { origin.y = otherBottom - movingBounds.height }
            }

            // Snap bottom edge of moving to top edge of other
            if abs(movingBottom - otherTop) < snapThreshold {
                origin.y = otherTop - movingBounds.height
                if abs(movingLeft - otherLeft) < snapThreshold { origin.x = otherLeft }
                else if abs(movingRight - otherRight) < snapThreshold { origin.x = otherRight - movingBounds.width }
            }
            // Snap top edge of moving to bottom edge of other
            else if abs(movingTop - otherBottom) < snapThreshold {
                origin.y = otherBottom
                if abs(movingLeft - otherLeft) < snapThreshold { origin.x = otherLeft }
                else if abs(movingRight - otherRight) < snapThreshold { origin.x = otherRight - movingBounds.width }
            }
        }

        return origin
    }

    override func mouseUp(with event: NSEvent) {
        guard let idx = dragIndex else { return }
        dragIndex = nil

        guard displays.count > 1 else {
            needsDisplay = true
            return
        }

        resolveOverlap(movingIndex: idx)
        ensureConnected(movingIndex: idx)

        var origins = [CGDirectDisplayID: CGPoint]()
        for d in displays {
            origins[d.id] = d.bounds.origin
        }

        let success = DisplayManager.apply(origins: origins)
        if success {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.reload()
            }
        } else {
            reload()
        }

        needsDisplay = true
    }

    private func resolveOverlap(movingIndex: Int) {
        for i in 0..<displays.count {
            guard i != movingIndex else { continue }
            let a = displays[movingIndex].bounds
            let b = displays[i].bounds
            let intersection = a.intersection(b)
            guard !intersection.isNull && intersection.width > 0 && intersection.height > 0 else { continue }

            if intersection.width <= intersection.height {
                if a.midX < b.midX {
                    displays[movingIndex].bounds.origin.x -= intersection.width
                } else {
                    displays[movingIndex].bounds.origin.x += intersection.width
                }
            } else {
                if a.midY < b.midY {
                    displays[movingIndex].bounds.origin.y -= intersection.height
                } else {
                    displays[movingIndex].bounds.origin.y += intersection.height
                }
            }
        }
    }

    private func ensureConnected(movingIndex: Int) {
        let movingBounds = displays[movingIndex].bounds
        var isConnected = false

        for (i, other) in displays.enumerated() {
            guard i != movingIndex else { continue }
            let ob = other.bounds
            let horizontalOverlap = movingBounds.maxX >= ob.minX && movingBounds.minX <= ob.maxX
            let verticalOverlap = movingBounds.maxY >= ob.minY && movingBounds.minY <= ob.maxY
            let touchesHorizontally = abs(movingBounds.maxX - ob.minX) <= 1 || abs(movingBounds.minX - ob.maxX) <= 1
            let touchesVertically = abs(movingBounds.maxY - ob.minY) <= 1 || abs(movingBounds.minY - ob.maxY) <= 1

            if (touchesHorizontally && verticalOverlap) || (touchesVertically && horizontalOverlap) {
                isConnected = true
                break
            }
        }

        guard !isConnected else { return }

        var bestDist = CGFloat.infinity
        var bestDelta = CGPoint.zero

        for (i, other) in displays.enumerated() {
            guard i != movingIndex else { continue }
            let ob = other.bounds

            let candidates: [CGPoint] = [
                CGPoint(x: ob.minX - movingBounds.width, y: ob.minY),
                CGPoint(x: ob.maxX, y: ob.minY),
                CGPoint(x: ob.minX, y: ob.minY - movingBounds.height),
                CGPoint(x: ob.minX, y: ob.maxY)
            ]

            for candidate in candidates {
                let dx = candidate.x - movingBounds.origin.x
                let dy = candidate.y - movingBounds.origin.y
                let dist = sqrt(dx * dx + dy * dy)
                if dist < bestDist {
                    bestDist = dist
                    bestDelta = CGPoint(x: dx, y: dy)
                }
            }
        }

        displays[movingIndex].bounds.origin.x += bestDelta.x
        displays[movingIndex].bounds.origin.y += bestDelta.y
    }
}
