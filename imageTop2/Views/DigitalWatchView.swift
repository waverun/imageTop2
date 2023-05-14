import SwiftUI

struct DigitalWatchView: View {
    let backgroundColor = Color.black.opacity(0.6)
    let timeFont = Font.system(size: 80, weight: .bold, design: .rounded)
    @State private var watchPosition = CGPoint(x: 0, y: 0)
    @State private var timeString = ""

    let x: CGFloat?
    let y: CGFloat?
    
    var body: some View {
        Text(timeString)
            .font(timeFont)
            .foregroundColor(.white)
            .frame(width: 250, height: 100)
            .background(backgroundColor)
            .cornerRadius(10)
            .position(watchPosition)
            .onAppear {
                updateTime()
                watchPosition = CGPoint(x: x ?? 100, y: y ?? 100)
            }
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                updateTime()
            }
    }
    
    private func updateTime() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        timeString = formatter.string(from: Date())
    }
}
