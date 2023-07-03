import SwiftUI

struct KeyView: NSViewRepresentable {
    let dismiss: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            if $0.keyCode == 53 {
                self.dismiss()
                print("dismiss")
                return nil
            } else {
                return $0
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
