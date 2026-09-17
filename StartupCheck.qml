import QtQuick
import qs.Common

QtObject {
    function check(done) {
        Proc.runCommand("dmsBluetoothBatteryMonitor.checkBluetoothctl", ["which", "bluetoothctl"], (stdout, exitCode) => {
            if (exitCode !== 0) {
                done({
                    title: "bluetoothctl is required",
                    details: "Install BlueZ and ensure bluetoothctl is available on PATH, then re-enable Bluetooth Battery Monitor."
                })
                return
            }

            Proc.runCommand("dmsBluetoothBatteryMonitor.checkNotifySend", ["which", "notify-send"], (notifyStdout, notifyExitCode) => {
                if (notifyExitCode !== 0) {
                    done({
                        title: "notify-send is required",
                        details: "Install libnotify and ensure notify-send is available on PATH, then re-enable Bluetooth Battery Monitor."
                    })
                    return
                }

                done(null)
            })
        })
    }
}
