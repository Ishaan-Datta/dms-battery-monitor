import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "dmsBluetoothBatteryMonitor"

    property var devices: []
    property int editingIndex: -1

    function normalizeMac(mac) {
        return String(mac ?? "").trim().toUpperCase()
    }

    function loadDevice(index) {
        const device = devices[index]
        if (!device)
            return

        editingIndex = index
        macField.text = device.mac ?? ""
        warningField.text = String(device.warningThreshold ?? 30)
        criticalField.text = String(device.criticalThreshold ?? 15)
        cooldownField.text = String(device.reminderCooldownMinutes ?? 60)
        ensureItemVisible(editorCard)
    }

    function clearEditor() {
        editingIndex = -1
        macField.text = ""
        warningField.text = "30"
        criticalField.text = "15"
        cooldownField.text = "60"
    }

    function saveDevice() {
        const mac = normalizeMac(macField.text)
        const warning = Number(warningField.text)
        const critical = Number(criticalField.text)
        const cooldown = Number(cooldownField.text)
        const macPattern = /^([0-9A-F]{2}:){5}[0-9A-F]{2}$/

        if (!macPattern.test(mac)) {
            ToastService.showError("Enter a valid Bluetooth MAC address")
            return
        }
        if (!Number.isInteger(warning) || warning < 2 || warning > 100) {
            ToastService.showError("Warning threshold must be an integer from 2 to 100")
            return
        }
        if (!Number.isInteger(critical) || critical < 1 || critical > 100) {
            ToastService.showError("Critical threshold must be an integer from 1 to 100")
            return
        }
        if (critical >= warning) {
            ToastService.showError("Critical threshold must be lower than warning threshold")
            return
        }
        if (!Number.isInteger(cooldown) || cooldown < 1 || cooldown > 10080) {
            ToastService.showError("Reminder cooldown must be between 1 and 10080 minutes")
            return
        }

        const duplicateIndex = devices.findIndex((device, index) => index !== editingIndex && normalizeMac(device.mac) === mac)
        if (duplicateIndex !== -1) {
            ToastService.showError("That Bluetooth device is already configured")
            return
        }

        const nextDevice = {
            mac: mac,
            warningThreshold: warning,
            criticalThreshold: critical,
            reminderCooldownMinutes: cooldown
        }
        const nextDevices = devices.slice()

        if (editingIndex === -1)
            nextDevices.push(nextDevice)
        else
            nextDevices[editingIndex] = nextDevice

        devices = nextDevices
        saveValue("devices", nextDevices)
        clearEditor()
    }

    function removeDevice(index) {
        const nextDevices = devices.slice()
        nextDevices.splice(index, 1)
        devices = nextDevices
        saveValue("devices", nextDevices)
        if (editingIndex === index)
            clearEditor()
        else if (editingIndex > index)
            editingIndex -= 1
    }

    QtObject {
        id: deviceSettingsLoader

        function loadValue() {
            root.devices = root.loadValue("devices", []) ?? []
        }
    }

    StyledText {
        width: parent.width
        text: "Bluetooth Battery Monitor"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Monitor selected Bluetooth devices in DankBar and receive warning and critical battery reminders. Device names come from their BlueZ aliases."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    SliderSetting {
        settingKey: "pollIntervalMinutes"
        label: "Polling interval"
        description: "How often to refresh battery information for all configured devices"
        defaultValue: 5
        minimum: 1
        maximum: 60
        unit: " min"
        rightIcon: "refresh"
    }

    StyledRect {
        id: editorCard
        width: parent.width
        height: editorColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: editorColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            Row {
                width: parent.width
                spacing: Theme.spacingM

                StyledText {
                    text: root.editingIndex === -1 ? "Add device" : "Edit device"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                DankButton {
                    text: "Cancel"
                    iconName: "close"
                    visible: root.editingIndex !== -1
                    onClicked: root.clearEditor()
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingXS

                StyledText {
                    text: "Bluetooth MAC address"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                DankTextField {
                    id: macField
                    width: parent.width
                    placeholderText: "AA:BB:CC:DD:EE:FF"
                    keyNavigationTab: warningField
                    onFocusStateChanged: function(hasFocus) {
                        if (hasFocus)
                            root.ensureItemVisible(macField)
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingXS

                StyledText {
                    text: "Warning threshold (%)"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                DankTextField {
                    id: warningField
                    width: parent.width
                    text: "30"
                    placeholderText: "30"
                    keyNavigationBacktab: macField
                    keyNavigationTab: criticalField
                    onFocusStateChanged: function(hasFocus) {
                        if (hasFocus)
                            root.ensureItemVisible(warningField)
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingXS

                StyledText {
                    text: "Critical threshold (%)"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                DankTextField {
                    id: criticalField
                    width: parent.width
                    text: "15"
                    placeholderText: "15"
                    keyNavigationBacktab: warningField
                    keyNavigationTab: cooldownField
                    onFocusStateChanged: function(hasFocus) {
                        if (hasFocus)
                            root.ensureItemVisible(criticalField)
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingXS

                StyledText {
                    text: "Reminder cooldown (minutes)"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                DankTextField {
                    id: cooldownField
                    width: parent.width
                    text: "60"
                    placeholderText: "60"
                    keyNavigationBacktab: criticalField
                    onFocusStateChanged: function(hasFocus) {
                        if (hasFocus)
                            root.ensureItemVisible(cooldownField)
                    }
                }
            }

            DankButton {
                text: root.editingIndex === -1 ? "Add device" : "Update device"
                iconName: root.editingIndex === -1 ? "add" : "check"
                onClicked: root.saveDevice()
            }
        }
    }

    StyledText {
        width: parent.width
        text: "Configured devices"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "No devices configured"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        horizontalAlignment: Text.AlignHCenter
        visible: root.devices.length === 0
    }

    Column {
        width: parent.width
        spacing: Theme.spacingS

        Repeater {
            model: root.devices

            StyledRect {
                required property int index
                required property var modelData

                width: parent.width
                height: deviceColumn.implicitHeight + Theme.spacingM * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainer

                Column {
                    id: deviceColumn
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    spacing: Theme.spacingS

                    Row {
                        width: parent.width
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "headphones"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            width: parent.width - Theme.iconSize - Theme.spacingS
                            text: modelData.mac
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            elide: Text.ElideRight
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    StyledText {
                        width: parent.width
                        text: "Warning at " + modelData.warningThreshold + "% | Critical at " + modelData.criticalThreshold + "% | Remind every " + modelData.reminderCooldownMinutes + " min"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }

                    Row {
                        spacing: Theme.spacingS

                        DankButton {
                            text: "Edit"
                            iconName: "edit"
                            onClicked: root.loadDevice(index)
                        }

                        DankButton {
                            text: "Remove"
                            iconName: "delete"
                            onClicked: root.removeDevice(index)
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: deviceSettingsLoader.loadValue()
}
