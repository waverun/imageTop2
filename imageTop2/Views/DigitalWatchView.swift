//import SwiftUI
//
//struct DigitalWatchView: View {
//    let backgroundColor = Color.black.opacity(0.6)
//    let timeFont = Font.system(size: 80, weight: .bold, design: .rounded)
//    let cpuUsage = getCpuUsage()
//
//    @State  var watchPosition = CGPoint(x: 0, y: 0)
//    @State  var timeString = ""
//
//    let x: CGFloat?
//    let y: CGFloat?
//
//    @ViewBuilder var body: some View {
//        Text(timeString)
//            .font(timeFont)
//            .foregroundColor(.white)
//            .frame(width: 250, height: 100)
//            .background(backgroundColor)
//            .cornerRadius(10)
//            .position(watchPosition)
//            .onAppear {
//                updateTime()
//                iPrint("watchPosition: \(x!), \(y!)")
//                watchPosition = CGPoint(x: x ?? 100, y: y ?? 100)
//            }
//            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
//                updateTime()
//            }
//    }
//
//     func updateTime() {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "HH:mm"
//        timeString = formatter.string(from: Date())
//        print("CPU Usage: \(cpuUsage)%")
//        timeString = cpuUsage
//    }
//}

import SwiftUI

struct DigitalWatchView: View {
    @EnvironmentObject var appDelegate: AppDelegate

    let backgroundColor = Color.black.opacity(0.6)
    let timeFont = Font.system(size: 80, weight: .bold, design: .rounded)
//    let monitor = CPUUsageMonitor()

    @Binding var timerIsActive: Bool  // External condition binding

    @State private var watchPosition = CGPoint(x: 0, y: 0)
    @State private var timeString = ""
    @State private var timer: Timer? = nil

    let x: CGFloat?
    let y: CGFloat?

    @ViewBuilder var body: some View {
        Text(timeString)
            .font(timeFont)
            .foregroundColor(.white)
            .frame(width: 250, height: 100)
            .background(backgroundColor)
            .cornerRadius(10)
            .position(watchPosition)
            .onAppear {
                updateTime()
                handleTimerChange(isActive: timerIsActive)
                iPrint("watchPosition: \(x ?? 100), \(y ?? 100)")
                watchPosition = CGPoint(x: x ?? 100, y: y ?? 100)
            }
            .onChange(of: timerIsActive) { newValue in
                handleTimerChange(isActive: newValue)
            }
            .blur(radius: appDelegate.isVideoBlurred ? 20 : 0)
    }

    func handleTimerChange(isActive: Bool) {
        if isActive {
            if timer == nil {
                timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                    updateTime()
                }
            }
        } else {
            timer?.invalidate()
            timer = nil
        }
    }

    func updateTime() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        switch true {
            case appDelegate.showWatchOrCpu:
                timeString = formatter.string(from: Date())
            case appDelegate.showCpu: 
//                timeString = getCpuUsage() ?? ""
//                // Note: getCpuUsage() and iPrint() weren't defined in the provided code, so they are commented out
//                print("CPU Usage: \(String(describing: getCpuUsage()))%")
//                if let usage = monitor.update() {
//                    print(String(format: "CPU Usage monitor: %.2f%%", usage))
//                }
//                let loadInfo = hostCPULoadInfo()
//                print("CPU Usage loadInfo: \(String(describing: loadInfo))")
                let cpuLoad = calculateCPULoad()
                if let cpuLoad = cpuLoad {
                    print("CPU Load: \(cpuLoad)%")
                    timeString = String(format: "%.2f%", cpuLoad)
                }
                // iPrint("Time updated")
            default: break
        }
    }
}
