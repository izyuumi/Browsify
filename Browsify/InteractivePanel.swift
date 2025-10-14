//
//  InteractivePanel.swift
//  Browsify
//
//  Custom NSPanel that accepts user interaction while maintaining accessory app status
//

import AppKit

class InteractivePanel: NSPanel {
    override var canBecomeKey: Bool {
        // Allow the panel to become key so it can accept input
        NSLog("[InteractivePanel] canBecomeKey called, returning true")
        return true
    }

    override var canBecomeMain: Bool {
        // Prevent the panel from becoming main to avoid full app activation
        return false
    }

    override func becomeKey() {
        NSLog("[InteractivePanel] Panel becoming key")
        super.becomeKey()
    }

    override func resignKey() {
        NSLog("[InteractivePanel] Panel resigning key")
        super.resignKey()
    }

    override func mouseDown(with event: NSEvent) {
        NSLog("[InteractivePanel] mouseDown event received. isKeyWindow: \(self.isKeyWindow)")
        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        NSLog("[InteractivePanel] mouseUp event received. isKeyWindow: \(self.isKeyWindow)")
        super.mouseUp(with: event)
    }
}

// Custom NSView that accepts first mouse for click-through behavior
class ClickThroughView: NSView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        NSLog("[ClickThroughView] acceptsFirstMouse called, returning true")
        return true
    }
}
