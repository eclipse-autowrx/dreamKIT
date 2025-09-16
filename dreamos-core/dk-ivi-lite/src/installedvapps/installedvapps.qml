// Copyright (c) 2025 Eclipse Foundation.
// 
// This program and the accompanying materials are made available under the
// terms of the MIT License which is available at
// https://opensource.org/licenses/MIT.
// 
// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../resource/customwidgets"
import VappsAsync 1.0

Rectangle {
    id: installedvaps_page
    visible: true
    width: parent.width
    height: parent.height
    color: "#0F0F0F"

    property int numbeOfInstalledApps: 0
    property int numbeOfSearchedApps: 0
    property int installAppIndex: -1
    property bool isSearchTextInputEmpty: true
    property int removeAppIndex: -1
    property string activeAppName: ""
    property string deleteAppName: ""

    Component.onCompleted: {
        appListModel.clear()
        appAsync.initInstalledFromDB()
    }

    function findChildByObjectName(parent, objectName) {
        for (var i = 0; i < parent.children.length; i++) {
            if (parent.children[i].objectName === objectName) {
                return parent.children[i];
            } else if (parent.children[i].children.length > 0) {
                var found = findChildByObjectName(parent.children[i], objectName);
                if (found) return found;
            }
        }
        return null;
    }

    VappsAsync {
        id: appAsync

        onClearServicesListView: {
            appListModel.clear()
        }

        onAppendServicesInfoToServicesList: (name, author, rating, noofdownload, icon, isInstalled, appId, isSubscribed) => {
            if (name === "") {
                appListModel.append({name: "No Result.", author: "", rating: "", noofdownload: "", iconpath: "", is_installed: false, appId: "", isSubscribed: false})
            } else {
                appListModel.append({
                    name: name,
                    author: author,
                    rating: rating+"*",
                    noofdownload: noofdownload,
                    iconpath: icon,
                    is_installed: isInstalled,
                    appId: appId,
                    isSubscribed: isSubscribed
                })
            }
        }

        onAppendLastRowToServicesList: (noOfApps) => {
            numbeOfSearchedApps = noOfApps
            appListModel.append({name: "", author: "", rating: "", noofdownload: "", iconpath: ""})
            appListView.positionViewAtBeginning()
        }
                               
        onUpdateStartAppMsg: (appId, isStarted, msg) => {
            startSubscribePopup.message = msg
            var chkItem = appListView.itemAtIndex(appListView.currentIndex);
            var chkItemChildren = chkItem.children;
            for( var i = 0 ; i < chkItemChildren.length ; ++i) {
                if(chkItemChildren[i].objectName === appId) {
                    chkItemChildren[i].checked = isStarted
                }
            }
            appListView.currentIndex = -1
            startAppBusyIndicator.visible = false
            startAppBusyIndicator.running = false
        }

        onUpdateServicesRunningSts: (appId, isStarted, idx) => {
            if (appId !== "") {
                var chkItem = appListView.itemAtIndex(idx);
                var foundChild = findChildByObjectName(chkItem, appId);
                if (foundChild) {
                    foundChild.checked = isStarted;
                }
            }
        }
    }

    // Enhanced popup dialogs with better sizing and typography
    Dialog {
        id: startSubscribePopup
        property string message: ""
        width: Math.min(480, parent.width * 0.9)
        height: Math.min(320, parent.height * 0.6)
        anchors.centerIn: parent
        modal: true
        closePolicy: Popup.NoAutoClose

        onAccepted: {
            startSubscribePopup.close()
        }

        background: Rectangle {
            color: "#1A1A1A"
            radius: 20
            border.color: "#00D4AA40"
            border.width: 2
            
            // Subtle shadow effect
            Rectangle {
                anchors.fill: parent
                anchors.margins: -4
                color: "transparent"
                border.color: "#00000040"
                border.width: 1
                radius: 24
                z: -1
            }
        }

        contentItem: Column {
            anchors.fill: parent
            anchors.margins: 40
            spacing: 32

            // Header icon
            Rectangle {
                width: 64
                height: 64
                radius: 32
                color: "#00D4AA20"
                border.color: "#00D4AA"
                border.width: 2
                anchors.horizontalCenter: parent.horizontalCenter

                Text {
                    anchors.centerIn: parent
                    text: "▶"
                    color: "#00D4AA"
                    font.pixelSize: 24
                    font.family: "Segoe UI"
                    font.weight: Font.Bold
                }
            }

            Text {
                width: parent.width
                text: startSubscribePopup.message
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                color: "#FFFFFF"
                font.family: "Segoe UI"
                font.pixelSize: 18
                font.weight: Font.Medium
                lineHeight: 1.4
            }

            BusyIndicator {
                id: startAppBusyIndicator
                width: 60
                height: 60
                anchors.horizontalCenter: parent.horizontalCenter
                running: true

                // Custom styling for busy indicator
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + 20
                    height: parent.height + 20
                    color: "transparent"
                    border.color: "#00D4AA20"
                    border.width: 1
                    radius: width / 2
                }
            }

            Button {
                text: "OK"
                width: 120
                height: 48
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: startSubscribePopup.accepted()
                
                background: Rectangle {
                    color: parent.hovered ? "#00E5BB" : "#00D4AA"
                    radius: 24
                    
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
                
                contentItem: Text {
                    text: parent.text
                    color: "#FFFFFF"
                    font.family: "Segoe UI"
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    Dialog {
        id: unSubscribePopup
        property string appIdString: ""
        width: Math.min(520, parent.width * 0.9)
        height: Math.min(380, parent.height * 0.7)
        anchors.centerIn: parent
        modal: true

        onAccepted: {
            appAsync.executeServices(appListView.currentIndex, activeAppName, appIdString, false);
            unSubscribePopup.close()
            var chkItem = appListView.itemAtIndex(appListView.currentIndex);
            var chkItemChildren = chkItem.children;
            for( var i = 0 ; i < chkItemChildren.length ; ++i) {
                if(chkItemChildren[i].objectName === appIdString) {
                    chkItemChildren[i].checked = false
                }
            }
            appListView.currentIndex = -1
        }
        
        onRejected: {
            unSubscribePopup.close()
            var chkItem = appListView.itemAtIndex(appListView.currentIndex);
            var chkItemChildren = chkItem.children;
            for( var i = 0 ; i < chkItemChildren.length ; ++i) {
                if(chkItemChildren[i].objectName === appIdString) {
                    chkItemChildren[i].checked = true
                }
            }
            appListView.currentIndex = -1
        }

        background: Rectangle {
            color: "#1A1A1A"
            radius: 20
            border.color: "#FF444460"
            border.width: 2
            
            Rectangle {
                anchors.fill: parent
                anchors.margins: -4
                color: "transparent"
                border.color: "#00000040"
                border.width: 1
                radius: 24
                z: -1
            }
        }

        contentItem: Column {
            anchors.fill: parent
            anchors.margins: 40
            spacing: 32

            // Warning icon
            Rectangle {
                width: 64
                height: 64
                radius: 32
                color: "#FF444420"
                border.color: "#FF4444"
                border.width: 2
                anchors.horizontalCenter: parent.horizontalCenter

                Text {
                    anchors.centerIn: parent
                    text: "⚠"
                    color: "#FF4444"
                    font.pixelSize: 28
                    font.family: "Segoe UI"
                }
            }

            Text {
                width: parent.width
                text: `Want to unsubscribe from <b>${activeAppName}</b>?<br><br>This app will be stopped when you press "Confirm"!`
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                color: "#FFFFFF"
                font.family: "Segoe UI"
                font.pixelSize: 18
                font.weight: Font.Medium
                lineHeight: 1.4
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 20

                Button {
                    text: "Cancel"
                    width: 120
                    height: 48
                    onClicked: unSubscribePopup.rejected()
                    
                    background: Rectangle {
                        color: parent.hovered ? "#353535" : "#2A2A2A"
                        radius: 24
                        border.color: parent.hovered ? "#606060" : "#404040"
                        border.width: 1
                        
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on border.color { ColorAnimation { duration: 200 } }
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "#FFFFFF"
                        font.family: "Segoe UI"
                        font.pixelSize: 16
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    text: "Confirm"
                    width: 120
                    height: 48
                    onClicked: unSubscribePopup.accepted()
                    
                    background: Rectangle {
                        color: parent.hovered ? "#FF6666" : "#FF4444"
                        radius: 24
                        
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "#FFFFFF"
                        font.family: "Segoe UI"
                        font.pixelSize: 16
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }

    Dialog {
        id: removeAppPopup
        property string appIdString: ""
        width: Math.min(520, parent.width * 0.9)
        height: Math.min(380, parent.height * 0.7)
        anchors.centerIn: parent
        modal: true

        onAccepted: {
            appAsync.removeServices(appListView.currentIndex);
            removeAppPopup.close()
            appListView.currentIndex = -1
        }
        
        onRejected: {
            removeAppPopup.close()
            appListView.currentIndex = -1
        }

        background: Rectangle {
            color: "#1A1A1A"
            radius: 20
            border.color: "#FF444460"
            border.width: 2
            
            Rectangle {
                anchors.fill: parent
                anchors.margins: -4
                color: "transparent"
                border.color: "#00000040"
                border.width: 1
                radius: 24
                z: -1
            }
        }

        contentItem: Column {
            anchors.fill: parent
            anchors.margins: 40
            spacing: 32

            // Delete icon
            Rectangle {
                width: 64
                height: 64
                radius: 32
                color: "#FF444420"
                border.color: "#FF4444"
                border.width: 2
                anchors.horizontalCenter: parent.horizontalCenter

                Text {
                    anchors.centerIn: parent
                    text: "🗑"
                    color: "#FF4444"
                    font.pixelSize: 24
                    font.family: "Segoe UI"
                }
            }

            Text {
                width: parent.width
                text: `Want to delete <b>${deleteAppName}</b>?<br><br>This app will be stopped and deleted when you press "Confirm"!`
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                color: "#FFFFFF"
                font.family: "Segoe UI"
                font.pixelSize: 18
                font.weight: Font.Medium
                lineHeight: 1.4
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 20

                Button {
                    text: "Cancel"
                    width: 120
                    height: 48
                    onClicked: removeAppPopup.rejected()
                    
                    background: Rectangle {
                        color: parent.hovered ? "#353535" : "#2A2A2A"
                        radius: 24
                        border.color: parent.hovered ? "#606060" : "#404040"
                        border.width: 1
                        
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on border.color { ColorAnimation { duration: 200 } }
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "#FFFFFF"
                        font.family: "Segoe UI"
                        font.pixelSize: 16
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    text: "Delete"
                    width: 120
                    height: 48
                    onClicked: removeAppPopup.accepted()
                    
                    background: Rectangle {
                        color: parent.hovered ? "#FF6666" : "#FF4444"
                        radius: 24
                        
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "#FFFFFF"
                        font.family: "Segoe UI"
                        font.pixelSize: 16
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }

    // Header
    Rectangle {
        id: headerArea
        width: parent.width
        height: 80
        color: "transparent"

        Text {
            text: "Vehicle Apps"
            x: 32
            y: 30
            font.bold: true
            font.pixelSize: 28
            font.weight: Font.Bold
            color: "#00D4AA"
            font.family: "Segoe UI"
        }
    }

    // Main content area
    Rectangle {
        id: contentArea
        anchors.top: headerArea.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 32
        color: "transparent"

        ListView {
            id: appListView
            anchors.fill: parent
            currentIndex: -1
            spacing: 16
            clip: true

            function setActiveIndex(index) {
                forceActiveFocus()
                currentIndex = index
            }

            delegate: Item {
                id: appListViewItem
                width: appListView.width
                height: 100
                visible: name.length > 0 && name !== "No Result."

                Rectangle {
                    id: appCard
                    anchors.fill: parent
                    color: "#1A1A1A"
                    radius: 16
                    border.color: "#2A2A2A"
                    border.width: 1

                    Row {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 20

                        // App icon
                        Rectangle {
                            width: 60
                            height: 60
                            radius: 12
                            color: "#2A2A2A"
                            border.color: "#404040"
                            border.width: 1
                            anchors.verticalCenter: parent.verticalCenter

                            Image {
                                id: appIcon
                                source: iconpath || ""
                                width: 40
                                height: 40
                                anchors.centerIn: parent
                                fillMode: Image.PreserveAspectFit
                                visible: iconpath && iconpath.length > 0

                                Rectangle {
                                    anchors.fill: parent
                                    visible: !appIcon.visible
                                    color: "#00D4AA20"
                                    radius: 8

                                    Text {
                                        anchors.centerIn: parent
                                        text: name.length > 0 ? name.charAt(0).toUpperCase() : "A"
                                        font.pixelSize: 20
                                        font.bold: true
                                        color: "#00D4AA"
                                        font.family: "Segoe UI"
                                    }
                                }
                            }
                        }

                        // App info
                        Column {
                            width: 300
                            spacing: 4
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                text: name
                                font.bold: true
                                font.pixelSize: 18
                                color: "#FFFFFF"
                                font.family: "Segoe UI"
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Text {
                                text: author
                                font.pixelSize: 14
                                color: "#B0B0B0"
                                font.family: "Segoe UI"
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Row {
                                spacing: 16
                                
                                Text {
                                    text: rating
                                    font.pixelSize: 12
                                    color: "#B0B0B0"
                                    font.family: "Segoe UI"
                                    visible: rating && rating !== "*"
                                }

                                Text {
                                    text: noofdownload + " downloads"
                                    font.pixelSize: 12
                                    color: "#B0B0B0"
                                    font.family: "Segoe UI"
                                    visible: noofdownload && noofdownload !== "0"
                                }
                            }
                        }

                        // Status badge
                        Rectangle {
                            visible: is_installed
                            width: 80
                            height: 28
                            radius: 14
                            color: "#00D4AA20"
                            border.color: "#00D4AA"
                            border.width: 1
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                anchors.centerIn: parent
                                text: "Installed"
                                color: "#00D4AA"
                                font.family: "Segoe UI"
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }
                        }

                        // Spacer
                        Item {
                            Layout.fillWidth: true
                            width: 50
                        }

                        // Controls
                        Row {
                            spacing: 12
                            anchors.verticalCenter: parent.verticalCenter

                            // Edit button - modern design without image
                            Rectangle {
                                width: 40
                                height: 40
                                radius: 20
                                color: "#2A2A2A"
                                border.color: "#404040"
                                border.width: 1

                                // Edit icon using text/symbols
                                Text {
                                    anchors.centerIn: parent
                                    text: "✎"
                                    color: "#B0B0B0"
                                    font.pixelSize: 16
                                    font.family: "Segoe UI"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: {
                                        parent.color = "#353535"
                                        parent.border.color = "#00D4AA40"
                                    }
                                    onExited: {
                                        parent.color = "#2A2A2A"
                                        parent.border.color = "#404040"
                                    }
                                    onClicked: {
                                        appAsync.openAppEditor(index)
                                    }
                                }

                                Behavior on color { ColorAnimation { duration: 200 } }
                                Behavior on border.color { ColorAnimation { duration: 200 } }
                            }

                            // Toggle switch - modern car-style design
                            Rectangle {
                                id: switchContainer
                                width: 60
                                height: 32
                                radius: 16
                                color: control.checked ? "#00D4AA" : "#2A2A2A"
                                border.color: control.checked ? "#00D4AA" : "#404040"
                                border.width: 1

                                // Running indicator light
                                Rectangle {
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: control.checked ? "#FFFFFF" : "transparent"
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: control.checked ? 8 : parent.width - width - 8
                                    opacity: control.checked ? 1 : 0

                                    // Pulsing animation when active
                                    SequentialAnimation on opacity {
                                        running: control.checked
                                        loops: Animation.Infinite
                                        NumberAnimation { to: 0.3; duration: 1000 }
                                        NumberAnimation { to: 1.0; duration: 1000 }
                                    }

                                    Behavior on x { NumberAnimation { duration: 200 } }
                                }

                                Rectangle {
                                    id: switchHandle
                                    width: 24
                                    height: 24
                                    radius: 12
                                    color: "#FFFFFF"
                                    border.color: control.checked ? "#00D4AA" : "#606060"
                                    border.width: 1
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: control.checked ? parent.width - width - 4 : 4

                                    // App icon in center
                                    Rectangle {
                                        width: 8
                                        height: 8
                                        radius: 4
                                        color: "transparent"
                                        border.color: control.checked ? "#00D4AA" : "#606060"
                                        border.width: 1
                                        anchors.centerIn: parent

                                        Rectangle {
                                            width: 2
                                            height: 4
                                            color: control.checked ? "#00D4AA" : "#606060"
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            y: 1
                                        }
                                    }

                                    Behavior on x { NumberAnimation { duration: 200 } }
                                    Behavior on border.color { ColorAnimation { duration: 200 } }
                                }

                                MouseArea {
                                    id: control
                                    objectName: appId
                                    property bool checked: isSubscribed
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        appListView.currentIndex = index
                                        if (checked === true) {
                                            // Currently ON, user wants to turn OFF - show unsubscribe popup
                                            control.checked = false
                                            unSubscribePopup.appIdString = objectName
                                            activeAppName = name
                                            unSubscribePopup.open()
                                        } else {
                                            // Currently OFF, user wants to turn ON - start the app
                                            control.checked = true
                                            startSubscribePopup.message = "Starting <b>" + name + "</b>..."
                                            startAppBusyIndicator.visible = true
                                            startAppBusyIndicator.running = true
                                            startSubscribePopup.open()
                                            appAsync.executeServices(appListView.currentIndex, name, objectName, true);
                                        }
                                    }
                                }

                                Behavior on color { ColorAnimation { duration: 200 } }
                                Behavior on border.color { ColorAnimation { duration: 200 } }
                            }

                            // Delete button - modern design without image
                            Rectangle {
                                width: 40
                                height: 40
                                radius: 20
                                color: "#FF444420"
                                border.color: "#FF4444"
                                border.width: 1

                                // Delete icon using text
                                Text {
                                    anchors.centerIn: parent
                                    text: "🗑"
                                    color: "#FF4444"
                                    font.pixelSize: 16
                                    font.family: "Segoe UI"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: {
                                        parent.color = "#FF444440"
                                        parent.scale = 1.1
                                    }
                                    onExited: {
                                        parent.color = "#FF444420"
                                        parent.scale = 1.0
                                    }
                                    onClicked: {
                                        appListView.currentIndex = index
                                        deleteAppName = name
                                        removeAppPopup.open()
                                    }
                                }

                                Behavior on color { ColorAnimation { duration: 200 } }
                                Behavior on scale { NumberAnimation { duration: 150 } }
                            }
                        }
                    }
                }
            }

            model: ListModel {
                id: appListModel
                ListElement {
                    name: ""
                    author: ""
                    rating: ""
                    noofdownload: ""
                    iconpath: ""
                    is_installed: false
                    isSubscribed: false
                    appId: ""
                }
            }
        }

        // Empty state - only show when no real apps exist
        Column {
            anchors.centerIn: parent
            spacing: 16
            visible: {
                var hasRealApps = false;
                for (var i = 0; i < appListModel.count; i++) {
                    var item = appListModel.get(i);
                    if (item && item.name && item.name.length > 0 && item.name !== "No Result.") {
                        hasRealApps = true;
                        break;
                    }
                }
                return !hasRealApps;
            }

            Rectangle {
                width: 80
                height: 80
                radius: 40
                color: "#2A2A2A"
                anchors.horizontalCenter: parent.horizontalCenter

                Text {
                    anchors.centerIn: parent
                    text: "📱"
                    font.pixelSize: 32
                }
            }

            Text {
                text: "No Apps Installed"
                font.pixelSize: 18
                font.weight: Font.Medium
                color: "#B0B0B0"
                font.family: "Segoe UI"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "Install apps from the Market Place to see them here"
                font.pixelSize: 14
                color: "#707070"
                font.family: "Segoe UI"
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}