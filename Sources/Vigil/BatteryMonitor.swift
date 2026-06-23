import Foundation
import IOKit.ps

struct BatterySnapshot {
    var percent: Int          // 0...100, -1 если нет батареи (десктоп)
    var isCharging: Bool
    var onAC: Bool
    var hasBattery: Bool
}

enum BatteryMonitor {
    static func read() -> BatterySnapshot {
        guard
            let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef],
            let source = sources.first,
            let desc = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any]
        else {
            return BatterySnapshot(percent: -1, isCharging: false, onAC: true, hasBattery: false)
        }

        let cur = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
        let max = desc[kIOPSMaxCapacityKey] as? Int ?? 100
        let pct = max > 0 ? Int(round(Double(cur) / Double(max) * 100)) : 0
        let state = desc[kIOPSPowerSourceStateKey] as? String ?? kIOPSACPowerValue
        let onAC = (state == kIOPSACPowerValue)
        let charging = desc[kIOPSIsChargingKey] as? Bool ?? false

        return BatterySnapshot(percent: pct, isCharging: charging, onAC: onAC, hasBattery: true)
    }
}
