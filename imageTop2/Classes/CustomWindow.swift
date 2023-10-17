import AppKit

var gClosingDueToEscapeKey = false

class CustomWindow: NSWindow {
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
            case 53: // Escape key code
                gClosingDueToEscapeKey = true
                self.close()
            default:
                super.keyDown(with: event)
        }
    }
}
