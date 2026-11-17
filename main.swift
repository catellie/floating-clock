import Cocoa

final class ClockView: NSView {
    var faceOpacity: CGFloat = 0.32
    var inkOpacity: CGFloat = 0.65
    var darkFace = false
    var showsSeconds = true
    var showsDate = true
    var showsAlternateTime = true
    var timeZoneDots: [TimeZoneDot] = [.eastCoast]
    var menuProvider: (() -> NSMenu)?
    var displayedDate: Date?
    private var drawingObstacles: [NSRect] = []

    private let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    override var isOpaque: Bool { false }
    override func menu(for event: NSEvent) -> NSMenu? { menuProvider?() }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control), let menu = menuProvider?() {
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        } else {
            window?.performDrag(with: event)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        drawingObstacles = []
        NSColor.clear.setFill()
        bounds.fill(using: .copy)
        let diameter = min(bounds.width, bounds.height) - 4
        let radius = diameter / 2
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let face = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius,
                                             width: diameter, height: diameter))
        (darkFace ? NSColor.black : NSColor.white).withAlphaComponent(faceOpacity).setFill()
        face.fill()
        let ink = (darkFace ? NSColor.white : NSColor.black).withAlphaComponent(inkOpacity)
        ink.setStroke()
        for tick in 0..<60 where tick % 5 != 0 {
            let angle = CGFloat(tick) * .pi / 30
            let path = NSBezierPath()
            path.lineWidth = diameter * 0.0012
            path.move(to: point(angle: angle, distance: radius * 0.91, center: center))
            path.line(to: point(angle: angle, distance: radius * 0.93, center: center))
            path.stroke()
        }
        for hour in 1...12 {
            let position = point(angle: CGFloat(hour) * .pi / 6,
                                 distance: radius * 0.84, center: center)
            drawText(String(hour), at: position, fontSize: diameter * 0.10, color: ink)
        }

        let date = displayedDate ?? Date()
        let zone = TimeZone.autoupdatingCurrent
        if showsDate {
            weekdayFormatter.timeZone = zone
            dateFormatter.timeZone = zone
            drawText(weekdayFormatter.string(from: date),
                     at: NSPoint(x: center.x, y: center.y + radius * 0.36),
                     fontSize: diameter * 0.06, color: ink)
            drawText(dateFormatter.string(from: date),
                     at: NSPoint(x: center.x, y: center.y + radius * 0.21),
                     fontSize: diameter * 0.06, color: ink)
            let hour = Calendar.autoupdatingCurrent.component(.hour, from: date)
            drawText(hour < 12 ? "AM" : "PM",
                     at: NSPoint(x: center.x, y: center.y - radius * 0.21),
                     fontSize: diameter * 0.06, color: ink)
            drawText(ClockMath.timeZoneLabel(at: date, timeZone: zone),
                     at: NSPoint(x: center.x, y: center.y - radius * 0.36),
                     fontSize: diameter * 0.06, color: ink)
        }

        let angles = ClockMath.angles(at: date, calendar: .autoupdatingCurrent)
        drawHand(angle: angles.hour, length: radius * 0.54, width: diameter * 0.012,
                 center: center, color: ink)
        drawHand(angle: angles.minute, length: radius * 0.77, width: diameter * 0.010,
                 center: center, color: ink)
        if showsSeconds {
            drawHand(angle: angles.second, length: radius * 0.91, width: diameter * 0.006,
                     center: center, color: ink)
        }
        if showsAlternateTime {
            let markers: [(dot: TimeZoneDot, angle: Double)] = timeZoneDots.compactMap { dot in
                guard let timeZone = TimeZone(identifier: dot.timeZoneIdentifier) else { return nil }
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = timeZone
                return (dot, ClockMath.angles(at: date, calendar: calendar).hour)
            }
            let lanes = ClockMath.dotLanes(for: markers.map(\.angle))
            let laneCount = CGFloat((lanes.max() ?? 0) + 1)
            let spacing = min(radius * 0.14, radius * 0.5 / laneCount)
            for (index, marker) in markers.enumerated() {
                let lane = CGFloat(lanes[index])
                let position = point(angle: marker.angle, distance: radius * 0.84 - lane * spacing, center: center)
                let dotSize = min(diameter * 0.06, spacing * 0.86)
                let color = marker.dot.color.nsColor.withAlphaComponent(0.9)
                color.setFill()
                let rect = NSRect(x: position.x - dotSize / 2, y: position.y - dotSize / 2,
                                  width: dotSize, height: dotSize)
                NSBezierPath(ovalIn: rect).fill()
                drawingObstacles.append(rect)
            }
            for marker in markers {
                let position = point(angle: marker.angle, distance: radius * 0.64, center: center)
                drawText(marker.dot.label, at: position, fontSize: diameter * 0.035,
                         color: marker.dot.color.nsColor.withAlphaComponent(0.9),
                         maximumWidth: diameter * 0.26, avoidingOverlaps: true)
            }
        }
    }

    private func point(angle: CGFloat, distance: CGFloat, center: NSPoint) -> NSPoint {
        NSPoint(x: center.x + sin(angle) * distance, y: center.y + cos(angle) * distance)
    }

    private func drawText(_ text: String, at center: NSPoint, fontSize: CGFloat, color: NSColor,
                          maximumWidth: CGFloat? = nil, avoidingOverlaps: Bool = false) {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: color,
        ]
        let string = text as NSString
        if let maximumWidth {
            let width = string.size(withAttributes: attributes).width
            if width > maximumWidth {
                attributes[.font] = NSFont.systemFont(ofSize: fontSize * maximumWidth / width, weight: .medium)
            }
        }
        let size = string.size(withAttributes: attributes)
        var rect = NSRect(x: center.x - size.width / 2, y: center.y - size.height / 2,
                          width: size.width, height: size.height)
        if avoidingOverlaps {
            rect = labelRect(near: rect, step: fontSize * 1.5)
        }
        string.draw(at: rect.origin, withAttributes: attributes)
        drawingObstacles.append(rect.insetBy(dx: -fontSize * 0.1, dy: -fontSize * 0.1))
    }

    private func labelRect(near preferred: NSRect, step: CGFloat) -> NSRect {
        for ring in 0...8 {
            for x in -ring...ring {
                for y in -ring...ring where max(abs(x), abs(y)) == ring {
                    let rect = preferred.offsetBy(dx: CGFloat(x) * step, dy: CGFloat(y) * step)
                    let dx = max(abs(rect.minX - bounds.midX), abs(rect.maxX - bounds.midX))
                    let dy = max(abs(rect.minY - bounds.midY), abs(rect.maxY - bounds.midY))
                    if hypot(dx, dy) < min(bounds.width, bounds.height) / 2 - 4,
                       !drawingObstacles.contains(where: { $0.intersects(rect) }) {
                        return rect
                    }
                }
            }
        }
        return preferred
    }

    private func drawHand(angle: Double, length: CGFloat, width: CGFloat,
                          center: NSPoint, color: NSColor) {
        let path = NSBezierPath()
        path.lineWidth = width
        path.move(to: point(angle: angle + .pi, distance: length * 0.08, center: center))
        path.line(to: point(angle: angle, distance: length, center: center))
        color.setStroke()
        path.stroke()
    }
}

final class ClockApp: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let defaults = UserDefaults.standard
    private let clock = ClockView()
    private var panel: NSPanel!
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var clickThrough = false
    private var alwaysOnTop = true
    private var clockVisible = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        defaults.register(defaults: ["diameter": 560.0, "faceOpacity": 0.32,
                                     "inkOpacity": 0.65, "showsSeconds": true,
                                     "showsDate": true, "alwaysOnTop": true,
                                     "showsAlternateTime": true, "alternateLabel": "East Coast",
                                     "alternateTimeZone": "America/New_York"])
        clock.faceOpacity = defaults.double(forKey: "faceOpacity")
        clock.inkOpacity = defaults.double(forKey: "inkOpacity")
        clock.darkFace = defaults.bool(forKey: "darkFace")
        clock.showsSeconds = defaults.bool(forKey: "showsSeconds")
        clock.showsDate = defaults.bool(forKey: "showsDate")
        clock.showsAlternateTime = defaults.bool(forKey: "showsAlternateTime")
        clock.timeZoneDots = TimeZoneDot.load(from: defaults)
        clickThrough = defaults.bool(forKey: "clickThrough")
        alwaysOnTop = defaults.bool(forKey: "alwaysOnTop")
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.title = "Floating Clock"
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.level = alwaysOnTop ? .floating : .normal
        panel.ignoresMouseEvents = clickThrough
        panel.contentView = clock
        panel.delegate = self
        clock.menuProvider = { [weak self] in self?.makeMenu() ?? NSMenu() }
        let diameter = max(160, defaults.double(forKey: "diameter"))
        if let origin = defaults.string(forKey: "origin") {
            panel.setFrame(NSRect(origin: NSPointFromString(origin),
                                  size: NSSize(width: diameter, height: diameter)), display: true)
            keepOnScreen()
        } else {
            centerClock(size: diameter)
        }
        panel.orderFrontRegardless()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Floating Clock")
        statusItem.button?.toolTip = "Floating Clock: settings and click-through controls"
        updateMenu()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.clock.needsDisplay = true
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
                                               name: NSApplication.didChangeScreenParametersNotification,
                                               object: nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        saveOrigin()
    }

    func windowDidMove(_ notification: Notification) { saveOrigin() }

    private func saveOrigin() {
        guard let panel else { return }
        defaults.set(NSStringFromPoint(panel.frame.origin), forKey: "origin")
    }

    private func updateMenu() { statusItem.menu = makeMenu() }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        let heading = NSMenuItem(title: "Floating Clock", action: nil, keyEquivalent: "")
        menu.addItem(heading)
        menu.addItem(.separator())
        add("Show Clock", to: menu, action: #selector(toggleVisible), checked: clockVisible)
        add("Always on Top", to: menu, action: #selector(toggleOnTop), checked: alwaysOnTop)
        add("Click Through (Lock Position)", to: menu, action: #selector(toggleClickThrough), checked: clickThrough)
        add("Show Seconds", to: menu, action: #selector(toggleSeconds), checked: clock.showsSeconds)
        add("Show Date and Time Zone", to: menu, action: #selector(toggleDate), checked: clock.showsDate)
        add("Dark Face / Light Hands", to: menu, action: #selector(toggleTheme), checked: clock.darkFace)
        menu.addItem(.separator())
        let dots = submenu("Time-Zone Dots", in: menu)
        add("Show Time-Zone Dots", to: dots, action: #selector(toggleAlternateTime),
            checked: clock.showsAlternateTime)
        dots.addItem(.separator())
        for (index, dot) in clock.timeZoneDots.enumerated() {
            let dotMenu = submenu(dot.label, in: dots)
            let image = NSImage(size: NSSize(width: 14, height: 14), flipped: false) { rect in
                dot.color.nsColor.setFill()
                NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()
                return true
            }
            dots.items.last?.image = image
            dotMenu.addItem(NSMenuItem(title: dot.timeZoneIdentifier, action: nil, keyEquivalent: ""))
            add("Edit Label, Time Zone and Colour…", to: dotMenu, action: #selector(editTimeZoneDot)).tag = index
            add("Remove Dot…", to: dotMenu, action: #selector(removeTimeZoneDot)).tag = index
        }
        dots.addItem(.separator())
        add("Add Time-Zone Dot…", to: dots, action: #selector(addTimeZoneDot))
        menu.addItem(.separator())
        let sizes = submenu("Size", in: menu)
        for size in [200, 320, 440, 560, 680, 800] {
            let item = add("\(size) pt", to: sizes, action: #selector(changeSize),
                           checked: Int(panel.frame.width.rounded()) == size)
            item.tag = size
        }
        let face = submenu("Face Opacity", in: menu)
        for percent in [0, 10, 20, 32, 50, 75, 100] {
            let item = add("\(percent)%", to: face, action: #selector(changeFaceOpacity),
                           checked: Int((clock.faceOpacity * 100).rounded()) == percent)
            item.tag = percent
        }
        let hands = submenu("Hands and Text Opacity", in: menu)
        for percent in [25, 40, 65, 80, 100] {
            let item = add("\(percent)%", to: hands, action: #selector(changeInkOpacity),
                           checked: Int((clock.inkOpacity * 100).rounded()) == percent)
            item.tag = percent
        }
        add("Center on Main Screen", to: menu, action: #selector(recenter))
        menu.addItem(.separator())
        let hint = NSMenuItem(title: "Drag clock to move · Right-click for settings", action: nil, keyEquivalent: "")
        menu.addItem(hint)
        let quit = add("Quit Floating Clock", to: menu, action: #selector(quit))
        quit.keyEquivalent = "q"
        return menu
    }

    @discardableResult
    private func add(_ title: String, to menu: NSMenu, action: Selector,
                     checked: Bool? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        if let checked { item.state = checked ? .on : .off }
        menu.addItem(item)
        return item
    }

    private func submenu(_ title: String, in menu: NSMenu) -> NSMenu {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        item.submenu = submenu
        menu.addItem(item)
        return submenu
    }

    private func centerClock(size: CGFloat) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let size = min(max(size, 160), min(visible.width, visible.height))
        panel.setFrame(NSRect(x: visible.midX - size / 2, y: visible.midY - size / 2,
                              width: size, height: size), display: true)
    }

    private func keepOnScreen() {
        guard let screen = NSScreen.screens.max(by: {
            $0.visibleFrame.intersection(panel.frame).area < $1.visibleFrame.intersection(panel.frame).area
        }) else { return }
        let visible = screen.visibleFrame
        var frame = panel.frame
        let size = min(frame.width, min(visible.width, visible.height))
        frame.size = NSSize(width: size, height: size)
        frame.origin.x = min(max(frame.minX, visible.minX), visible.maxX - size)
        frame.origin.y = min(max(frame.minY, visible.minY), visible.maxY - size)
        panel.setFrame(frame, display: true)
    }

    @objc private func screensChanged() {
        keepOnScreen()
        updateMenu()
    }
    @objc private func toggleVisible() {
        clockVisible.toggle()
        if clockVisible { panel.orderFrontRegardless() } else { panel.orderOut(nil) }
        updateMenu()
    }
    @objc private func toggleOnTop() {
        alwaysOnTop.toggle()
        defaults.set(alwaysOnTop, forKey: "alwaysOnTop")
        panel.level = alwaysOnTop ? .floating : .normal
        updateMenu()
    }
    @objc private func toggleClickThrough() {
        clickThrough.toggle()
        panel.ignoresMouseEvents = clickThrough
        defaults.set(clickThrough, forKey: "clickThrough")
        updateMenu()
    }
    @objc private func toggleSeconds() {
        clock.showsSeconds.toggle()
        defaults.set(clock.showsSeconds, forKey: "showsSeconds")
        redraw()
    }
    @objc private func toggleDate() {
        clock.showsDate.toggle()
        defaults.set(clock.showsDate, forKey: "showsDate")
        redraw()
    }
    @objc private func toggleTheme() {
        clock.darkFace.toggle()
        defaults.set(clock.darkFace, forKey: "darkFace")
        redraw()
    }
    @objc private func toggleAlternateTime() {
        clock.showsAlternateTime.toggle()
        defaults.set(clock.showsAlternateTime, forKey: "showsAlternateTime")
        redraw()
    }
    @objc private func addTimeZoneDot() {
        editDot(TimeZoneDot(label: "", timeZoneIdentifier: "America/New_York",
                            color: DotColor(red: 0.1, green: 0.5, blue: 1)), at: nil)
    }
    @objc private func editTimeZoneDot(_ sender: NSMenuItem) {
        editDot(clock.timeZoneDots[sender.tag], at: sender.tag)
    }
    @objc private func removeTimeZoneDot(_ sender: NSMenuItem) {
        let alert = NSAlert()
        alert.messageText = "Remove \"\(clock.timeZoneDots[sender.tag].label)\"?"
        alert.informativeText = "This removes only this time-zone dot."
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            clock.timeZoneDots.remove(at: sender.tag)
            TimeZoneDot.save(clock.timeZoneDots, to: defaults)
            redraw()
        }
    }
    private func editDot(_ dot: TimeZoneDot, at index: Int?) {
        let alert = NSAlert()
        alert.messageText = index == nil ? "Add Time-Zone Dot" : "Edit Time-Zone Dot"
        alert.informativeText = "The dot follows the hour in this time zone. Choose a label and colour."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        let form = DotEditorView(dot: dot)
        alert.accessoryView = form
        alert.window.initialFirstResponder = form.name
        NSApp.activate(ignoringOtherApps: true)
        defer {
            form.color.deactivate()
            NSColorPanel.shared.orderOut(nil)
        }
        while alert.runModal() == .alertFirstButtonReturn {
            let identifier = form.zone.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let label = form.name.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let timeZone = TimeZone(identifier: identifier), !label.isEmpty, label.count <= 24 else {
                alert.informativeText = "Choose a valid time zone, such as America/New_York, and a label of 1–24 characters."
                continue
            }
            let color = form.color.color.usingColorSpace(.sRGB)!
            var updated = dot
            updated.timeZoneIdentifier = timeZone.identifier
            updated.label = label
            updated.color = DotColor(red: color.redComponent, green: color.greenComponent, blue: color.blueComponent)
            if let index {
                clock.timeZoneDots[index] = updated
            } else {
                clock.timeZoneDots.append(updated)
            }
            clock.showsAlternateTime = true
            TimeZoneDot.save(clock.timeZoneDots, to: defaults)
            defaults.set(true, forKey: "showsAlternateTime")
            redraw()
            break
        }
    }
    @objc private func changeSize(_ sender: NSMenuItem) {
        let center = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        let size = CGFloat(sender.tag)
        panel.setFrame(NSRect(x: center.x - size / 2, y: center.y - size / 2,
                              width: size, height: size), display: true)
        keepOnScreen()
        defaults.set(panel.frame.width, forKey: "diameter")
        redraw()
    }
    @objc private func changeFaceOpacity(_ sender: NSMenuItem) {
        clock.faceOpacity = CGFloat(sender.tag) / 100
        defaults.set(clock.faceOpacity, forKey: "faceOpacity")
        redraw()
    }
    @objc private func changeInkOpacity(_ sender: NSMenuItem) {
        clock.inkOpacity = CGFloat(sender.tag) / 100
        defaults.set(clock.inkOpacity, forKey: "inkOpacity")
        redraw()
    }
    @objc private func recenter() {
        centerClock(size: panel.frame.width)
        updateMenu()
    }
    @objc private func quit() { NSApp.terminate(nil) }
    private func redraw() { clock.needsDisplay = true; updateMenu() }
}

final class DotEditorView: NSView {
    let name = NSTextField(frame: NSRect(x: 0, y: 102, width: 340, height: 24))
    let zone = NSComboBox(frame: NSRect(x: 0, y: 46, width: 340, height: 26))
    let color = NSColorWell(frame: NSRect(x: 70, y: 0, width: 64, height: 30))

    init(dot: TimeZoneDot) {
        super.init(frame: NSRect(x: 0, y: 0, width: 340, height: 150))
        for (title, y) in [("Label (up to 24 characters)", 130.0), ("Time zone", 74.0), ("Colour", 6.0)] {
            let label = NSTextField(labelWithString: title)
            label.frame = NSRect(x: 0, y: y, width: 340, height: 18)
            addSubview(label)
        }
        name.stringValue = dot.label
        name.placeholderString = "City or person’s name"
        zone.addItems(withObjectValues: TimeZone.knownTimeZoneIdentifiers.sorted())
        zone.completes = true
        zone.numberOfVisibleItems = 10
        zone.stringValue = dot.timeZoneIdentifier
        color.color = dot.color.nsColor
        for view in [name, zone, color] { addSubview(view) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private extension DotColor {
    var nsColor: NSColor { NSColor(srgbRed: red, green: green, blue: blue, alpha: 1) }
}

private extension NSRect {
    var area: CGFloat { isNull ? 0 : width * height }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
if CommandLine.arguments.count == 3,
   ["--snapshot", "--snapshot-dots", "--snapshot-overlap", "--snapshot-editor"].contains(CommandLine.arguments[1]) {
    let clock = ClockView(frame: NSRect(x: 0, y: 0, width: 600, height: 600))
    clock.displayedDate = ISO8601DateFormatter().date(from: "2026-11-17T09:49:42Z")
    if CommandLine.arguments[1] == "--snapshot-dots" {
        clock.timeZoneDots = [.eastCoast,
            TimeZoneDot(label: "London", timeZoneIdentifier: "Europe/London",
                        color: DotColor(red: 0.1, green: 0.5, blue: 1)),
            TimeZoneDot(label: "Tokyo", timeZoneIdentifier: "Asia/Tokyo",
                        color: DotColor(red: 0.5, green: 0.2, blue: 0.9))]
    }
    if CommandLine.arguments[1] == "--snapshot-overlap" {
        clock.timeZoneDots = [.eastCoast,
            TimeZoneDot(label: "Lima", timeZoneIdentifier: "America/Lima",
                        color: DotColor(red: 0.1, green: 0.5, blue: 1)),
            TimeZoneDot(label: "Bangkok", timeZoneIdentifier: "Asia/Bangkok",
                        color: DotColor(red: 0.5, green: 0.2, blue: 0.9))]
    }
    let view: NSView = CommandLine.arguments[1] == "--snapshot-editor" ? DotEditorView(dot: .eastCoast) : clock
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
                                  pixelsWide: Int(view.bounds.width * 2), pixelsHigh: Int(view.bounds.height * 2),
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB,
                                  bytesPerRow: 0, bitsPerPixel: 0)!
    bitmap.size = view.bounds.size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    if view === clock {
        view.draw(view.bounds)
    } else {
        NSColor.windowBackgroundColor.setFill()
        view.bounds.fill()
        view.displayIgnoringOpacity(view.bounds, in: NSGraphicsContext.current!)
    }
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(
        to: URL(fileURLWithPath: CommandLine.arguments[2]))
} else {
    let delegate = ClockApp()
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
