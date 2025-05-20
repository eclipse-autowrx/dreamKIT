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

    SwipeView {
        id: swipeView
        anchors.fill: parent

        Loader {
            source: "../controls/controls.qml"
        }
        Loader {
            source: "../digitalauto/digitalauto.qml"
        }
        Loader {
            source: "../installedvapps/installedvapps.qml"
        }      
        Loader {
            source: "../installedservices/installedservices.qml"
        }
        Loader {
            source: "../marketplace/marketplace.qml"
        }
    }
}
