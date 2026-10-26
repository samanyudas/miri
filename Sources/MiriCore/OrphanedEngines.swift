import Darwin

/// Engines that outlived the app that started them. An engine whose parent is launchd has no app to stop it, but
/// it still manages windows and holds the Mach service, so a new engine cannot start.
public enum OrphanedEngines {
    /// The process IDs of running processes named `executableName` whose parent is launchd.
    public static func find(executableName: String = "miri-engine") -> [pid_t] {
        let capacity = proc_listallpids(nil, 0)
        guard capacity > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(capacity) * 2)
        let count = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        return pids.prefix(Int(max(count, 0))).filter { pid in
            pid > 0 && parent(of: pid) == 1 && self.executableName(of: pid) == executableName
        }
    }

    /// Interrupts each process so its cleanup runs, kills any that still run after `timeout`, and returns once they
    /// are gone, so a new engine can take the Mach service.
    public static func stop(_ pids: [pid_t], timeout: Duration) {
        for pid in pids { kill(pid, SIGINT) }
        let survivors = waitForExit(pids, timeout: timeout)
        for pid in survivors { kill(pid, SIGKILL) }
        _ = waitForExit(survivors, timeout: .seconds(1))
    }

    /// The processes that still run after `timeout`.
    private static func waitForExit(_ pids: [pid_t], timeout: Duration) -> [pid_t] {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        var running = pids.filter { kill($0, 0) == 0 }
        while !running.isEmpty, clock.now < deadline {
            usleep(20_000)
            running = running.filter { kill($0, 0) == 0 }
        }
        return running
    }

    private static func parent(of pid: pid_t) -> pid_t? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
        return pid_t(info.pbi_ppid)
    }

    private static func executableName(of pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return String(cString: buffer).split(separator: "/").last.map(String.init)
    }
}
