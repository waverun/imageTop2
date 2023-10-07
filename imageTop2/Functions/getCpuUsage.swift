//import Foundation
//import Darwin
//
//func getCpuUsage() -> String? {
//    var cpuLoad: host_cpu_load_info_data_t = host_cpu_load_info_data_t()
//    var count: mach_msg_type_number_t = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
//    let result = withUnsafeMutablePointer(to: &cpuLoad) {
//        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
//            host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
//        }
//    }
//    guard result == KERN_SUCCESS else {
//        print("Failed to get CPU usage")
//        return nil
//    }
//    let totalTicks = cpuLoad.cpu_ticks.0 + cpuLoad.cpu_ticks.1 + cpuLoad.cpu_ticks.2 + cpuLoad.cpu_ticks.3
//    let idleTicks = cpuLoad.cpu_ticks.3
//    let usedTicks = totalTicks - idleTicks
//    let cpuUsage = Double(usedTicks) / Double(totalTicks) * 100.0
//    let cpu = String(format: "%.2f", cpuUsage)
//    return cpu
//}
//
//func getCpuUsage() -> String {
//    var totalUser: natural_t = 0
//    var totalUserNice: natural_t = 0
//    var totalSystem: natural_t = 0
//    var totalIdle: natural_t = 0
//
//    var processorInfo: processor_info_array_t?
//    var processorMsgCount: mach_msg_type_number_t = 0
//    var processorCount: natural_t = 0
//
//    let host = mach_host_self()
//
//    let result = host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &processorCount, &processorInfo, &processorMsgCount)
//
//    guard result == KERN_SUCCESS else {
//        print("Failed to get CPU usage")
//        return "N/A"
//    }
//
//    let processorStats = UnsafeBufferPointer(start: processorInfo, count: Int(processorMsgCount))
//
//    for i in stride(from: 0, to: Int(processorMsgCount), by: Int(CPU_STATE_MAX)) {
//        totalUser += natural_t(processorStats[i + Int(CPU_STATE_USER)])
//        totalUserNice += natural_t(processorStats[i + Int(CPU_STATE_NICE)])
//        totalSystem += natural_t(processorStats[i + Int(CPU_STATE_SYSTEM)])
//        totalIdle += natural_t(processorStats[i + Int(CPU_STATE_IDLE)])
//    }
//
//    let total = totalUser + totalUserNice + totalSystem + totalIdle
//    let totalUsage = totalUser + totalUserNice + totalSystem
//
//    let cpuUsage = Float(totalUsage) / Float(total) * 100.0
//    let cpu = String(format: "%.2f", cpuUsage)
////    print("getCpuUsage cpu: \(cpu)")
//    return cpu
//}

//let cpuUsage = getCpuUsage()
//print("CPU Usage: \(cpuUsage)%")
