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
import QtQuick.Window
import DigitalAutoAppAsync 1.0

Rectangle {
    id: digitalautowindow
    width: Screen.width
    height: Screen.height
    visible: true
    color: "#0F0F0F"

    property string dreamKIT_ID: ''
    property string activeAppName: ""
    property string deleteAppName: ""

    Component.onCompleted: {
        daAppListModel.clear()
        digitalAutoAppAsync.initSubscribeAppFromDB()
    }

    DigitalAutoAppAsync {
        id: digitalAutoAppAsync

        onUpdateBoardSerialNumber: (serial)=> {
            dreamKIT_ID = serial
        }

        onClearAppListView: {
            daAppListModel.clear()
        }

        onSetProgressVisibility: (visible)=> {
            dd_downloadprogress.visible = visible
        }

        onUpdateProgressValue: (percent)=> {
            dd_downloadprogress.value = percent
        }

        onAppendAppInfoToAppList: (name, appId, isSubscribed) => {
            console.log(name, appId)
            if (name === "") {
                daAppListModel.append({name: "No Result.", appId: ""})
            }
            else {
                daAppListModel.append({name: name, appId: appId, isSubscribed: isSubscribed})
            }
        }

        onUpdateStartAppMsg: (appId, isStarted, msg) => {
            startSubscribePopup.message = msg
            var chkItem = daSubscribeListview.itemAtIndex(daSubscribeListview.currentIndex);
            var chkItemChildren = chkItem.children;
            for( var i = 0 ; i < chkItemChildren.length ; ++i) {
                if(chkItemChildren[i].objectName === appId) {
                    if (isStarted) {
                        chkItemChildren[i].checked = true
                    }
                    else {
                        chkItemChildren[i].checked = false
                    }
                }
            }
            daSubscribeListview.currentIndex = -1
            startAppBusyIndicator.visible = false
            startAppBusyIndicator.running = false
        }

        onUpdateAppRunningSts: (appId, isStarted, idx) => {
            var chkItem = daSubscribeListview.itemAtIndex(idx);
            var chkItemChildren = chkItem.children;
            for( var i = 0 ; i < chkItemChildren.length ; ++i) {
                if(chkItemChildren[i].objectName === appId) {
                    if (isStarted) {
                        chkItemChildren[i].checked = true
                    }
                    else {
                        chkItemChildren[i].checked = false
                    }
                }
            }
        }
    }

    // Enhanced popup dialogs with modern styling
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
            console.log("unsubscribe: onAccepted clicked")
            digitalAutoAppAsync.executeApp(activeAppName, appIdString, false);
            unSubscribePopup.close()
            var chkItem = daSubscribeListview.itemAtIndex(daSubscribeListview.currentIndex);
            var chkItemChildren = chkItem.children;
            for( var i = 0 ; i < chkItemChildren.length ; ++i) {
                if(chkItemChildren[i].objectName === appIdString) {
                    chkItemChildren[i].checked = false
                }
            }
            daSubscribeListview.currentIndex = -1
        }

        onRejected: {
            console.log("unsubscribe: rejected clicked")
            unSubscribePopup.close()
            var chkItem = daSubscribeListview.itemAtIndex(daSubscribeListview.currentIndex);
            var chkItemChildren = chkItem.children;
            for( var i = 0 ; i < chkItemChildren.length ; ++i) {
                if(chkItemChildren[i].objectName === appIdString) {
                    chkItemChildren[i].checked = true
                }
            }
            daSubscribeListview.currentIndex = -1
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
                text: `Want to unsubscribe from <b>${activeAppName}</b>?<br><br>This feature will be stopped when you press "Confirm"!`
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
            console.log("removeAppPopup: onAccepted clicked")
            digitalAutoAppAsync.removeApp(daSubscribeListview.currentIndex);
            removeAppPopup.close()
            daSubscribeListview.currentIndex = -1
        }

        onRejected: {
            console.log("removeAppPopup: rejected clicked")
            removeAppPopup.close()
            daSubscribeListview.currentIndex = -1
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
                text: `Want to delete <b>${deleteAppName}</b>?<br><br>This feature will be stopped and deleted when you press "Confirm"!`
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

    // Modern header with device ID (improved visibility)
    Rectangle {
        id: headerArea
        width: parent.width
        height: 110
        color: "transparent"
        z: 100

        // Device ID Card
        Rectangle {
            id: deviceIdCard
            width: Math.min(540, parent.width * 0.80)
            height: 88
            radius: 22
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 32
            color: "#181818"
            border.color: dreamKIT_ID ? "#00D4AA90" : "#FF444490"
            border.width: 2
            //elevation: 4 // Uncomment if using Material style

            Row {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 24

                Rectangle {
                    width: 18
                    height: 18
                    radius: 9
                    color: dreamKIT_ID ? "#00D4AA" : "#FF4444"
                    anchors.verticalCenter: parent.verticalCenter

                    SequentialAnimation on opacity {
                        running: dreamKIT_ID
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 1000 }
                        NumberAnimation { to: 1.0; duration: 1000 }
                    }
                }

                Column {
                    spacing: 4
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        text: dreamKIT_ID ? "Device ID:" : ""
                        color: dreamKIT_ID ? "#B0FFF2" : "#FFAAAA"
                        font.family: "Segoe UI"
                        font.pixelSize: 28
                        font.weight: Font.DemiBold
                        visible: dreamKIT_ID
                    }
                    Text {
                        text: dreamKIT_ID ? dreamKIT_ID : "Device Disconnected"
                        color: dreamKIT_ID ? "#00D4AA" : "#FF4444"
                        font.family: "Segoe UI"
                        font.pixelSize: dreamKIT_ID ? 32 : 32
                        font.weight: Font.Bold
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }

    // Modern progress bar
    ProgressBar {
        id: dd_downloadprogress
        width: Math.min(400, parent.width * 0.4)
        height: 8
        anchors.top: headerArea.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        from: 0
        to: 100
        value: 50
        visible: false

        background: Rectangle {
            color: "#2A2A2A"
            radius: 4
            border.color: "#404040"
            border.width: 1
        }

        contentItem: Rectangle {
            width: dd_downloadprogress.visualPosition * parent.width
            height: parent.height
            radius: 4
            color: "#00D4AA"

            Rectangle {
                anchors.fill: parent
                color: "#FFFFFF40"
                radius: 4
                opacity: 0.3
            }
        }
    }

    // Main content area
    Rectangle {
        id: contentArea
        anchors.top: dd_downloadprogress.visible ? dd_downloadprogress.bottom : headerArea.bottom
        anchors.topMargin: 20
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 32
        color: "transparent"

        // Tab header
        ListView {
            id: appListMenu
            width: parent.width
            height: 60
            orientation: ListView.Horizontal
            currentIndex: 0
            spacing: 0

            delegate: Rectangle {
                width: 280
                height: 60
                color: appListMenu.currentIndex === index ? "#1A1A1A" : "transparent"
                radius: appListMenu.currentIndex === index ? 16 : 0
                border.color: appListMenu.currentIndex === index ? "#00D4AA40" : "transparent"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: name
                    font.bold: true
                    font.pixelSize: 18
                    color: appListMenu.currentIndex === index ? "#00D4AA" : "#B0B0B0"
                    font.family: "Segoe UI"
                }

                Rectangle {
                    width: parent.width * 0.8
                    height: 2
                    color: "#00D4AA"
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: appListMenu.currentIndex === index
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        appListMenu.forceActiveFocus()
                        appListMenu.currentIndex = index
                    }
                }

                Behavior on color { ColorAnimation { duration: 200 } }
            }

            model: ListModel {
                ListElement {
                    name: "Digital Auto Deployment"
                }
            }
        }

        // App list
        ListView {
            id: daSubscribeListview
            anchors.top: appListMenu.bottom
            anchors.topMargin: 20
            width: parent.width
            height: parent.height - appListMenu.height - 20
            clip: true
            currentIndex: -1
            spacing: 16

            delegate: Rectangle {
                width: daSubscribeListview.width
                height: 100
                color: "#1A1A1A"
                radius: 16
                border.color: "#2A2A2A"
                border.width: 1

                Row {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 20

                    // App icon placeholder
                    Rectangle {
                        width: 60
                        height: 60
                        radius: 12
                        color: "#00D4AA20"
                        border.color: "#00D4AA40"
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: name.length > 0 ? name.charAt(0).toUpperCase() : "D"
                            font.pixelSize: 20
                            font.bold: true
                            color: "#00D4AA"
                            font.family: "Segoe UI"
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
                            text: "Digital Auto Application"
                            font.pixelSize: 14
                            color: "#B0B0B0"
                            font.family: "Segoe UI"
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

                        // Edit button
                        Rectangle {
                            width: 40
                            height: 40
                            radius: 20
                            color: "#2A2A2A"
                            border.color: "#404040"
                            border.width: 1

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
                                    digitalAutoAppAsync.openAppEditor(index)
                                }
                            }

                            Behavior on color { ColorAnimation { duration: 200 } }
                            Behavior on border.color { ColorAnimation { duration: 200 } }
                        }

                        // Toggle switch
                        Rectangle {
                            id: switchContainer
                            width: 60
                            height: 32
                            radius: 16
                            color: control.checked ? "#00D4AA" : "#2A2A2A"
                            border.color: control.checked ? "#00D4AA" : "#404040"
                            border.width: 1

                            Rectangle {
                                width: 6
                                height: 6
                                radius: 3
                                color: control.checked ? "#FFFFFF" : "transparent"
                                anchors.verticalCenter: parent.verticalCenter
                                x: control.checked ? 8 : parent.width - width - 8
                                opacity: control.checked ? 1 : 0

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
                                    console.log ("index : ", index)
                                    daSubscribeListview.currentIndex = index

                                    if (control.checked === true) {
                                        control.checked = false
                                        startSubscribePopup.message = "Starting <b>" + name + "</b>..."
                                        startAppBusyIndicator.visible = true
                                        startAppBusyIndicator.running = true
                                        startSubscribePopup.open()
                                        digitalAutoAppAsync.executeApp(name, objectName, true);
                                    }
                                    else {
                                        control.checked = true
                                        unSubscribePopup.appIdString = objectName
                                        activeAppName = name
                                        unSubscribePopup.open()
                                    }
                                }
                            }

                            Behavior on color { ColorAnimation { duration: 200 } }
                            Behavior on border.color { ColorAnimation { duration: 200 } }
                        }

                        // Delete button
                        Rectangle {
                            width: 40
                            height: 40
                            radius: 20
                            color: "#FF444420"
                            border.color: "#FF4444"
                            border.width: 1

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
                                    daSubscribeListview.currentIndex = index
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

            model: ListModel {
                id: daAppListModel
                ListElement {
                    name: "App1"
                    appId: "AppId1"
                    isSubscribed: false
                }
                ListElement {
                    name: "App2"
                    appId: "AppId2"
                    isSubscribed: false
                }
                ListElement {
                    name: "App3"
                    appId: "AppId3"
                    isSubscribed: false
                }
                ListElement {
                    name: "App4"
                    appId: "AppId4"
                    isSubscribed: false
                }
                ListElement {
                    name: "App5"
                    appId: "AppId5"
                    isSubscribed: false
                }
                ListElement {
                    name: "App6"
                    appId: "AppId6"
                    isSubscribed: false
                }
                ListElement {
                    name: "App7"
                    appId: "AppId7"
                    isSubscribed: false
                }
                ListElement {
                    name: "App8"
                    appId: "AppId8"
                    isSubscribed: false
                }
                ListElement {
                    name: "App9"
                    appId: "AppId9"
                    isSubscribed: false
                }
                ListElement {
                    name: "App10"
                    appId: "AppId10"
                    isSubscribed: false
                }
            }
        }
    }
}
