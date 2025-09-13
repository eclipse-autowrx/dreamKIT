import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: mainWindow
    visible: true
    width: Screen.width
    height: Screen.height
    visibility: "FullScreen"
    flags: Qt.Window | Qt.FramelessWindowHint
    color: "#0F0F0F"

    // Simple fade-in - reduced duration and complexity
    opacity: 0
    
    Component.onCompleted: {
        // Delay to ensure everything is loaded
        fadeInTimer.start()
    }

    Timer {
        id: fadeInTimer
        interval: 100
        onTriggered: fadeInAnimation.start()
    }

    NumberAnimation {
        id: fadeInAnimation
        target: mainWindow
        property: "opacity"
        from: 0
        to: 1
        duration: 400  // Reduced from 800
        easing.type: Easing.OutCubic
    }

    // Static background - no animations
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0F0F0F" }
            GradientStop { position: 1.0; color: "#1A1A1A" }
        }
    }

    // REMOVED: Animated background pattern - this was causing continuous repaints
    // The 20 rectangles with infinite animations were a major CPU drain

    SwipeView {
        id: swipeView
        anchors.fill: parent
        interactive: false

        // Faster transitions
        Behavior on currentIndex {
            NumberAnimation {
                duration: 200  // Reduced from 400
                easing.type: Easing.OutCubic
            }
        }

        Loader {
            id: settingsLoader
            source: "settings.qml"
            
            // Simplified loading indicator
            Rectangle {
                anchors.centerIn: parent
                width: 60  // Smaller
                height: 60
                radius: 30
                color: "transparent"
                border.color: "#00D4AA"
                border.width: 2
                visible: settingsLoader.status === Loader.Loading

                // Simpler rotation - no need for complex animation
                RotationAnimation on rotation {
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: 1000  // Faster rotation
                }

                Text {
                    anchors.centerIn: parent
                    text: "Loading..."
                    font.family: "Segoe UI"
                    font.pixelSize: 10
                    color: "#00D4AA"
                }
            }
            
            // Handle loading errors
            onStatusChanged: {
                if (status === Loader.Error) {
                    console.warn("Failed to load settings.qml")
                }
            }
        }
    }

    // Optimized Notification Overlay
    Loader {
        id: notificationLoader
        anchors.fill: parent
        source: "qrc:/untitled2/platform/notifications/notificationoverlay.qml"
        z: 10000
        asynchronous: true  // Load asynchronously
        
        onLoaded: {
            if (item && globalNotificationManager) {
                // Configure the notification overlay
                item.notificationManagerInstance = globalNotificationManager
                item.position = "topRight"
                item.margin = 24
                item.notificationWidth = 380
                item.maxVisibleNotifications = 5
                item.compactMode = false
                
                console.log("NotificationOverlay configured successfully")
            } else {
                console.warn("NotificationOverlay configuration failed")
            }
        }
        
        onStatusChanged: {
            if (status === Loader.Error) {
                console.warn("NotificationLoader failed, trying alternative path")
                source = "qrc:/platform/notifications/notificationoverlay.qml"
            }
        }
    }

    // Simplified corner accents - static, no canvas repainting
    Rectangle {
        width: 50  // Smaller
        height: 2
        color: "#00D4AA"
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 20
        anchors.rightMargin: 20
    }

    Rectangle {
        width: 2
        height: 50
        color: "#00D4AA"
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 20
        anchors.rightMargin: 20
    }

    Rectangle {
        width: 50
        height: 2
        color: "#00D4AA"
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.bottomMargin: 20
        anchors.leftMargin: 20
    }

    Rectangle {
        width: 2
        height: 50
        color: "#00D4AA"
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.bottomMargin: 20
        anchors.leftMargin: 20
    }
    
    // Development test button - only visible in debug mode
    Rectangle {
        width: 120
        height: 40
        color: "#00D4AA20"
        border.color: "#00D4AA"
        border.width: 1
        radius: 8
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 20
        visible: Qt.application.arguments.indexOf("--debug") !== -1
        
        Text {
            anchors.centerIn: parent
            text: "Test Notifications"
            color: "#00D4AA"
            font.family: "Segoe UI"
            font.pixelSize: 12
        }
        
        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (notificationLoader.item) {
                    notificationLoader.item.testNotifications()
                }
            }
        }
    }
}