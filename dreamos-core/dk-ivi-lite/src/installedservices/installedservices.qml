import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../resource/customwidgets"
import ServicesAsync 1.0

Rectangle {
    id: installedservices_page
    visible: true
    layer.enabled: true
    width: Screen.width
    height: Screen.height

    property int numbeOfInstalledApps: 0
    property int numbeOfSearchedApps: 0

    property int installAppIndex: -1
    property bool isSearchTextInputEmpty: true
    property int removeAppIndex: -1

    property string activeAppName: ""
    property string deleteAppName: ""

    Rectangle {
        id: bg
        color: "#212121"
        anchors.fill: parent
    }

    Component.onCompleted: {
        appListModel.clear()
        appAsync.initInstalledServicesFromDB()
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

    ServicesAsync {
        id: appAsync

        onClearServicesListView: {
            appListModel.clear()
        }

        onAppendServicesInfoToServicesList: (name, author, rating, noofdownload, icon, isInstalled, appId, isSubscribed) => {
                                      console.log(name, author, rating, noofdownload, icon)
                                      if (name === "") {
                                          appListModel.append({name: "No Result.", author: "", rating: "", noofdownload: "", iconpath: "", is_installed: false, appId: "", isSubscribed: false})
                                      }
                                      else {
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

        onAppendLastRowToServicesList:  (noOfApps) => {
                                       console.log("onAppendLastRowToAppList")
                                       numbeOfSearchedApps = noOfApps
                                       appListModel.append({name: "", author: "", rating: "", noofdownload: "", iconpath: ""})
                                       appListView.positionViewAtBeginning()
                                   }
                                   
        onUpdateStartAppMsg: (appId, isStarted, msg) => {
                                 startSubscribePopup.message = msg

                                 console.log("onUpdateStartAppMsg: appListView.currentIndex: ", appListView.currentIndex)
                                 var chkItem = appListView.itemAtIndex(appListView.currentIndex);
                                 var chkItemChildren = chkItem.children;
                                 // iterate over children using any machanism you prefer to filter those children
                                 for( var i = 0 ; i < chkItemChildren.length ; ++i) {
                                     console.log("delegate Object name: ", chkItemChildren[i].objectName)
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
                                 appListView.currentIndex = -1

                                 startAppBusyIndicator.visible = false
                                 startAppBusyIndicator.running = false
                             }

        onUpdateServicesRunningSts: (appId, isStarted, idx) => {         
                                // Usage:
                                var chkItem = appListView.itemAtIndex(idx);
                                var foundChild = findChildByObjectName(chkItem, appId);
                                if (foundChild) {
                                    foundChild.checked = isStarted;
                                } else {
                                    console.log("No child with objectName: ", appId);
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

        onAccepted: {
            startSubscribePopup.close()
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
            appAsync.executeServices(appListView.currentIndex, activeAppName, appIdString, false);
            unSubscribePopup.close()
//            console.log("appListView.currentIndex: ", appListView.currentIndex)
            var chkItem = appListView.itemAtIndex(appListView.currentIndex);
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
            appListView.currentIndex = -1
        }
        onRejected: {
            console.log("unsubscribe: rejected clicked")
            unSubscribePopup.close()
//            console.log("appListView.currentIndex: ", appListView.currentIndex)
            var chkItem = appListView.itemAtIndex(appListView.currentIndex);
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
            appListView.currentIndex = -1
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
            appAsync.removeServices(appListView.currentIndex);
            removeAppPopup.close()
            appListView.currentIndex = -1
        }
        onRejected: {
            console.log("removeAppPopup: rejected clicked")
            removeAppPopup.close()
            appListView.currentIndex = -1
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

    Rectangle {
        id: searchAppRec
        x: 38
        y: 100
        width: installedservices_page.width - 100
        height: installedservices_page.height - 100
        clip: true
        color: "transparent"
        border.color: "#d7d9cc"
        border.width: 0
        visible: true

        ListView {
            id: appListView
            property int installPopupX: 0
            property int installPopupY: 0
            currentIndex: -1
            x: 19
            y: 0
            width: searchAppRec.width
            height: searchAppRec.width
            clip: true

            function setActiveIndex(index) {
                appListView.forceActiveFocus()
                appListView.currentIndex = index
            }

            delegate: Item {
                id: appListViewItem
                x: 5
                width: appListView.width
                height: 100
                clip: true
                Rectangle {
                        x: 0
                        y: 80
                        width: appListView.width
                        height: 1
                        color: "white"
                        border.width: 1
                        border.color: "white"
                    }
                Row {
                    id: row1
                    spacing: 20
                    width: appListViewItem.width
                    height: 50
                    //clip: true                     
                    Image {
                        //                        id: imageId
                        source: iconpath
                        width: row1.height
                        height: row1.height
                    }

                    Rectangle {
                        x: row1.height + 30
                        height: appListViewItem.height
                        width: 300
                        color: "#00000000"
                        clip: true
                        Text {
                            id: appNameId
                            x: 0
                            y: 0
                            text: name
                            font.bold: true
                            font.pixelSize: 20
                            color: "#90ebebeb"
                            font.family: "Arial"
                        }
                        Text {
                            id: authorId
                            x: 0
                            y: appNameId.y + appNameId.height + 6
                            text: author
                            font.bold: false
                            font.pixelSize: 14
                            color: "#90ebebeb"
                            font.family: "Arial"
                        }
                        Text {
                            id: ratingId
                            x: 0
                            y: authorId.y + authorId.height + 4
                            text: rating
                            font.bold: false
                            font.pixelSize: 14
                            color: "#90ebebeb"
                            font.family: "Arial"
                        }
                        Text {
                            id: noofdownloadId
                            x: 70
                            y: ratingId.y
                            text: noofdownload
                            font.bold: false
                            font.pixelSize: 14
                            color: "#90ebebeb"
                            font.family: "Arial"
                        }
                    }

                    Rectangle {
                        visible: is_installed && name.length>0
                        width: 120
                        height: row1.height
                        x: 500
                        y: 0
                        //                        anchors.right: row1.right - 20
                        color: "#00000000"
                        Text {
                            anchors.fill: parent
                            anchors.centerIn: parent
                            text: qsTr("Installed")
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            color: "#90ebebeb"
                            font.family: "Arial"
                            font.pointSize: 13
                            font.bold: true
                        }
                    }

                    Rectangle {
                        id: deleteDaAppRec1
                        implicitWidth: 70
                        implicitHeight: 26
                        x: 1200
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
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                appListView.currentIndex = index
                                deleteAppName = name
                                removeAppPopup.open()
                            }
                        }
                    }
    
                    SwitchDelegate {
                        id: control
                        objectName: appId
                        checked: isSubscribed
                        x: deleteDaAppRec1.x - deleteDaAppRec1.width - 100
    
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
//                                       console.log ("you just switch a digital auto app: ", control.checked)
                                       console.log ("index : ", index)
                                       appListView.currentIndex = index
    
                                       if (control.checked === true) {
                                           control.checked = false
                                           startSubscribePopup.message = "Starting <b>" + name + "</b> ..."
                                           startAppBusyIndicator.visible = true
                                           startAppBusyIndicator.running = true
                                           startSubscribePopup.open()
                                           appAsync.executeServices(appListView.currentIndex, name, objectName, true);                                           
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
                                appAsync.openAppEditor(index)
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
    }

    Text {
        text: "Vehicle Services"
        x: 30
        y: 30
        font.bold: true
        font.pointSize: 20
        color: "#8BC34A"
        font.family: "Arial"
    }
    
    Item {
        id: __materialLibrary__
    }

}

/*##^##
Designer {
    D{i:0;formeditorZoom:0.66}
}
##^##*/
