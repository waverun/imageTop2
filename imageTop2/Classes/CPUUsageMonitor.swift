import SwiftUI

class CPUUsageMonitor {
    private var previousTotalTicks: UInt64 = 0
    private var previousIdleTicks: UInt64 = 0

    func update() -> Double? {
        var cpuLoad: host_cpu_load_info_data_t = host_cpu_load_info_data_t()
        var count: mach_msg_type_number_t = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &cpuLoad) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            print("Failed to get CPU usage")
            return nil
        }
        let totalTicks = UInt64(cpuLoad.cpu_ticks.0 + cpuLoad.cpu_ticks.1 + cpuLoad.cpu_ticks.2 + cpuLoad.cpu_ticks.3)
        let idleTicks = UInt64(cpuLoad.cpu_ticks.3)

        let totalDelta = totalTicks - previousTotalTicks
        let idleDelta = idleTicks - previousIdleTicks

        let usage = 100.0 * (Double(totalDelta) - Double(idleDelta)) / Double(totalDelta)

        previousTotalTicks = totalTicks
        previousIdleTicks = idleTicks

        return usage
    }
}
