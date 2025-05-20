import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import "../resource/customwidgets"
import MarketplaceAsync 1.0
//import Qt5Compat.GraphicalEffects

Rectangle {
    id: marketplace_page
    visible: true
    layer.enabled: true
    //width: 778
    //height: 1025
    width: parent.width
    height: parent.height

//     property alias searchTextInput: searchTextInput

    property int numbeOfInstalledApps: 0
    property int numbeOfSearchedApps: 0

    property int installAppIndex: -1
    property bool isSearchTextInputEmpty: true
    property int removeAppIndex: -1

    property string activeAppName: ""

    Rectangle {
        id: bg
        color: "#212121"
        anchors.fill: parent
    }

    function searchApp () {
        appListModel.clear()
        appAsync.searchAppFromStore(searchTextInput.text)
        appListMenu.currentIndex = -1
        Qt.inputMethod.hide();
    }

    Component.onCompleted: {
        appAsync.initMarketplaceListFromDB()
    }

    Connections {
        target: appListMenu
        function onCurrentIndexChanged() {
            if (appListMenu.currentIndex === -1) {
                return
            }

            // clear the searched list
            appListModel.clear()

            // reset input search text editor
            searchTextInput.text = "Search"
            isSearchTextInputEmpty = true

            //                console.log("appListMenu.currentIndex: ", appListMenu.currentIndex)
            if (appListMenu.currentIndex === 0) {
                appAsync.searchAppFromStore("vehicle")
            }
            else if (appListMenu.currentIndex === 1) {
                appAsync.searchAppFromStore("vehicle-service")
            }
            else {
                appAsync.searchAppFromStore("XXXXXX")
            }

            //          appListMenu.currentIndex = -1
        }
    }

    Connections {
        target: appListView
        function onCurrentIndexChanged() {
            console.log(`appListView index changed to ${appListView.currentIndex}`)
            if ((appListView.currentIndex === -1)
                    || (appListView.currentIndex >= (appListView.count - 1))
                    || (appListView.currentIndex >= (numbeOfSearchedApps)))  {
                appListView.currentIndex = -1
                return
            }

            //             console.log(appListView.currentIndex)

            let matchApp = appListModel.get(appListView.currentIndex)
            if(matchApp && !matchApp.is_installed) {
                activeAppName = matchApp.name
                installAppIndex = appListView.currentIndex
                if (notifArea.visible === false) {
                    installAppPopup.open()
                }
            }
            //             appListView.currentIndex = -1
        }
    }

    Connections {
        target: searchTextInput
        function accepted() {
            console.log("searchTextInput accepted")
            Qt.inputMethod.hide();
        }

        function onEditingFinished() {
            console.log("onEditingFinished finish")
            Qt.inputMethod.hide();
            if (searchTextInput.text === "") {
                searchTextInput.text = "Search"
                isSearchTextInputEmpty = true
                console.log("onEditingFinished, isSearchTextInputEmpty = ", isSearchTextInputEmpty)
                return
            } else {
                // searchApp()
            }

            isSearchTextInputEmpty = false
            console.log("onEditingFinished, isSearchTextInputEmpty = ", isSearchTextInputEmpty)
        }
        function onActiveFocusChanged(activeFocus) {
            if (activeFocus) {
                if(searchTextInput.text === "Search") {
                    searchTextInput.text = "";
                }

                console.log("searchTextInput Gained focus");
            } else {
                console.log("searchTextInput Lost focus");
            }
        }
    }

    MarketplaceAsync {
        id: appAsync
        onClearAppInfoToAppList: () =>
        {
            appListModel.clear()
        }

        onAppendAppInfoToAppList: (name, author, rating, noofdownload, icon, isInstalled) => {
                                      console.log(name, author, rating, noofdownload, icon)
                                      if (name === "") {
                                          appListModel.append({name: "No Result.", author: "", rating: "", noofdownload: "", iconpath: "", is_installed: false})
                                      }
                                      else {
                                          appListModel.append({
                                                                  name: name,
                                                                  author: author,
                                                                  rating: rating+"*",
                                                                  noofdownload: noofdownload,
                                                                  iconpath: icon,
                                                                  is_installed: isInstalled
                                                              })
                                      }
                                  }

        onAppendLastRowToAppList:  (noOfApps) => {
                                       console.log("onAppendLastRowToAppList")
                                       numbeOfSearchedApps = noOfApps
                                       appListModel.append({name: "", author: "", rating: "", noofdownload: "", iconpath: ""})
                                       appListView.positionViewAtBeginning()
                                   }

        onHandleFailureAppInstallation: (type, msg) => {
                                            console.log("onHandleFailureAppInstallation")
                                            if (type === "alreadyinstalled") {
                                                handleFailureInstallAppMsg = msg
                                            }
                                            else if (type === "notAvailable") {
                                                handleFailureInstallAppMsg = msg
                                            }

                                            notSupportedFeaturePopup.open()
                                        }

        onClearMarketplaceNameList: () => {
            marketplace_comboBox_model.clear();
        }

        onAppendMarketplaceUrlList: (name) => {
            marketplace_comboBox_model.append({text: name});
            marketplace_comboBox.currentIndex = 0
        }

        onSetInstallServiceRunningStatus: (status) => {
            notifArea.visible = status
        }
    }

    Dialog {
        id: installAppPopup
        width: 500
        height: 400
        anchors.centerIn: parent
        modal: true

        onAccepted: {
            console.log("install onAccepted clicked")
            appAsync.installApp(installAppIndex)
            installAppPopup.close()
            appListView.currentIndex = -1
            notifArea.visible = true
        }
        onRejected: {
            console.log("install rejected clicked")
            installAppPopup.close()
            appListView.currentIndex = -1
        }

        contentItem: Rectangle {
            anchors.fill: parent
            width: 500
            height: 400
            color: "#676767"
            //            border.width: 1
            //            border.color: "white"

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
                    text: `Confirm install app <b>${activeAppName}</b>?`
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: "white"
                    font.pointSize: 16
                    wrapMode: Text.WordWrap
                }
            }

            Rectangle {
                id: btnCancel
                x: 40
                y: 300
                width: 160
                height: 80
                color: "#00000000"

                Text {
                    anchors.fill: parent
                    anchors.centerIn: parent
                    text: qsTr("Cancel")
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: "white"
                    font.pointSize: 18
                    font.bold: true
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        installAppPopup.rejected()
                    }
                }
            }

            Rectangle {
                id: btnAccept
                width: 160
                height: 80
                x: 300
                y: 300
                color: "#00000000"

                Text {
                    anchors.fill: parent
                    anchors.centerIn: parent
                    text: qsTr("Install")
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: "white"
                    font.pointSize: 18
                    font.bold: true
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        installAppPopup.accepted()
                    }
                }
            }
        }
    }

    Rectangle {
        id: searchAppRec
        x: 38
        y: 0
        width: parent.width
        height: parent.height
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
            y: 143
            width: parent.width - 100
            height: parent.height - 100
            clip: true

            function setActiveIndex(index) {
                appListView.forceActiveFocus()
                appListView.currentIndex = index
            }

            delegate: Item {
                id: appListViewItem
                x: 5
                width: appListView.width
                height: 90
                Row {
                    id: row1
                    spacing: 20
                    width: appListViewItem.width
                    height: 50

                    Image {
                        //                        id: imageId
                        source: iconpath
                        width: row1.height
                        height: row1.height
                    }

                    Rectangle {
                        x: row1.height + 30
                        height: appListViewItem.height
                        width: parent.width
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
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: (mouse) => {
                                   appListView.setActiveIndex(index)
                                   //                        appListView.forceActiveFocus()
                                   //                        appListView.currentIndex = index
                                   //                        var positionInPopup = mapToItem(content, mouse.x, mouse.y)
                                   //                        appListView.installPopupX = positionInPopup.x
                                   //                        appListView.installPopupY = positionInPopup.y - 50
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
                }
            }
        }

        ListView {
            id: appListMenu
            x: 0
            y: 76
            width: parent.width
            height: 50
            orientation: ListView.Horizontal
            clip: true
            currentIndex: -1
            spacing: 30
            highlight: Rectangle {
                color: "transparent"

                Rectangle {
                    id: borderLeft
                    width: parent.width
                    height: 1
                    anchors.bottom: parent.bottom
                    color: "#ebebeb"
                }
            }

            delegate: Item {
                id: item2
                x: 5
                width: 150
                height: 40

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    Text {
                        text: name
                        font.bold: true
                        font.pointSize: 14
                        color: "#90ebebeb"
                        font.family: "Arial"
                        horizontalAlignment: Text.AlignHCenter
                        anchors.centerIn: parent
                        wrapMode: Text.WordWrap
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
                    name: "Vehicle App"
                }
                ListElement {
                    name: "Vehicle Service"
                }
            }
        }

        Rectangle {
            id: search_area
            x: 0
            y: 8
            width: 349
            height: 50
            visible: true
            color: "#10ebebeb"
            radius: 10
            layer.enabled: true

            CustomBtn1 {
                id: searchAppButton
                x: 0
                y: 0
                width: 47
                height: 50
                btnIconSource: "../resource/search.png"
                iconWidth: 24
                iconHeight: 24
                colorDefault: "#00ececec"
                colorClicked: "#00ffffff"
                btn_border_color: "#00d5d7d7"
                btn_background_color: "#00ffffff"
                btn_color_overlay:"#60ebebeb"
                onClicked:
                {
                    searchApp()
                }
            }

            TextInput {
                id: searchTextInput
                x: 49
                width: 300
                height: 50
                text: "Search"
                anchors.verticalCenter: parent.verticalCenter
                font.letterSpacing: 1
                activeFocusOnPress: true
                font.pixelSize: 16
                horizontalAlignment: Text.AlignLeft
                verticalAlignment: Text.AlignVCenter
                font.styleName: "Regular"
                font.bold: true
                font.family: "Arial"
                color: "#60ebebeb"
                clip: true
            }
        }

        Rectangle {
            id: notifArea
            x: search_area.x + search_area.width + 20
            y: search_area.y
            width: 600
            height: 50
            visible: false
            color: "#10ebebeb"
            radius: 10
            layer.enabled: true

            BusyIndicator {
                id: busyIndicator
                running: true   // set to false to stop
                width: 35
                height: 35
                Material.accent: "#29B6F6"

                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 10  // optional spacing from left edge
            }

            Text {
                id: notifAreaText
                x: 49
                width: 500
                height: 50
                text: "Installation service is running. Please wait ..."
                anchors.verticalCenter: parent.verticalCenter
                font.letterSpacing: 1
                font.pixelSize: 16
                horizontalAlignment: Text.AlignLeft
                verticalAlignment: Text.AlignVCenter
                font.styleName: "Regular"
                font.bold: true
                font.family: "Arial"
                color: "#60ebebeb"
                clip: true
            }
        }
    }

    ComboBox {
        id: marketplace_comboBox
        x: parent.width - 300
        y: 0
        width: 250
        height: 40
        editable: false
        model: ListModel {
            id: marketplace_comboBox_model
        }

        // Delegate for dropdown items with custom background and text color
        delegate: ItemDelegate {
            width: marketplace_comboBox.width
            text: model.text
            font.family: "Arial"
            font.pixelSize: 18
            background: Rectangle {
                color: "#FAF3E0"               // Background color for each item
                border.color: "#A0A0A0"          // Optional border color for clarity
                radius: 4                        // Optional rounded corners
            }
            contentItem: Text {
                text: model.text
                color: "#1A1A2E"                 // Dark text color for visibility
                horizontalAlignment: Text.AlignLeft
                verticalAlignment: Text.AlignVCenter
                //elide: Text.ElideRight
            }
            onClicked: {
                marketplace_comboBox.currentIndex = index     // Update the selected index
                marketplace_comboBox.popup.close()            // Close dropdown on selection
                console.log("Selected index:", index)
                appAsync.setCurrentMarketPlaceIdx(index)
            }
        }

        // Custom main ComboBox background color and text styling
        background: Rectangle {
            color: "#10EBEBEB"                    // ComboBox background color
            radius: 5
        }

        contentItem: Text {
            text: marketplace_comboBox.currentText
            color: "#90EBEBEB"                    // Color of selected text
            font.family: "Arial"
            font.pixelSize: 18
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            width: marketplace_comboBox.width
        }
    }
    
    // ImgOverlay {
    //     id: icon_installed
    //     x: 56
    //     y: 50
    //     width: 24
    //     height: 24
    //     active_img_source: "../resource/search.png"
    //     default_img_source: "../resource/cloud-download-alt.png"
    //     default_color_overlay: "#95ebebeb"
    // }
    
    Item {
        id: __materialLibrary__
    }

}

/*##^##
Designer {
    D{i:0;formeditorZoom:0.66}
}
##^##*/
