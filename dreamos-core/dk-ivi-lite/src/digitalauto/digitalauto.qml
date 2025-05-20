import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import DigitalAutoAppAsync 1.0

Rectangle {
    id: digitalautowindow
    width: Screen.width
    height: Screen.height
//    width: 800
//    height: 600
    visible: true
//    visibility: "FullScreen"
//    flags: Qt.Window | Qt.FramelessWindowHint

    Rectangle {
        id: bg
        color: "#212121"
        anchors.fill: parent
    }
    
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
//            console.log("onUpdateBoardSerialNumber: ---------------------------------------- ", serial)
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

                                 //            console.log("daSubscribeListview.currentIndex: ", daSubscribeListview.currentIndex)
                                 var chkItem = daSubscribeListview.itemAtIndex(daSubscribeListview.currentIndex);
                                 var chkItemChildren = chkItem.children;
                                 // iterate over children using any machanism you prefer to filter those children
                                 //
                                 for( var i = 0 ; i < chkItemChildren.length ; ++i) {
                                     //                console.log("delegate Object name: ", chkItemChildren[i].objectName)
                                     if(chkItemChildren[i].objectName === appId) {
                                         if (isStarted) {
                                             chkItemChildren[i].checked = true
                                         }
                                         else {
                                             chkItemChildren[i].checked = false
                                         }
                                         //                    console.log("found object: ", appIdString)
                                     }
                                 }
                                 daSubscribeListview.currentIndex = -1

                                 startAppBusyIndicator.visible = false
                                 startAppBusyIndicator.running = false
                             }
        
        onUpdateAppRunningSts: (appId, isStarted, idx) => {                                 
                                 var chkItem = daSubscribeListview.itemAtIndex(idx);
                                 var chkItemChildren = chkItem.children;
                                 // iterate over children using any machanism you prefer to filter those children
                                 for( var i = 0 ; i < chkItemChildren.length ; ++i) {
                                     //                console.log("delegate Object name: ", chkItemChildren[i].objectName)
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
    
    Dialog {
        id: startSubscribePopup
        property string message: ""
        width: 500
        height: 400
        anchors.centerIn: parent
        modal: true

//        Overlay.modal: Rectangle {
//            x: digitalautoItem.x
//            y: digitalautoItem.y
//            height: digitalautoItem.height/2
//            color: "#aacfdbe7"
//        }

        onAccepted: {
            startSubscribePopup.close()
        }

        contentItem: Rectangle {
            anchors.fill: parent
            width: 500
            height: 400
            color: "#676767"
            //            border.width: 1
            //            border.color: "white"

//            DropShadow {
//                anchors.fill: parent
//                horizontalOffset: 3
//                verticalOffset: 3
//                radius: 8.0
//                color: "#909090"
//                source: parent
//            }

            Rectangle {
                x: 0
                y: 0
                width: parent.width
                height: 300
                color: "#00000000"

                Text {
                    width: parent.width
                    height: 200
                    anchors.centerIn: parent
                    text: startSubscribePopup.message
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: "white"
                    font.pointSize: 16
                }
            }

            BusyIndicator {
                id: startAppBusyIndicator
                y: 270
                height: 50
                width: 50
                anchors.horizontalCenter: parent.horizontalCenter
                running: true
            }

            Rectangle {
                width: 160
                height: 80
                x: 170
                y: 300
                color: "#00000000"

                Text {
                    anchors.fill: parent
                    anchors.centerIn: parent
                    text: qsTr("OK")
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: "white"
                    font.pointSize: 18
                    font.bold: true
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        startSubscribePopup.accepted()
                    }
                }
            }
        }
    }

    Dialog {
        id: unSubscribePopup
        property string appIdString: ""
        width: 500
        height: 400
        anchors.centerIn: parent
        modal: true

        onAccepted: {
            console.log("unsubscribe: onAccepted clicked")
            digitalAutoAppAsync.executeApp(activeAppName, appIdString, false);
            unSubscribePopup.close()
//            console.log("daSubscribeListview.currentIndex: ", daSubscribeListview.currentIndex)
            var chkItem = daSubscribeListview.itemAtIndex(daSubscribeListview.currentIndex);
            var chkItemChildren = chkItem.children;
            // iterate over children using any machanism you prefer to filter those children
            //
            for( var i = 0 ; i < chkItemChildren.length ; ++i) {
//                console.log("delegate Object name: ", chkItemChildren[i].objectName)
                if(chkItemChildren[i].objectName === appIdString) {
                    chkItemChildren[i].checked = false
//                    console.log("found object: ", appIdString)
                }
            }
            daSubscribeListview.currentIndex = -1
        }
        onRejected: {
            console.log("unsubscribe: rejected clicked")
            unSubscribePopup.close()
//            console.log("daSubscribeListview.currentIndex: ", daSubscribeListview.currentIndex)
            var chkItem = daSubscribeListview.itemAtIndex(daSubscribeListview.currentIndex);
            var chkItemChildren = chkItem.children;
            // iterate over children using any machanism you prefer to filter those children
            //
            for( var i = 0 ; i < chkItemChildren.length ; ++i) {
//                console.log("delegate Object name: ", chkItemChildren[i].objectName)
                if(chkItemChildren[i].objectName === appIdString) {
                    chkItemChildren[i].checked = true
//                    console.log("found object: ", appIdString)
                }
            }
            daSubscribeListview.currentIndex = -1
        }

        contentItem: Rectangle {
            anchors.fill: parent
            width: 500
            height: 400
            color: "#676767"
            //            border.width: 1
            //            border.color: "white"

//            DropShadow {
//                anchors.fill: parent
//                horizontalOffset: 3
//                verticalOffset: 3
//                radius: 8.0
//                color: "#909090"
//                source: parent
//            }

            Rectangle {
                x: 0
                y: 0
                width: parent.width
                height: 300
                color: "#00000000"

                Text {
                    width: parent.width
                    height: 200
                    anchors.centerIn: parent
                    text: `Want to unsubcribe to <b>${activeAppName}</b> ?<br><br>This feature shall be stopped when you press "Confirm" !!!`
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: "white"
                    font.pointSize: 16
                }
            }

            Rectangle {
                x: 40
                y: 300
                width: 160
                height: 80
                color: "#00000000"

                Text {
                    anchors.fill: parent
                    anchors.centerIn: parent
                    text: qsTr("No")
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: "white"
                    font.pointSize: 18
                    font.bold: true
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        unSubscribePopup.rejected()
                    }
                }
            }

            Rectangle {
                width: 160
                height: 80
                x: 300
                y: 300
                color: "#00000000"

                Text {
                    anchors.fill: parent
                    anchors.centerIn: parent
                    text: qsTr("Confirm")
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: "white"
                    font.pointSize: 18
                    font.bold: true
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        unSubscribePopup.accepted()
                    }
                }
            }
        }
    }

    Dialog {
        id: removeAppPopup
        property string appIdString: ""
        width: 500
        height: 400
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

        contentItem: Rectangle {
            anchors.fill: parent
            width: 500
            height: 400
            color: "#676767"

            Rectangle {
                x: 0
                y: 0
                width: parent.width
                height: 300
                color: "#00000000"

                Text {
                    width: parent.width
                    height: 200
                    anchors.centerIn: parent
                    text: `Want to delete <b>${deleteAppName}</b> ?<br><br>This feature shall be stopped and deleted when you press "Confirm" !!!`
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: "white"
                    font.pointSize: 16
                }
            }

            Rectangle {
                x: 40
                y: 300
                width: 160
                height: 80
                color: "#00000000"

                Text {
                    anchors.fill: parent
                    anchors.centerIn: parent
                    text: qsTr("No")
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: "white"
                    font.pointSize: 18
                    font.bold: true
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        removeAppPopup.rejected()
                    }
                }
            }

            Rectangle {
                width: 160
                height: 80
                x: 300
                y: 300
                color: "#00000000"

                Text {
                    anchors.fill: parent
                    anchors.centerIn: parent
                    text: qsTr("Confirm")
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: "white"
                    font.pointSize: 18
                    font.bold: true
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        removeAppPopup.accepted()
                    }
                }
            }
        }
    }

    Text {
        x: 10
        y: 20
        z: 100
        text: 'ID: ' + dreamKIT_ID
        color: '#8BC34A'
        font.pointSize: 11
    }
    
    ProgressBar {
        id: dd_downloadprogress
        width: digitalautowindow.width/3
        height: 20
        y: 20
        from: 0
        to: 100
        value: 50
        padding: 1
        visible: false
        anchors.horizontalCenter: parent.horizontalCenter

        background: Rectangle {
            implicitWidth: dd_downloadprogress.width
            implicitHeight: 6
            color: "#e6e6e6"
            radius: 3
        }

        contentItem: Item {
            implicitWidth: dd_downloadprogress.width
            implicitHeight: 4

            Rectangle {
                width: dd_downloadprogress.visualPosition * parent.width
                height: parent.height
                radius: 2
                color: "#17a81a"
            }
        }
    }

    Rectangle {
        id: searchDigitalAutoAppRec
        x: 10
        y: dd_downloadprogress.y + 10
        width: digitalautowindow.width - 20
        height: digitalautowindow.height
        clip: true
        color: "transparent"
        border.width: 0

        ListView {
            id: appListMenu
            x: 0
            y: 20
            width: parent.width
            height: 50
            orientation: ListView.Horizontal
            clip: true
            currentIndex: -1
            spacing: 16
            highlight: Rectangle {
                color: "transparent"
                Rectangle {
                    id: borderLeft
                    width: parent.width
                    height: 1
                    anchors.bottom: parent.bottom
                    color: "white"
                }
            }

            delegate: Item {
                id: item2
                x: 5
                width: 250
                height: 40

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    Text {
                        text: name
                        font.bold: true
                        font.pointSize: 14
                        color: "#8BC34A"
                        font.family: "Arial"
                        anchors.centerIn: parent
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        appListMenu.forceActiveFocus()
                        appListMenu.currentIndex = index
                    }
                }
            }
            model: ListModel {
                ListElement {
                    name: "digitalauto Deployment"
                }
            }
        }

        ListView {
            x: 0
            y: 70
            width: searchDigitalAutoAppRec.width
            height: searchDigitalAutoAppRec.height - 100
            id: daSubscribeListview
            clip: true
            currentIndex: -1
//            ScrollBar.vertical: ScrollBar {
//                policy: ScrollBar.AlwaysOn
//                active: ScrollBar.AlwaysOn
//            }

            delegate: Rectangle {
                x: 0
                y: 0
                width: searchDigitalAutoAppRec.width
                height: searchDigitalAutoAppRec.height/7
                clip: true
                color: "transparent"
                border.width: 0

                Text {
                    y: 7
                    text: name
                    color: "white"
                    font.pixelSize: 20
                }

                Rectangle {
                    y: 50
                    width: searchDigitalAutoAppRec.width
                    height: 1
                    color: "white"
                    border.width: 1
                    border.color: "white"
                }

                Rectangle {
                    id: deleteDaAppRec
                    implicitWidth: 70
                    implicitHeight: 26
                    x: searchDigitalAutoAppRec.width - 100
                    y: control.y + 8
                    radius: 13
                    color: "red"
                    border.color: "red"
                    Text {
                        y: 2
                        text: "    X"
                        color: "white"
                        font.pixelSize: 20
                    }
                    //Image {
                    //    x: 20
                    //    source: "resource/trashbin2.png"
                    //    height: 25
                    //    width: 25
                    //}
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            daSubscribeListview.currentIndex = index
                            deleteAppName = name
                            removeAppPopup.open()
                        }
                    }
                }

                SwitchDelegate {
                    id: control
                    objectName: appId
                    checked: isSubscribed
                    x: deleteDaAppRec.x - deleteDaAppRec.width - 100

                    indicator: Rectangle {
                        implicitWidth: 70
                        implicitHeight: 26
                        x: control.width - width - control.rightPadding
                        y: parent.height / 2 - height / 2
                        radius: 13
                        color: control.checked ? "#17a81a" : "transparent"
                        border.color: control.checked ? "#17a81a" : "#cccccc"

                        Rectangle {
                            x: control.checked ? parent.width - width : 0
                            width: 26
                            height: 26
                            radius: 13
                            color: control.down ? "#cccccc" : "#ffffff"
                            border.color: control.checked ? (control.down ? "#17a81a" : "#21be2b") : "#999999"
                        }
                    }

                    background: Rectangle {
                        implicitWidth: 100
                        implicitHeight: 40
                        visible: control.down || control.highlighted
                        color: "transparent"
                    }

                    onClicked: () => {
//                                   console.log ("you just switch a digital auto app: ", control.checked)
                                   console.log ("index : ", index)
                                   daSubscribeListview.currentIndex = index

                                   if (control.checked === true) {
                                       control.checked = false
                                       startSubscribePopup.message = "Starting <b>" + name + "</b> ..."
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

                Rectangle {
                    implicitWidth: 70
                    implicitHeight: 26
                    x: control.x - control.width - 30
                    y: control.y + 8
                    radius: 13
                    color: "transparent"
                    border.color: "transparent"
                    Image {
                        x: 20
                        source: "../resource/icons/editicon3.png"
                        height: 25
                        width: 25
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            digitalAutoAppAsync.openAppEditor(index)
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
