import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import NotificationManager 1.0

Rectangle {
    id: settings_page
    width: Screen.width
    height: Screen.height
    color: "#0F0F0F"

    Component.onCompleted: {
        headerAnimation.start()
        menuAnimation.start()
    }

    // Simplified static background - removed all dynamic animations
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: "#0A0A0A" }
            GradientStop { position: 0.3; color: "#0F0F0F" }
            GradientStop { position: 0.7; color: "#0F0F0F" }
            GradientStop { position: 1.0; color: "#1A1A1A" }
        }
    }

    // Static grid pattern - no animations
    Canvas {
        id: staticGridPattern
        anchors.fill: parent
        opacity: 0.05
        
        Component.onCompleted: requestPaint()
        
        onPaint: {
            var ctx = getContext("2d")
            ctx.strokeStyle = "#00D4AA"
            ctx.lineWidth = 0.5
            
            var spacing = 80
            
            // Vertical lines
            for (var x = 0; x < width; x += spacing) {
                ctx.beginPath()
                ctx.moveTo(x, 0)
                ctx.lineTo(x, height)
                ctx.stroke()
            }
            
            // Horizontal lines
            for (var y = 0; y < height; y += spacing) {
                ctx.beginPath()
                ctx.moveTo(0, y)
                ctx.lineTo(width, y)
                ctx.stroke()
            }
        }
    }

    // Reduced corner particles - only show when hovered/active
    Item {
        id: cornerParticles
        anchors.top: parent.top
        anchors.right: parent.right
        width: parent.width * 0.3
        height: parent.height * 0.4
        opacity: 0.1
        
        // Reduced from 25 to 8 particles
        Repeater {
            model: 8
            Rectangle {
                width: 4 + Math.random() * 6
                height: width
                radius: width / 2
                color: "#00D4AA"
                opacity: 0.2 + Math.random() * 0.2
                x: Math.random() * parent.width
                y: Math.random() * parent.height
                
                // Only animate when settings page becomes active
                property bool shouldAnimate: settings_page.visible
                
                // Slower, less frequent animations
                SequentialAnimation on y {
                    running: parent.parent.shouldAnimate && index < 4 // Only animate half
                    loops: Animation.Infinite
                    NumberAnimation {
                        to: parent.y - 50
                        duration: 8000 // Much slower
                        easing.type: Easing.InOutQuad
                    }
                    NumberAnimation {
                        to: parent.y + 50
                        duration: 8000
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        }
    }

    // Header area - simplified
    Rectangle {
        id: headerBackground
        x: 0
        y: 0
        width: parent.width
        height: 100
        color: "#1A1A1A"
        
        // Static accent line - no animation
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 20
            width: 200
            height: 3
            color: "#00D4AA"
            radius: 1.5
            x: 32
        }
        
        // Static border
        Rectangle {
            anchors.bottom: parent.bottom
            width: settings_page.width
            height: 1
            color: "#2A2A2A"
        }
    }

    // Simplified dreamKIT text
    Item {
        id: dreamKitContainer
        x: 32
        y: 20
        width: 300
        height: 60

        // Static background glow
        Rectangle {
            anchors.centerIn: parent
            width: parent.width + 40
            height: parent.height + 20
            radius: 15
            color: "#00D4AA"
            opacity: 0.08 // Static opacity
        }

        Text {
            id: settings_page_header_text
            text: "dreamKIT v1.11"
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            font.bold: true
            font.pixelSize: 36
            font.weight: Font.Bold
            color: "#00D4AA"
            font.family: "Segoe UI"
            font.letterSpacing: 2
            opacity: 0

            // Static shadow - no animation
            Text {
                anchors.fill: parent
                text: parent.text
                font: parent.font
                color: "#004D3D"
                opacity: 0.3
                x: 2
                y: 2
                z: -1
            }

            // Simple fade-in only
            NumberAnimation {
                id: headerAnimation
                target: settings_page_header_text
                property: "opacity"
                from: 0
                to: 1
                duration: 800
                easing.type: Easing.OutCubic
            }
        }
    }

    ColumnLayout {
        spacing: 0
        y: 100
        width: parent.width
        height: parent.height - 100

        RowLayout {
            id: mainLayout
            Layout.fillWidth: true
            height: Screen.height - 100
            spacing: 0

            Rectangle {
                id: menuPanel
                Layout.preferredWidth: settings_page.width * 0.2
                Layout.fillHeight: true
                color: "#1A1A1A"
                
                Rectangle {
                    anchors.right: parent.right
                    width: 1
                    height: parent.height
                    color: "#2A2A2A"
                }

                // Simple slide-in
                x: -width
                NumberAnimation {
                    id: menuAnimation
                    target: menuPanel
                    property: "x"
                    from: -menuPanel.width
                    to: 0
                    duration: 400
                    easing.type: Easing.OutCubic
                }

                ListView {
                    id: settingsList
                    anchors.fill: parent
                    anchors.margins: 8
                    model: settingsModel
                    spacing: 6
                    
                    delegate: Item {
                        width: settingsList.width
                        height: 64

                        Rectangle {
                            id: backgroundRect
                            anchors.fill: parent
                            radius: 12
                            color: settingsList.currentIndex === index ? "#00D4AA15" : "transparent"
                            border.color: settingsList.currentIndex === index ? "#00D4AA40" : "transparent"
                            border.width: 1

                            // Smooth transitions only
                            Behavior on color {
                                ColorAnimation { duration: 200 }
                            }
                            
                            Behavior on border.color {
                                ColorAnimation { duration: 200 }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 20
                                anchors.rightMargin: 16
                                spacing: 16

                                // Simplified icon - no animations
                                Rectangle {
                                    width: 36
                                    height: 36
                                    radius: 8
                                    color: settingsList.currentIndex === index ? "#00D4AA15" : "#2A2A2A"
                                    border.color: settingsList.currentIndex === index ? "#00D4AA" : "#404040"
                                    border.width: 1
                                    
                                    Behavior on color {
                                        ColorAnimation { duration: 200 }
                                    }
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: {
                                            switch(index) {
                                                case 0: return "●"
                                                case 1: return "◐"
                                                case 2: return "◆"
                                                case 3: return "▲"
                                                case 4: return "■"
                                                default: return "●"
                                            }
                                        }
                                        font.pixelSize: 18
                                        font.family: "Arial"
                                        color: settingsList.currentIndex === index ? "#00D4AA" : "#B0B0B0"
                                        
                                        Behavior on color {
                                            ColorAnimation { duration: 200 }
                                        }
                                    }
                                }

                                Text {
                                    text: title
                                    font.pixelSize: 16
                                    font.family: "Segoe UI"
                                    font.weight: settingsList.currentIndex === index ? Font.DemiBold : Font.Medium
                                    color: settingsList.currentIndex === index ? "#FFFFFF" : "#C0C0C0"
                                    Layout.fillWidth: true
                                    
                                    Behavior on color {
                                        ColorAnimation { duration: 200 }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            
                            onEntered: {
                                if (settingsList.currentIndex !== index) {
                                    backgroundRect.color = "#00D4AA25"
                                }
                            }
                            
                            onExited: {
                                if (settingsList.currentIndex !== index) {
                                    backgroundRect.color = "transparent"
                                }
                            }
                            
                            onClicked: {
                                if (settingsList.currentIndex !== index) {
                                    settingsList.currentIndex = index
                                    stackLayout.currentIndex = index
                                }
                            }
                        }
                    }
                    
                    highlight: Rectangle { color: "transparent" }
                }
            }

            Rectangle {
                id: contentPanel
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#0F0F0F"

                StackLayout {
                    id: stackLayout
                    anchors.fill: parent
                    currentIndex: settingsList.currentIndex

                    Loader { source: "../marketplace/marketplace.qml" }
                    Loader { source: "../controls/controls.qml" }
                    Loader { source: "../digitalauto/digitalauto.qml" }
                    Loader { source: "../installedvapps/installedvapps.qml" }
                    Loader { source: "../installedservices/installedservices.qml" }
                }
            }
        }
    }

    ListModel {
        id: settingsModel
        ListElement { title: "Market Place" }
        ListElement { title: "Control" }
        ListElement { title: "App Test Deployment" }
        ListElement { title: "Vehicle App" }
        ListElement { title: "Vehicle Service" }
    }
}