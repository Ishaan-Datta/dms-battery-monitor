import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Modules.Plugins

PluginComponent {
    id: root

    Item {}

    readonly property var configuredDevices: pluginData.devices ?? []
    readonly property int pollIntervalMinutes: Math.max(1, Number(pluginData.pollIntervalMinutes ?? 5))

    property bool pollInProgress: false
    property bool pollPending: false
    property int pollIndex: 0
    property var pollQueue: []
    property var workingStates: []
    property var alertStates: ({})
    property int connectionRefreshAttempts: 0

    Timer {
        id: pollTimer
        interval: root.pollIntervalMinutes * 60 * 1000
        repeat: true
        running: false
        onTriggered: root.requestPoll()
    }

    Timer {
        id: connectionRefreshTimer
        interval: 2000
        repeat: true
        running: false
        onTriggered: {
            root.connectionRefreshAttempts += 1
            console.info("BluetoothBatteryMonitor: connection refresh attempt", root.connectionRefreshAttempts)
            root.requestPoll()
            if (root.connectionRefreshAttempts >= 3)
                stop()
        }
    }

    Repeater {
        model: BluetoothService.pairedDevices

        Item {
            required property var modelData
            readonly property bool deviceConnected: modelData?.connected ?? false

            width: 0
            height: 0
            visible: false

            onDeviceConnectedChanged: root.handleDeviceConnectionChanged(modelData?.address ?? "", deviceConnected)
        }
    }

    Component {
        id: notificationProcess

        Process {
            property string notificationTitle: ""
            property string notificationBody: ""
            property string notificationUrgency: "normal"

            command: [
                "notify-send",
                "--app-name=Bluetooth Battery Monitor",
                "--icon=headphones",
                "--urgency=" + notificationUrgency,
                notificationTitle,
                notificationBody
            ]

            onExited: (exitCode, exitStatus) => {
                if (exitCode !== 0)
                    console.error("BluetoothBatteryMonitor: notify-send exited with code", exitCode)
                destroy()
            }
        }
    }

    function normalizeMac(mac) {
        return String(mac ?? "").trim().toUpperCase()
    }

    function normalizedConfig(device) {
        const warning = Number(device.warningThreshold)
        const critical = Number(device.criticalThreshold)
        const cooldown = Number(device.reminderCooldownMinutes)
        const safeWarning = Number.isInteger(warning) && warning >= 2 && warning <= 100 ? warning : 30
        return {
            mac: normalizeMac(device.mac),
            warningThreshold: safeWarning,
            criticalThreshold: Number.isInteger(critical) && critical >= 1 && critical < safeWarning ? critical : Math.max(1, Math.min(15, safeWarning - 1)),
            reminderCooldownMinutes: Number.isInteger(cooldown) && cooldown >= 1 ? cooldown : 60
        }
    }

    function updatePollTimer() {
        if (configuredDevices.length > 0)
            pollTimer.restart()
        else
            pollTimer.stop()
    }

    function isConfiguredMac(mac) {
        const normalizedMac = normalizeMac(mac)
        return configuredDevices.some(device => normalizeMac(device.mac) === normalizedMac)
    }

    function handleDeviceConnectionChanged(mac, connected) {
        if (!isConfiguredMac(mac))
            return

        if (connected) {
            console.info("BluetoothBatteryMonitor: configured device connected, scheduling battery refresh:", normalizeMac(mac))
            connectionRefreshAttempts = 0
            connectionRefreshTimer.restart()
        } else {
            console.info("BluetoothBatteryMonitor: configured device disconnected:", normalizeMac(mac))
            connectionRefreshTimer.stop()
            requestPoll()
        }
    }

    function requestPoll() {
        if (pollInProgress) {
            pollPending = true
            return
        }

        const devices = configuredDevices.map(normalizedConfig).filter(device => device.mac !== "")
        if (devices.length === 0) {
            console.warn("BluetoothBatteryMonitor: no devices configured")
            publishStates([])
            return
        }

        pollInProgress = true
        pollPending = false
        pollIndex = 0
        pollQueue = devices
        workingStates = []
        pruneAlertStates(devices)
        pollNextDevice()
    }

    function pruneAlertStates(devices) {
        const configuredMacs = devices.map(device => device.mac)
        const nextStates = {}

        configuredMacs.forEach(mac => {
            if (alertStates[mac] !== undefined)
                nextStates[mac] = alertStates[mac]
        })
        alertStates = nextStates
    }

    function pollNextDevice() {
        if (pollIndex >= pollQueue.length) {
            finishPoll()
            return
        }

        const device = pollQueue[pollIndex]
        const commandId = "dmsBluetoothBatteryMonitor.info." + device.mac.replace(/:/g, "")
        Proc.runCommand(commandId, ["bluetoothctl", "info", device.mac], (stdout, exitCode) => {
            workingStates = workingStates.concat([parseDeviceInfo(device, stdout, exitCode)])
            pollIndex += 1
            pollNextDevice()
        }, 0, 10000, root)
    }

    function parseDeviceInfo(device, output, exitCode) {
        const text = String(output ?? "")
        const aliasMatch = text.match(/^\s*Alias:\s*(.+)$/m)
        const connected = /^\s*Connected:\s*yes\s*$/mi.test(text)
        let battery = null

        const decimalMatch = text.match(/Battery Percentage:\s*(?:0x[0-9a-f]+\s*)?\(([0-9]+)\)/i)
        if (decimalMatch) {
            battery = Number(decimalMatch[1])
        } else {
            const hexMatch = text.match(/Battery Percentage:\s*0x([0-9a-f]+)/i)
            if (hexMatch)
                battery = parseInt(hexMatch[1], 16)
        }

        if (!Number.isInteger(battery) || battery < 0 || battery > 100)
            battery = null

        const available = exitCode === 0 && connected && battery !== null
        const severity = available ? severityForBattery(device, battery) : "none"
        const state = {
            mac: device.mac,
            alias: aliasMatch ? aliasMatch[1].trim() : device.mac,
            connected: connected,
            available: available,
            battery: battery,
            severity: severity,
            warningThreshold: device.warningThreshold,
            criticalThreshold: device.criticalThreshold,
            reminderCooldownMinutes: device.reminderCooldownMinutes,
            updatedAt: Date.now()
        }

        if (available)
            updateAlertState(state)

        return state
    }

    function severityForBattery(device, battery) {
        if (battery <= device.criticalThreshold)
            return "critical"
        if (battery <= device.warningThreshold)
            return "warning"
        return "none"
    }

    function updateAlertState(device) {
        const previous = alertStates[device.mac] ?? { severity: "none", lastNotifiedAt: 0 }
        const now = Date.now()
        const cooldownMs = Math.max(1, device.reminderCooldownMinutes) * 60 * 1000
        let shouldNotify = false

        if (device.severity === "none") {
            setAlertState(device.mac, { severity: "none", lastNotifiedAt: 0 })
            return
        }

        if (previous.severity === "none")
            shouldNotify = true
        else if (device.severity === "critical" && previous.severity !== "critical")
            shouldNotify = true
        else if (now - Number(previous.lastNotifiedAt ?? 0) >= cooldownMs)
            shouldNotify = true

        const lastNotifiedAt = shouldNotify ? now : Number(previous.lastNotifiedAt ?? 0)
        setAlertState(device.mac, {
            severity: device.severity,
            lastNotifiedAt: lastNotifiedAt
        })

        if (shouldNotify)
            sendBatteryNotification(device)
    }

    function setAlertState(mac, state) {
        const nextStates = Object.assign({}, alertStates)
        nextStates[mac] = state
        alertStates = nextStates
    }

    function sendBatteryNotification(device) {
        const critical = device.severity === "critical"
        const process = notificationProcess.createObject(root, {
            notificationTitle: device.alias + (critical ? " battery critical" : " battery low"),
            notificationBody: device.battery + "% remaining",
            notificationUrgency: critical ? "critical" : "normal"
        })
        process.running = true
    }

    function finishPoll() {
        pollInProgress = false
        publishStates(workingStates)
        persistAlertStates()

        if (pollPending)
            Qt.callLater(requestPoll)
    }

    function publishStates(states) {
        if (pluginService && pluginId)
            pluginService.setGlobalVar(pluginId, "deviceStates", states)
    }

    function persistAlertStates() {
        if (pluginService && pluginId)
            pluginService.savePluginState(pluginId, "alertStates", alertStates)
    }

    function initialize() {
        if (!pluginService || !pluginId)
            return

        alertStates = pluginService.loadPluginState(pluginId, "alertStates", {}) ?? {}
        publishStates([])
        updatePollTimer()
        requestPoll()
    }

    onConfiguredDevicesChanged: {
        updatePollTimer()
        requestPoll()
    }

    onPollIntervalMinutesChanged: updatePollTimer()

    onPluginServiceChanged: Qt.callLater(initialize)

    Component.onCompleted: Qt.callLater(initialize)

    Component.onDestruction: {
        pollTimer.stop()
        connectionRefreshTimer.stop()
        pollPending = false
    }
}
