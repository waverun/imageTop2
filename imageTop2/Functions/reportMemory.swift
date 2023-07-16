import MachO

func reportMemory() -> String {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
    let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }

    if kerr == KERN_SUCCESS {
        let usedMB = Float(info.resident_size) / 1024.0 / 1024.0
        return "Memory used in MB: \(usedMB)"
    } else {
        return "Error with task_info(): " +
        (String(cString: mach_error_string(kerr), encoding: .ascii) ?? "unknown error")
    }
}
