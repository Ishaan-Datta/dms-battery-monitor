import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root
    layerNamespacePlugin: "bluetooth-battery-monitor"

    PluginGlobalVar {
        id: sharedDeviceStates
        varName: "deviceStates"
        defaultValue: []
    }

    readonly property var deviceStates: sharedDeviceStates.value ?? []
    readonly property var availableDevices: deviceStates.filter(device => device.available)
    readonly property int configuredDeviceCount: (pluginData.devices ?? []).length
    readonly property bool needsConfiguration: configuredDeviceCount === 0
    readonly property int visibleDeviceRows: Math.min(Math.max(deviceStates.length, 1), 4)
    readonly property real deviceRowHeight: Math.max(Theme.iconSize, Theme.fontSizeMedium + Theme.fontSizeSmall + Theme.spacingXS) + Theme.spacingM * 2
    readonly property real deviceListViewportHeight: deviceStates.length === 0 ? 48 : visibleDeviceRows * deviceRowHeight + (visibleDeviceRows - 1) * Theme.spacingS

    function batteryColor(severity) {
        if (severity === "critical")
            return Theme.error
        if (severity === "warning")
            return Theme.warning
        return Theme.widgetTextColor
    }

    function barIconColor(severity) {
        if (severity === "critical")
            return Theme.error
        if (severity === "warning")
            return Theme.warning
        return Theme.widgetIconColor
    }

    function updateVisibility() {
        setVisibilityOverride(needsConfiguration || availableDevices.length > 0)
    }

    onAvailableDevicesChanged: updateVisibility()
    onNeedsConfigurationChanged: updateVisibility()
    Component.onCompleted: updateVisibility()

    popoutWidth: 400
    popoutHeight: needsConfiguration ? 270 : deviceListViewportHeight + 100

    popoutContent: Component {
        PopoutComponent {
            id: batteryPopout
            headerText: "Bluetooth batteries"
            detailsText: root.needsConfiguration ? "Add at least one Bluetooth device to begin monitoring." : ""
            showCloseButton: true

            Item {
                width: parent.width
                implicitHeight: root.needsConfiguration ? 180 : root.deviceListViewportHeight

                Column {
                    anchors.centerIn: parent
                    width: parent.width - Theme.spacingL * 2
                    spacing: Theme.spacingM
                    visible: root.needsConfiguration

                    DankIcon {
                        name: "headphones"
                        size: Theme.iconSizeLarge
                        color: Theme.primary
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        width: parent.width
                        text: "No devices configured"
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.widgetTextColor
                        horizontalAlignment: Text.AlignHCenter
                    }

                    StyledText {
                        width: parent.width
                        text: "Create ~/.config/DankMaterialShell/plugin_settings.json and add a Bluetooth MAC address."
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.withAlpha(Theme.widgetTextColor, 0.7)
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                }

                Column {
                    anchors.fill: parent
                    spacing: Theme.spacingM
                    visible: !root.needsConfiguration

                    Flickable {
                        width: parent.width
                        height: parent.height
                        contentWidth: width
                        contentHeight: deviceList.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: contentHeight > height

                        Column {
                            id: deviceList
                            width: parent.width
                            spacing: Theme.spacingS

                            StyledText {
                                width: parent.width
                                text: "Refreshing device status..."
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.withAlpha(Theme.widgetTextColor, 0.7)
                                horizontalAlignment: Text.AlignHCenter
                                visible: root.deviceStates.length === 0
                            }

                            Repeater {
                                model: root.deviceStates

                                StyledRect {
                                    required property var modelData
                                    width: deviceList.width
                                    height: root.deviceRowHeight
                                    radius: Theme.cornerRadius
                                    color: Theme.surfaceContainerHigh

                                    Row {
                                        id: statusRow
                                        anchors.fill: parent
                                        anchors.margins: Theme.spacingM
                                        spacing: Theme.spacingM

                                        DankIcon {
                                            name: "headphones"
                                            size: Theme.iconSize
                                            color: modelData.available ? root.batteryColor(modelData.severity) : Theme.surfaceVariantText
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Column {
                                            width: parent.width - batteryStatus.width - Theme.iconSize - Theme.spacingM * 2
                                            spacing: Theme.spacingXS
                                            anchors.verticalCenter: parent.verticalCenter

                                            StyledText {
                                                width: parent.width
                                                text: modelData.alias
                                                font.pixelSize: Theme.fontSizeMedium
                                                font.weight: Font.Medium
                                                color: Theme.widgetTextColor
                                                elide: Text.ElideRight
                                            }

                                            StyledText {
                                                width: parent.width
                                                text: modelData.mac
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.withAlpha(Theme.widgetTextColor, 0.7)
                                                elide: Text.ElideRight
                                            }
                                        }

                                        StyledText {
                                            id: batteryStatus
                                            text: modelData.available ? modelData.battery + "%" : (modelData.connected ? "No battery" : "Disconnected")
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Font.Medium
                                            color: modelData.available ? root.batteryColor(modelData.severity) : Theme.withAlpha(Theme.widgetTextColor, 0.7)
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }
                            }
                        }
                    }

                }
            }
        }
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingM

            Repeater {
                model: root.availableDevices

                Row {
                    required property var modelData
                    spacing: Theme.spacingXS

                    DankIcon {
                        name: "headphones"
                        size: root.iconSize
                        color: root.barIconColor(parent.modelData.severity)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: parent.modelData.battery + "%"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.widgetTextColor
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Row {
                visible: root.needsConfiguration
                spacing: Theme.spacingXS

                DankIcon {
                    name: "headphones"
                    size: root.iconSize
                    color: Theme.widgetIconColor
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: "Setup"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.widgetTextColor
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingS

            Repeater {
                model: root.availableDevices

                Column {
                    required property var modelData
                    spacing: Theme.spacingXS

                    DankIcon {
                        name: "headphones"
                        size: root.iconSize
                        color: root.barIconColor(parent.modelData.severity)
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        text: parent.modelData.battery + "%"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.widgetTextColor
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }

            Column {
                visible: root.needsConfiguration
                spacing: Theme.spacingXS

                DankIcon {
                    name: "headphones"
                    size: root.iconSize
                    color: Theme.widgetIconColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: "Setup"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.widgetTextColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
}
