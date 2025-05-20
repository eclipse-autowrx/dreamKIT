import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "."  // Import local ToggleButton.qml and ModeControl.qml
import ControlsAsync 1.0

Rectangle {
    id: rectangle
    anchors.fill: parent
    color: "#212121"           // Dark background (near black)
    border.color: "#1E1E1E"    // Optional: greenish border like your original
    border.width: 2

    property int columnSpacing: 50
    property int buttonSpacing: 70

    ControlsAsync {
        id: controlPageAsync

        onUpdateWidget_lightCtr_lowBeam: (sts) => {
            lowbeamBtn.checked = sts
        }
        onUpdateWidget_lightCtr_highBeam: (sts) => {
            highbeamBtn.checked = sts
        }
        onUpdateWidget_lightCtr_Hazard: (sts) => {
            hazardBtn.checked = sts
        }
        onUpdateWidget_lightCtr_ambient_mode: (mode) => {
            ambientControl.mode = mode
        }
        onUpdateWidget_lightCtr_ambient_intensity: (intensity) => {
            intensitySlider.value = intensity
        }
        onUpdateWidget_gear_mode: (mode) => {
            gearButtons.selectGear(mode) 
        }
        onUpdateWidget_door_driverSide_isOpen: (sts) => {
            doorLeftBtn.checked = sts
        }
        onUpdateWidget_door_passengerSide_isOpen: (sts) => {
            doorRightBtn.checked = sts
        }
        onUpdateWidget_trunk_rear_isOpen: (sts) => {
            trunkBtn.checked = sts
        }
        onUpdateWidget_hvac_driverSide_FanSpeed: (speed) => {
            fanSpeedLeft.mode = speed
        }
        onUpdateWidget_hvac_passengerSide_FanSpeed: (speed) => {
            fanSpeedRight.mode = speed
        }
    }

    ScrollView {
        anchors.fill: parent
        clip: true

        Component.onCompleted: {
            controlPageAsync.init()
        }

        ColumnLayout {
            id: mainColumn
            x: 70
            width: parent.width
            spacing: columnSpacing
            Layout.margins: 70

            // Light Control
            RowLayout {
                Layout.fillWidth: true
                spacing: 100

                Label {
                    text: "Light Control "
                    font.pixelSize: 24
                    font.family: "Segoe UI"
                    font.bold: true
                    color: "#70BCC9"
                    Layout.preferredWidth: 160
                    verticalAlignment: Label.AlignVCenter
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: buttonSpacing

                    ToggleButton { 
                        id: lowbeamBtn; text: "Lowbeam"; Layout.preferredWidth: 130 
                        onToggledChanged: {
                            // console.log("Lowbeam checked changed: ", checked)
                            controlPageAsync.qml_setApi_lightCtr_LowBeam(checked)
                        }
                    }
                    ToggleButton { 
                        id: highbeamBtn; text: "Highbeam"; Layout.preferredWidth: 130 
                        onToggledChanged: {
                            // console.log("Highbeam checked changed: ", checked)
                            controlPageAsync.qml_setApi_lightCtr_HighBeam(checked)
                        }
                    }
                    ToggleButton { 
                        id: hazardBtn; text: "Hazard"; Layout.preferredWidth: 130 
                        onToggledChanged: {
                            controlPageAsync.qml_setApi_lightCtr_Hazard(checked)
                        }
                    }
                }
            }

            // Separator
            Rectangle {
                color: "#444444"
                height: 1
                Layout.fillWidth: true
            }

            // Ambient Control
            RowLayout {
                Layout.fillWidth: true
                spacing: 100

                Label {
                    text: "Ambient Control "
                    font.pixelSize: 24
                    font.family: "Segoe UI"
                    font.bold: true
                    color: "#70BCC9"
                    Layout.preferredWidth: 160
                    verticalAlignment: Label.AlignVCenter
                }

                ModeControl {
                    id: ambientControl
                    maxMode: 7
                    Layout.fillWidth: true
                    onModeChangedOnPressedChanged: {
                        console.log("ambientControl mode changed: ", mode)
                        controlPageAsync.qml_setApi_ambient_mode(mode)
                    }
                }

                Slider {
                    id: intensitySlider
                    from: 0
                    stepSize: 1
                    to: 255
                    value: 0

                    onValueChanged: {
                        // console.log("Intensity changed: ", value)
                        // console.log("pressed: ", pressed)
                        if (pressed) {
                            controlPageAsync.qml_setApi_ambient_intensity(value)
                        }
                    }

                    background: Rectangle {
                        x: intensitySlider.leftPadding
                        y: intensitySlider.topPadding + intensitySlider.availableHeight / 2 - height / 2
                        implicitWidth: 300
                        implicitHeight: 4
                        width: intensitySlider.availableWidth
                        height: implicitHeight
                        radius: 2
                        color: "#bdbebf"

                        Rectangle {
                            width: intensitySlider.visualPosition * parent.width
                            height: parent.height
                            color: "#21be2b"
                            radius: 2
                        }
                    }

                    handle: Rectangle {
                        x: intensitySlider.leftPadding + intensitySlider.visualPosition * (intensitySlider.availableWidth - width)
                        y: intensitySlider.topPadding + intensitySlider.availableHeight / 2 - height / 2
                        implicitWidth: 26
                        implicitHeight: 26
                        radius: 13
                        color: intensitySlider.pressed ? "#f0f0f0" : "#f6f6f6"
                        border.color: "#bdbebf"
                    }
                }
            }

            // Separator
            Rectangle {
                color: "#444444"
                height: 1
                Layout.fillWidth: true
            }

            // Gear Control (enforce one selected; clicking selected button keeps it selected)
            RowLayout {
                Layout.fillWidth: true
                spacing: 100

                Label {
                    text: "Gear Control "
                    font.pixelSize: 24
                    font.family: "Segoe UI"
                    font.bold: true
                    color: "#70BCC9"
                    Layout.preferredWidth: 160
                    verticalAlignment: Label.AlignVCenter
                }

                RowLayout {
                    id: gearButtons
                    Layout.fillWidth: true
                    spacing: buttonSpacing

                    property var buttons: []

                    function deselectOthers(selected) {
                        for (let i = 0; i < buttons.length; i++) {
                            if (buttons[i] !== selected) {
                                buttons[i].checked = false
                            }
                            else {
                                controlPageAsync.qml_setApi_gear(i)
                            }
                        }
                    }

                    function selectGear(mode) {
                        // console.log ("selectGear : ", mode)
                        // console.log ("buttons.length : ", buttons.length)
                        for (let i = 0; i < buttons.length; i++) {
                            if (i === mode) {
                                buttons[i].checked = true
                            }
                            else {
                                buttons[i].checked = false
                            }
                        }
                    }

                    ToggleButton {
                        id: gearP
                        text: "P"
                        Layout.preferredWidth: 130
                        checked: true // initial selected

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (!gearP.checked) {
                                    gearP.checked = true
                                    gearButtons.deselectOthers(gearP)
                                }
                            }
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                        }
                        Component.onCompleted: gearButtons.buttons.push(gearP)
                    }
                    ToggleButton {
                        id: gearR
                        text: "R"
                        Layout.preferredWidth: 130

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (!gearR.checked) {
                                    gearR.checked = true
                                    gearButtons.deselectOthers(gearR)
                                }
                            }
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                        }
                        Component.onCompleted: gearButtons.buttons.push(gearR)
                    }
                    ToggleButton {
                        id: gearN
                        text: "N"
                        Layout.preferredWidth: 130

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (!gearN.checked) {
                                    gearN.checked = true
                                    gearButtons.deselectOthers(gearN)
                                }
                            }
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                        }
                        Component.onCompleted: gearButtons.buttons.push(gearN)
                    }
                    ToggleButton {
                        id: gearD
                        text: "D"
                        Layout.preferredWidth: 130

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (!gearD.checked) {
                                    gearD.checked = true
                                    gearButtons.deselectOthers(gearD)
                                }
                            }
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                        }
                        Component.onCompleted: gearButtons.buttons.push(gearD)
                    }
                }
            }

            // Separator
            Rectangle {
                color: "#444444"
                height: 1
                Layout.fillWidth: true
            }

            // Door Control
            RowLayout {
                Layout.fillWidth: true
                spacing: 100

                Label {
                    text: "Door Control "
                    font.pixelSize: 24
                    font.family: "Segoe UI"
                    font.bold: true
                    color: "#70BCC9"
                    Layout.preferredWidth: 160
                    verticalAlignment: Label.AlignVCenter
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: buttonSpacing

                    ToggleButton { 
                        id: doorLeftBtn; text: "Driver Left"; Layout.preferredWidth: 130 
                        onToggledChanged: {
                            console.log("doorLeftBtn checked changed: ", checked)
                            controlPageAsync.qml_setApi_door_driverSide_isOpen(checked)
                        }
                    }
                    ToggleButton { 
                        id: doorRightBtn; text: "Driver Right"; Layout.preferredWidth: 130 
                        onToggledChanged: {
                            console.log("doorRightBtn checked changed: ", checked)
                            controlPageAsync.qml_setApi_door_passengerSide_isOpen(checked)
                        }
                    }
                    ToggleButton { 
                        id: trunkBtn; text: "Trunk"; Layout.preferredWidth: 130 
                        onToggledChanged: {
                            console.log("Trunk checked changed: ", checked)
                            controlPageAsync.qml_setApi_trunk_rear_isOpen(checked)
                        }
                    }
                }
            }

            // Separator
            Rectangle {
                color: "#444444"
                height: 1
                Layout.fillWidth: true
            }

            // Fan Speed Left
            RowLayout {
                Layout.fillWidth: true
                spacing: 100

                Label {
                    text: "Fan Speed Left "
                    font.pixelSize: 24
                    font.family: "Segoe UI"
                    font.bold: true
                    color: "#70BCC9"
                    Layout.preferredWidth: 160
                    verticalAlignment: Label.AlignVCenter
                }

                ModeControl {
                    id: fanSpeedLeft
                    maxMode: 10
                    Layout.fillWidth: true
                    onModeChangedOnPressedChanged: {
                        console.log("fanSpeedLeft mode changed: ", mode)
                        controlPageAsync.qml_setApi_hvac_driverSide_FanSpeed(mode)
                    }
                }
            }

            // Separator
            Rectangle {
                color: "#444444"
                height: 1
                Layout.fillWidth: true
            }

            // Fan Speed Right
            RowLayout {
                Layout.fillWidth: true
                spacing: 100

                Label {
                    text: "Fan Speed Right "
                    font.pixelSize: 24
                    font.family: "Segoe UI"
                    font.bold: true
                    color: "#70BCC9"
                    Layout.preferredWidth: 160
                    verticalAlignment: Label.AlignVCenter
                }

                ModeControl {
                    id: fanSpeedRight
                    maxMode: 10
                    Layout.fillWidth: true
                    onModeChangedOnPressedChanged: {
                        console.log("fanSpeedRight mode changed: ", mode)
                        controlPageAsync.qml_setApi_hvac_passengerSide_FanSpeed(mode)
                    }
                }
            }
        }
    }
}
