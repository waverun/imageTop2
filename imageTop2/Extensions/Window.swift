
import Foundation
import SwiftUI

extension Window {
    override func close() {
        self.orderOut(NSApp)
    }
}
}
