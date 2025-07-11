import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "."  // Import local ToggleButton.qml and ModeControl.qml
import ControlsAsync 1.0

Rectangle {
    id: rectangle
    anchors.fill: parent
    color: "#0F0F0F"  // Deep dark background
    
    property int buttonSpacing: 16

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
        onUpdateWidget_hvac_driverSide_FanSpeed: (speed) => {
            // Convert 0-10 range to 0-100 percentage
            driverFanSlider.value = speed * 10
        }
        onUpdateWidget_hvac_passengerSide_FanSpeed: (speed) => {
            // Convert 0-10 range to 0-100 percentage
            passengerFanSlider.value = speed * 10
        }
        onUpdateWidget_seat_driverSide_position: (position) => {
            seatLevels.currentLevel = position
        }
    }

    Component.onCompleted: {
        controlPageAsync.init()
    }

    // Main container
    Item {
        anchors.fill: parent
        anchors.margins: 24

        // Header
        Text {
            id: headerText
            text: "Vehicle Control Center"
            font.pixelSize: 28
            font.family: "Segoe UI"
            font.weight: Font.Bold
            color: "#00D4AA"
            anchors.horizontalCenter: parent.horizontalCenter
            y: 20
        }

        // Main controls container
        Item {
            id: controlsContainer
            width: Math.min(parent.width, 1000)
            height: 600
            y: 80
            anchors.horizontalCenter: parent.horizontalCenter

            // Car illustration (centered)
            Item {
                id: carIllustration
                width: 240
                height: 480
                anchors.centerIn: parent

                // Background car image
                Image {
                    id: carImage
                    source: "qrc:/untitled2/resource/icons/car.png"
                    width: 200
                    height: 400
                    anchors.centerIn: parent
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                // Enhanced headlight overlays with glow effects
                Rectangle {
                    id: leftHeadlight
                    width: 20
                    height: 14
                    radius: 7
                    color: lowbeamBtn.checked || highbeamBtn.checked ? "#FFD700" : "transparent"
                    border.color: lowbeamBtn.checked || highbeamBtn.checked ? "#FFD700" : "#404040"
                    border.width: 1
                    x: 58  // Left side of car front
                    y: 38  // Near front of car
                    
                    Behavior on color { ColorAnimation { duration: 300 } }
                    
                    // Inner glow for active state
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - 4
                        height: parent.height - 4
                        radius: parent.radius - 2
                        color: lowbeamBtn.checked || highbeamBtn.checked ? "#FFFFFF" : "transparent"
                        opacity: 0.7
                        
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }
                    
                    // High beam outer glow
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width + 12
                        height: parent.height + 12
                        radius: parent.radius + 6
                        color: "transparent"
                        border.color: "#FFD700"
                        border.width: highbeamBtn.checked ? 3 : 0
                        opacity: 0.4
                        
                        Behavior on border.width { NumberAnimation { duration: 300 } }
                        
                        // Pulsing animation for high beam
                        SequentialAnimation on opacity {
                            running: highbeamBtn.checked
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.2; duration: 800 }
                            NumberAnimation { to: 0.6; duration: 800 }
                        }
                    }
                }

                Rectangle {
                    id: rightHeadlight
                    width: 20
                    height: 14
                    radius: 7
                    color: lowbeamBtn.checked || highbeamBtn.checked ? "#FFD700" : "transparent"
                    border.color: lowbeamBtn.checked || highbeamBtn.checked ? "#FFD700" : "#404040"
                    border.width: 1
                    x: 162  // Right side of car front
                    y: 38   // Near front of car
                    
                    Behavior on color { ColorAnimation { duration: 300 } }
                    
                    // Inner glow for active state
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - 4
                        height: parent.height - 4
                        radius: parent.radius - 2
                        color: lowbeamBtn.checked || highbeamBtn.checked ? "#FFFFFF" : "transparent"
                        opacity: 0.7
                        
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }
                    
                    // High beam outer glow
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width + 12
                        height: parent.height + 12
                        radius: parent.radius + 6
                        color: "transparent"
                        border.color: "#FFD700"
                        border.width: highbeamBtn.checked ? 3 : 0
                        opacity: 0.4
                        
                        Behavior on border.width { NumberAnimation { duration: 300 } }
                        
                        // Pulsing animation for high beam
                        SequentialAnimation on opacity {
                            running: highbeamBtn.checked
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.2; duration: 800 }
                            NumberAnimation { to: 0.6; duration: 800 }
                        }
                    }
                }

                // Enhanced hazard lights with modern styling
                Rectangle {
                    id: leftHazard
                    width: 16
                    height: 12
                    radius: 6
                    color: hazardBtn.checked ? "#FF4444" : "transparent"
                    border.color: hazardBtn.checked ? "#FF4444" : "#404040"
                    border.width: 1
                    x: 38   // Left side
                    y: 118  // Mid-car position
                    
                    Behavior on color { ColorAnimation { duration: 200 } }
                    
                    // Inner bright core
                    Rectangle {
                        anchors.centerIn: parent
                        width: 8
                        height: 6
                        radius: 3
                        color: hazardBtn.checked ? "#FFFFFF" : "transparent"
                        opacity: 0.9
                    }
                    
                    // Outer glow ring
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width + 8
                        height: parent.height + 8
                        radius: parent.radius + 4
                        color: "transparent"
                        border.color: "#FF4444"
                        border.width: hazardBtn.checked ? 2 : 0
                        opacity: 0.5
                        
                        Behavior on border.width { NumberAnimation { duration: 200 } }
                    }
                    
                    SequentialAnimation on opacity {
                        running: hazardBtn.checked
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 600 }
                        NumberAnimation { to: 1.0; duration: 600 }
                    }
                }

                Rectangle {
                    id: rightHazard
                    width: 16
                    height: 12
                    radius: 6
                    color: hazardBtn.checked ? "#FF4444" : "transparent"
                    border.color: hazardBtn.checked ? "#FF4444" : "#404040"
                    border.width: 1
                    x: 186  // Right side
                    y: 118  // Mid-car position
                    
                    Behavior on color { ColorAnimation { duration: 200 } }
                    
                    // Inner bright core
                    Rectangle {
                        anchors.centerIn: parent
                        width: 8
                        height: 6
                        radius: 3
                        color: hazardBtn.checked ? "#FFFFFF" : "transparent"
                        opacity: 0.9
                    }
                    
                    // Outer glow ring
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width + 8
                        height: parent.height + 8
                        radius: parent.radius + 4
                        color: "transparent"
                        border.color: "#FF4444"
                        border.width: hazardBtn.checked ? 2 : 0
                        opacity: 0.5
                        
                        Behavior on border.width { NumberAnimation { duration: 200 } }
                    }
                    
                    SequentialAnimation on opacity {
                        running: hazardBtn.checked
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 600 }
                        NumberAnimation { to: 1.0; duration: 600 }
                    }
                }

                // Enhanced rear hazard lights
                Rectangle {
                    width: 14
                    height: 10
                    radius: 5
                    color: hazardBtn.checked ? "#FF4444" : "transparent"
                    border.color: hazardBtn.checked ? "#FF4444" : "#404040"
                    border.width: 1
                    x: 63   // Left rear
                    y: 348  // Back of car
                    
                    Behavior on color { ColorAnimation { duration: 200 } }
                    
                    // Inner core
                    Rectangle {
                        anchors.centerIn: parent
                        width: 6
                        height: 4
                        radius: 2
                        color: hazardBtn.checked ? "#FFFFFF" : "transparent"
                        opacity: 0.8
                    }
                    
                    SequentialAnimation on opacity {
                        running: hazardBtn.checked
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.2; duration: 600 }
                        NumberAnimation { to: 1.0; duration: 600 }
                    }
                }

                Rectangle {
                    width: 14
                    height: 10
                    radius: 5
                    color: hazardBtn.checked ? "#FF4444" : "transparent"
                    border.color: hazardBtn.checked ? "#FF4444" : "#404040"
                    border.width: 1
                    x: 163  // Right rear
                    y: 348  // Back of car
                    
                    Behavior on color { ColorAnimation { duration: 200 } }
                    
                    // Inner core
                    Rectangle {
                        anchors.centerIn: parent
                        width: 6
                        height: 4
                        radius: 2
                        color: hazardBtn.checked ? "#FFFFFF" : "transparent"
                        opacity: 0.8
                    }
                    
                    SequentialAnimation on opacity {
                        running: hazardBtn.checked
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.2; duration: 600 }
                        NumberAnimation { to: 1.0; duration: 600 }
                    }
                }

                // Elegant seat activity indicator
                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: seatLevels.currentLevel > 0 ? "#00D4AA" : "transparent"
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 185  // Front seat area
                    opacity: seatLevels.currentLevel > 0 ? 1.0 : 0.0
                    
                    Behavior on opacity { NumberAnimation { duration: 300 } }
                    Behavior on color { ColorAnimation { duration: 300 } }
                    
                    // Subtle pulsing when active
                    SequentialAnimation on scale {
                        running: seatLevels.currentLevel > 0
                        loops: Animation.Infinite
                        NumberAnimation { to: 1.3; duration: 1200 }
                        NumberAnimation { to: 1.0; duration: 1200 }
                    }
                }

                // Ambient lighting strip (elegant accent)
                Rectangle {
                    width: 120
                    height: 3
                    radius: 1.5
                    color: (lowbeamBtn.checked || highbeamBtn.checked || hazardBtn.checked || seatLevels.currentLevel > 0) ? "#00D4AA" : "transparent"
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 320  // Lower part of car
                    opacity: 0.6
                    
                    Behavior on color { ColorAnimation { duration: 500 } }
                    
                    // Gradient effect simulation
                    Rectangle {
                        width: parent.width * 0.6
                        height: parent.height
                        radius: parent.radius
                        anchors.centerIn: parent
                        color: "#FFFFFF"
                        opacity: 0.3
                    }
                }
            }

            // Left control panel - Lighting
            Rectangle {
                id: leftPanel
                width: 240
                height: 450
                x: 0
                y: 75
                color: "#1A1A1A"
                radius: 16
                border.color: "#2A2A2A"
                border.width: 1

                Column {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 50

                    Text {
                        text: "Lighting Controls"
                        font.pixelSize: 20
                        font.family: "Segoe UI"
                        font.weight: Font.Medium
                        color: "#00D4AA"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Column {
                        width: parent.width
                        spacing: 50

                        // Custom ToggleButton for Low Beam
                        Rectangle {
                            id: lowbeamBtn
                            property bool checked: false
                            width: parent.width
                            height: 70
                            radius: 10
                            color: checked ? "#00D4AA" : "#2A2A2A"
                            border.color: checked ? "#00D4AA" : "#404040"
                            border.width: 2
                            
                            Row {
                                anchors.centerIn: parent
                                spacing: 10
                                
                                Rectangle {
                                    width: 12
                                    height: 8
                                    radius: 4
                                    color: lowbeamBtn.checked ? "#FFD700" : "#404040"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                
                                Text {
                                    text: "Low Beam"
                                    color: lowbeamBtn.checked ? "#000000" : "#FFFFFF"
                                    font.pixelSize: 20
                                    font.family: "Segoe UI"
                                    font.weight: Font.Medium
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    lowbeamBtn.checked = !lowbeamBtn.checked
                                    controlPageAsync.qml_setApi_lightCtr_LowBeam(lowbeamBtn.checked)
                                }
                            }
                        }

                        // Custom ToggleButton for High Beam
                        Rectangle {
                            id: highbeamBtn
                            property bool checked: false
                            width: parent.width
                            height: 70
                            radius: 10
                            color: checked ? "#00D4AA" : "#2A2A2A"
                            border.color: checked ? "#00D4AA" : "#404040"
                            border.width: 2
                            
                            Row {
                                anchors.centerIn: parent
                                spacing: 10
                                
                                Rectangle {
                                    width: 12
                                    height: 8
                                    radius: 4
                                    color: highbeamBtn.checked ? "#FFD700" : "#404040"
                                    border.color: highbeamBtn.checked ? "#FFD700" : "transparent"
                                    border.width: highbeamBtn.checked ? 2 : 0
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                
                                Text {
                                    text: "High Beam"
                                    color: highbeamBtn.checked ? "#000000" : "#FFFFFF"
                                    font.pixelSize: 20
                                    font.family: "Segoe UI"
                                    font.weight: Font.Medium
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    highbeamBtn.checked = !highbeamBtn.checked
                                    controlPageAsync.qml_setApi_lightCtr_HighBeam(highbeamBtn.checked)
                                }
                            }
                        }

                        // Custom ToggleButton for Hazard Lights
                        Rectangle {
                            id: hazardBtn
                            property bool checked: false
                            width: parent.width
                            height: 70
                            radius: 10
                            color: checked ? "#FF4444" : "#2A2A2A"
                            border.color: checked ? "#FF4444" : "#404040"
                            border.width: 2
                            
                            Row {
                                anchors.centerIn: parent
                                spacing: 10
                                
                                Rectangle {
                                    width: 12
                                    height: 8
                                    radius: 4
                                    color: hazardBtn.checked ? "white" : "#404040"
                                    anchors.verticalCenter: parent.verticalCenter
                                    
                                    SequentialAnimation on opacity {
                                        running: hazardBtn.checked
                                        loops: Animation.Infinite
                                        NumberAnimation { to: 0.3; duration: 600 }
                                        NumberAnimation { to: 1.0; duration: 600 }
                                    }
                                }
                                
                                Text {
                                    text: "Hazard Lights"
                                    color: hazardBtn.checked ? "black" : "#FFFFFF"
                                    font.pixelSize: 20
                                    font.family: "Segoe UI"
                                    font.weight: Font.Medium
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    hazardBtn.checked = !hazardBtn.checked
                                    controlPageAsync.qml_setApi_lightCtr_Hazard(hazardBtn.checked)
                                }
                            }
                        }
                    }
                }
            }

            // Right control panel - Climate & Seat
            Rectangle {
                id: rightPanel
                width: 240
                height: 450
                x: parent.width - width
                y: 75
                color: "#1A1A1A"
                radius: 16
                border.color: "#2A2A2A"
                border.width: 1

                Column {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 20

                    // Fan Control Section
                    Column {
                        width: parent.width
                        spacing: 15

                        Text {
                            text: "Fan Controls"
                            font.pixelSize: 20
                            font.family: "Segoe UI"
                            font.weight: Font.Medium
                            color: "#00D4AA"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }


                        // Driver Fan Control
                        Column {
                            width: parent.width
                            spacing: 10


                            Row {
                                width: parent.width
                                height: 20

                                Column {
                                    width: parent.width / 2
                                    Text {
                                        // anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.right: parent.right
                                        text: "Driver:"
                                        font.pixelSize: 16
                                        color: "#B0B0B0"
                                        font.family: "Segoe UI"
                                    }
                                }

                                Column {
                                    width: parent.width / 2
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: driverFanSlider.value + "%"
                                        font.pixelSize: 16
                                        color: "#B0B0B0"
                                        font.family: "Segoe UI"
                                    }
                                }
                            }



                            Slider {
                                id: driverFanSlider
                                width: parent.width
                                from: 0
                                stepSize: 10
                                to: 100
                                value: 0
                                property int lastBackendValue: -1

                                    
                                onPressedChanged: {
                                    if(!pressed){
                                        let backendValue = Math.round(value / 10)
                                        if (backendValue !== lastBackendValue){
                                            lastBackendValue = backendValue
                                            controlPageAsync.qml_setApi_hvac_driverSide_FanSpeed(lastBackendValue)
                                        }
                                    }
                                }

            

                                background: Rectangle {
                                    x: driverFanSlider.leftPadding
                                    y: driverFanSlider.topPadding + driverFanSlider.availableHeight / 2 - height / 2
                                    implicitWidth: 200
                                    implicitHeight: 8
                                    width: driverFanSlider.availableWidth
                                    height: implicitHeight
                                    radius: 4
                                    color: "#2A2A2A"

                                    Rectangle {
                                        width: driverFanSlider.visualPosition * parent.width
                                        height: parent.height
                                        color: "#00D4AA"
                                        radius: 4
                                    }
                                }

                                handle: Rectangle {
                                    x: driverFanSlider.leftPadding + driverFanSlider.visualPosition * (driverFanSlider.availableWidth - width)
                                    y: driverFanSlider.topPadding + driverFanSlider.availableHeight / 2 - height / 2
                                    implicitWidth: 24
                                    implicitHeight: 24
                                    radius: 12
                                    color: driverFanSlider.pressed ? "#FFFFFF" : "#F0F0F0"
                                    border.color: "#00D4AA"
                                    border.width: 2
                                }
                            }
                        }

                        // Passenger Fan Control
                        Column {
                            width: parent.width
                            spacing: 10

                            

                            Row {
                                width: parent.width
                                height: 20

                                Column {
                                    width: parent.width / 2
                                    Text {
                                        // anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.right: parent.right
                                        text: "Passenger:"
                                        font.pixelSize: 16
                                        color: "#B0B0B0"
                                        font.family: "Segoe UI"
                                    }
                                }

                                Column {
                                    width: parent.width / 2
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: passengerFanSlider.value + "%"
                                        font.pixelSize: 16
                                        color: "#B0B0B0"
                                        font.family: "Segoe UI"
                                    }
                                }
                            }


                            Slider {
                                id: passengerFanSlider
                                width: parent.width
                                from: 0
                                stepSize: 10
                                to: 100
                                value: 0
                                property  int lastSent :  -1
                                onPressedChanged: {
                                    if(!pressed){
                                        let backendValue = Math.round(value / 10)
                                        if (backendValue !== lastSent){
                                            lastSent = backendValue
                                            controlPageAsync.qml_setApi_hvac_passengerSide_FanSpeed(lastSent)
                                        }
                                    }
                                }


                                background: Rectangle {
                                    x: passengerFanSlider.leftPadding
                                    y: passengerFanSlider.topPadding + passengerFanSlider.availableHeight / 2 - height / 2
                                    implicitWidth: 200
                                    implicitHeight: 8
                                    width: passengerFanSlider.availableWidth
                                    height: implicitHeight
                                    radius: 4
                                    color: "#2A2A2A"

                                    Rectangle {
                                        width: passengerFanSlider.visualPosition * parent.width
                                        height: parent.height
                                        color: "#00D4AA"
                                        radius: 4
                                    }
                                }

                                handle: Rectangle {
                                    x: passengerFanSlider.leftPadding + passengerFanSlider.visualPosition * (passengerFanSlider.availableWidth - width)
                                    y: passengerFanSlider.topPadding + passengerFanSlider.availableHeight / 2 - height / 2
                                    implicitWidth: 24
                                    implicitHeight: 24
                                    radius: 12
                                    color: passengerFanSlider.pressed ? "#FFFFFF" : "#F0F0F0"
                                    border.color: "#00D4AA"
                                    border.width: 2
                                }
                            }
                        }
                    }

                    // Divider
                    Rectangle { 
                        width: parent.width
                        height: 1
                        color: "#2A2A2A"
                    }

                    // Seat Control Section
                    Column {
                        width: parent.width
                        spacing: 15

                        Text {
                            text: "Seat Position"
                            font.pixelSize: 20
                            font.family: "Segoe UI"
                            font.weight: Font.Medium
                            color: "#00D4AA"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Column {
                            width: parent.width
                            spacing: 15

                            // Seat image with level indicator
                            Item {
                                width: 120
                                height: 120
                                anchors.horizontalCenter: parent.horizontalCenter

                                // Seat image
                                Image {
                                    id: seatControlImage
                                    source: "qrc:/untitled2/resource/icons/seat.png"
                                    width: 110
                                    height: 110
                                    anchors.centerIn: parent
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    opacity: seatLevels.currentLevel > 0 ? 1.0 : 0.5
                                    
                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                }

                                // Position level indicator overlay
                                Rectangle {
                                    width: 30
                                    height: 30
                                    radius: 15
                                    color: seatLevels.currentLevel > 0 ? "#00D4AA" : "#404040"
                                    border.color: "#FFFFFF"
                                    border.width: 2
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        // seatLevels.currentLevel > 0 && seatLevels.currentLevel < "4" ? seatLevels.currentLevel : "0"
                                        text: {
                                            if (seatLevels.currentLevel > 3){
                                                "3"
                                            }
                                            else if (seatLevels.currentLevel > 0 && seatLevels.currentLevel < "4"){
                                                seatLevels.currentLevel
                                            }
                                            else{
                                                "0"
                                            }
                                        }
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: "black"
                                    }
                                }
                            }

                            Row {
                                id: seatLevels
                                spacing: 12
                                anchors.horizontalCenter: parent.horizontalCenter
                                property int currentLevel: 0

                                // Level 1 Button
                                Rectangle {
                                    id: seatLevel1
                                    property bool checked: seatLevels.currentLevel === 1
                                    width: 60
                                    height: 60
                                    radius: 10
                                    color: checked ? "#00D4AA" : "#2A2A2A"
                                    border.color: checked ? "#00D4AA" : "#404040"
                                    border.width: 2
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "1"
                                        color: seatLevel1.checked ? "#000000" : "#FFFFFF"
                                        font.pixelSize: 20
                                        font.bold: true
                                    }
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            if (seatLevels.currentLevel !== 1){
                                                seatLevels.currentLevel = 1;
                                                controlPageAsync.qml_setApi_seat_driverSide_position(1);
                                            }
                                            else{
                                                seatLevels.currentLevel = 0 ;
                                                controlPageAsync.qml_setApi_seat_driverSide_position(0)
                                            }
                                        }
                                    }

                                }

                                // Level 2 Button
                                Rectangle {
                                    id: seatLevel2
                                    property bool checked: seatLevels.currentLevel === 2
                                    width: 60
                                    height: 60
                                    radius: 10
                                    color: checked ? "#00D4AA" : "#2A2A2A"
                                    border.color: checked ? "#00D4AA" : "#404040"
                                    border.width: 2
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "2"
                                        color: seatLevel2.checked ? "#000000" : "#FFFFFF"
                                        font.pixelSize: 20
                                        font.bold: true
                                    }
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            if (seatLevels.currentLevel !== 2) {
                                                seatLevels.currentLevel = 2
                                                controlPageAsync.qml_setApi_seat_driverSide_position(2)
                                            }
                                            else {
                                                seatLevels.currentLevel = 0
                                                controlPageAsync.qml_setApi_seat_driverSide_position(0)
                                            }
                                        }
                                    }
                                }

                                // Level 3 Button
                                Rectangle {
                                    id: seatLevel3
                                    property bool checked: seatLevels.currentLevel >= 3
                                    width: 60
                                    height: 60
                                    radius: 10
                                    color: checked ? "#00D4AA" : "#2A2A2A"
                                    border.color: checked ? "#00D4AA" : "#404040"
                                    border.width: 2
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "3"
                                        color: seatLevel3.checked ? "#000000" : "#FFFFFF"
                                        font.pixelSize: 20
                                        font.bold: true
                                    }
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            if (seatLevels.currentLevel !== 3){
                                                seatLevels.currentLevel = 3
                                                controlPageAsync.qml_setApi_seat_driverSide_position(3)
                                            }
                                            else{
                                                seatLevels.currentLevel = 0
                                                controlPageAsync.qml_setApi_seat_driverSide_position(0)
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
    }
}
