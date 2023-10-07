import SwiftUI
import Darwin

// Your function:
func hostCPULoadInfo() -> host_cpu_load_info? {
    let HOST_CPU_LOAD_INFO_COUNT = MemoryLayout<host_cpu_load_info>.stride/MemoryLayout<integer_t>.stride
    var size = mach_msg_type_number_t(HOST_CPU_LOAD_INFO_COUNT)
    var cpuLoadInfo = host_cpu_load_info()

    let result = withUnsafeMutablePointer(to: &cpuLoadInfo) {
        $0.withMemoryRebound(to: integer_t.self, capacity: HOST_CPU_LOAD_INFO_COUNT) {
            host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
        }
    }
    if result != KERN_SUCCESS {
        print("Error  - \(#file): \(#function) - kern_result_t = \(result)")
        return nil
    }
    return cpuLoadInfo
}

// New function to calculate CPU load:
func calculateCPULoad() -> Double? {
    guard let startLoadInfo = hostCPULoadInfo() else { return nil }
    usleep(500000)  // sleep for half a second
    guard let endLoadInfo = hostCPULoadInfo() else { return nil }

    let userDiff = endLoadInfo.cpu_ticks.0 - startLoadInfo.cpu_ticks.0
    let systemDiff = endLoadInfo.cpu_ticks.1 - startLoadInfo.cpu_ticks.1
    let idleDiff = endLoadInfo.cpu_ticks.2 - startLoadInfo.cpu_ticks.2
    let niceDiff = endLoadInfo.cpu_ticks.3 - startLoadInfo.cpu_ticks.3

    let totalTicks = userDiff + systemDiff + idleDiff + niceDiff
    let busyTicks = userDiff + systemDiff + niceDiff

    if totalTicks > 0 {
        let load = Double(busyTicks) / Double(totalTicks)
        return load * 100  // convert to percentage
    } else {
        return nil
    }
}
