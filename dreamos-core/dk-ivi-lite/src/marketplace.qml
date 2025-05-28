import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import "resource/customwidgets"
import MarketplaceAsync 1.0
//import Qt5Compat.GraphicalEffects

Rectangle {
    id: marketplace_page
    visible: true
    layer.enabled: true
    width: parent.width
    height: parent.height

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

            if (appListMenu.currentIndex === 0) {
                appAsync.searchAppFromStore("vehicle")
            }
            else if (appListMenu.currentIndex === 1) {
                appAsync.searchAppFromStore("vehicle-service")
            }
            else {
                appAsync.searchAppFromStore("XXXXXX")
            }
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

            let matchApp = appListModel.get(appListView.currentIndex)
            if(matchApp && !matchApp.is_installed) {
                activeAppName = matchApp.name
                installAppIndex = appListView.currentIndex
                if (notifArea.visible === false) {
                    installAppPopup.open()
                }
            }
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
            radius: 12

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
                color: "#40ffffff"
                radius: 8
                border.color: "#80ffffff"
                border.width: 1

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
                color: "#4CAF50"
                radius: 8

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

        GridView {
            id: appListView
            property int installPopupX: 0
            property int installPopupY: 0
            currentIndex: -1
            x: 20
            y: 143
            width: parent.width - 120
            height: parent.height - 160
            clip: true
            
            cellWidth: Math.floor((width) / Math.floor(width / 180))
            cellHeight: 260
            
            function setActiveIndex(index) {
                appListView.forceActiveFocus()
                appListView.currentIndex = index
            }

            delegate: Item {
                id: appListViewItem
                width: appListView.cellWidth
                height: appListView.cellHeight

                // App Card Container
                Rectangle {
                    id: appCard
                    width: appListView.cellWidth - 20
                    height: appListView.cellHeight - 20
                    anchors.centerIn: parent
                    color: appListView.currentIndex === index ? "#40007ACC" : "#25ffffff"
                    radius: 16
                    border.color: appListView.currentIndex === index ? "#007ACC" : "transparent"
                    border.width: 2

                    // Subtle shadow effect
                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: 3
                        anchors.leftMargin: 3
                        color: "#15000000"
                        radius: parent.radius
                        z: -1
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 10

                        // App Icon Container - Large and Square
                        Rectangle {
                            id: iconContainer
                            width: Math.min(parent.width - 8, 120)
                            height: width  // Square icon
                            radius: 20
                            color: "#ffffff"
                            border.color: "#e0e0e0"
                            border.width: 1
                            anchors.horizontalCenter: parent.horizontalCenter

                            // Icon background gradient
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "#ffffff" }
                                    GradientStop { position: 1.0; color: "#f8f8f8" }
                                }
                            }

                            Image {
                                id: appIcon
                                source: iconpath || "../resource/default-app-icon.png"
                                width: parent.width - 16
                                height: parent.height - 16
                                anchors.centerIn: parent
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                antialiasing: true

                                // Fallback for broken images
                                Rectangle {
                                    anchors.fill: parent
                                    visible: appIcon.status === Image.Error || iconpath === ""
                                    color: "#e3f2fd"
                                    radius: 16

                                    Text {
                                        anchors.centerIn: parent
                                        text: name.length > 0 ? name.charAt(0).toUpperCase() : "?"
                                        font.pixelSize: Math.min(36, parent.width / 3)
                                        font.bold: true
                                        color: "#1976d2"
                                    }
                                }
                            }

                            // Install status badge overlay
                            Rectangle {
                                visible: is_installed && name.length > 0
                                width: 24
                                height: 24
                                radius: 12
                                color: "#4CAF50"
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.topMargin: -8
                                anchors.rightMargin: -8
                                border.color: "#ffffff"
                                border.width: 2

                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    color: "white"
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                            }
                        }

                        // App Information Container
                        Item {
                            width: parent.width
                            height: 70 // Fixed height to prevent overlap
                            
                            Column {
                                anchors.fill: parent
                                spacing: 6
                                
                                // App Name - Single line with scrolling and tooltip
                                Item {
                                    width: parent.width
                                    height: 20
                                    clip: true
                                    
                                    Text {
                                        id: appNameId
                                        text: name
                                        font.bold: true
                                        font.pixelSize: Math.max(14, Math.min(16, parent.parent.parent.width / 10))
                                        color: "#ffffff"
                                        font.family: "Arial"
                                        height: parent.height
                                        verticalAlignment: Text.AlignVCenter
                                        
                                        // Check if text is longer than container
                                        property bool isTextTooLong: contentWidth > parent.width
                                        property real maxScroll: Math.max(0, contentWidth - parent.width + 10)
                                        
                                        // Position text
                                        x: {
                                            if (!isTextTooLong) {
                                                return (parent.width - contentWidth) / 2  // Center short text
                                            } else if (scrollAnimation.running) {
                                                return -scrollAnimation.progress * maxScroll  // Scroll long text
                                            } else {
                                                return 0  // Start position for long text
                                            }
                                        }
                                        
                                        SequentialAnimation {
                                            id: scrollAnimation
                                            running: appNameId.isTextTooLong && appCard.containsMouse
                                            loops: Animation.Infinite
                                            
                                            property real progress: 0
                                            
                                            PauseAnimation { duration: 1000 }  // Wait before scrolling
                                            
                                            NumberAnimation {
                                                target: scrollAnimation
                                                property: "progress"
                                                from: 0
                                                to: 1
                                                duration: Math.max(1200, appNameId.contentWidth * 12)
                                                easing.type: Easing.InOutQuad
                                            }
                                            
                                            PauseAnimation { duration: 600 }   // Pause at end
                                            
                                            NumberAnimation {
                                                target: scrollAnimation
                                                property: "progress"
                                                from: 1
                                                to: 0
                                                duration: Math.max(1200, appNameId.contentWidth * 12)
                                                easing.type: Easing.InOutQuad
                                            }
                                        }
                                    }
                                    
                                    // Tooltip for long text
                                    Rectangle {
                                        id: tooltip
                                        visible: appNameId.isTextTooLong && appCard.containsMouse && !scrollAnimation.running
                                        width: tooltipText.contentWidth + 16
                                        height: 30
                                        color: "#333333"
                                        radius: 8
                                        border.color: "#555555"
                                        border.width: 1
                                        
                                        // Position tooltip above the card
                                        anchors.bottom: parent.top
                                        anchors.bottomMargin: 8
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        
                                        // Keep tooltip within screen bounds
                                        x: Math.max(10 - parent.x, Math.min(x, appListView.width - width - 10 - parent.x))
                                        
                                        Text {
                                            id: tooltipText
                                            text: name
                                            color: "#ffffff"
                                            font.family: "Arial"
                                            font.pixelSize: 12
                                            anchors.centerIn: parent
                                        }
                                        
                                        // Tooltip arrow
                                        Rectangle {
                                            width: 8
                                            height: 8
                                            color: parent.color
                                            rotation: 45
                                            anchors.top: parent.bottom
                                            anchors.topMargin: -4
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                        
                                        // Fade in animation
                                        opacity: 0
                                        NumberAnimation on opacity {
                                            to: 1
                                            duration: 200
                                            running: tooltip.visible
                                        }
                                    }
                                }

                                // Author - Single line with ellipsis
                                Text {
                                    id: authorId
                                    text: author
                                    font.bold: false
                                    font.pixelSize: Math.max(10, Math.min(12, parent.parent.parent.width / 12))
                                    color: "#90ffffff"
                                    font.family: "Arial"
                                    width: parent.width
                                    height: 16
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }

                                // Rating and Downloads Row
                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 8
                                    
                                    // Rating with stars
                                    Row {
                                        spacing: 1
                                        visible: rating && rating !== "**" && rating !== "*"
                                        
                                        Repeater {
                                            model: 5
                                            Text {
                                                text: "★"
                                                color: index < Math.floor(parseFloat(rating)) ? "#FFD700" : "#30FFD700"
                                                font.pixelSize: Math.max(10, Math.min(12, appCard.width / 15))
                                            }
                                        }
                                    }

                                    // Download count
                                    Text {
                                        text: formatDownloadCount(noofdownload)
                                        font.pixelSize: Math.max(8, Math.min(10, appCard.width / 18))
                                        color: "#70ffffff"
                                        font.family: "Arial"
                                        visible: noofdownload && noofdownload !== "0"
                                    }
                                }
                            }
                        }

                        // Install Button - Always at bottom
                        Rectangle {
                            id: installButton
                            visible: name.length > 0
                            width: parent.width
                            height: Math.max(28, Math.min(36, parent.width / 5))
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: is_installed ? "#4CAF50" : "#2196F3"
                            radius: height / 2
                            
                            Text {
                                anchors.centerIn: parent
                                text: is_installed ? "Installed" : "Install"
                                color: "white"
                                font.family: "Arial"
                                font.pixelSize: Math.max(10, Math.min(12, parent.parent.width / 12))
                                font.bold: true
                            }

                            // Install button glow effect when not installed
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: "transparent"
                                border.color: "#40ffffff"
                                border.width: is_installed ? 0 : 1
                                visible: !is_installed
                            }
                        }
                    }

                    MouseArea {
                        id: cardMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        
                        property alias containsMouse: cardMouseArea.containsMouse
                        
                        onClicked: (mouse) => {
                                       appListView.setActiveIndex(index)
                                   }
                        
                        // Hover effect
                        onEntered: {
                            if (!is_installed && name.length > 0) {
                                appCard.color = "#35ffffff"
                                appCard.scale = 1.02
                            }
                            appCard.containsMouse = true
                        }
                        onExited: {
                            appCard.color = appListView.currentIndex === index ? "#40007ACC" : "#25ffffff"
                            appCard.scale = 1.0
                            appCard.containsMouse = false
                        }
                    }
                    
                    property alias containsMouse: cardMouseArea.containsMouse

                    // Smooth scaling animation for the card
                    Behavior on scale {
                        NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                    }
                }

                // Function to format download count
                function formatDownloadCount(count) {
                    var num = parseInt(count)
                    if (num >= 1000000) {
                        return (num / 1000000).toFixed(1) + "M"
                    } else if (num >= 1000) {
                        return (num / 1000).toFixed(1) + "K"
                    }
                    return count
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
                    height: 3
                    anchors.bottom: parent.bottom
                    color: "#2196F3"
                    radius: 1.5
                }
            }

            delegate: Item {
                id: item2
                x: 5
                width: 150
                height: 40

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    radius: 8
                    
                    Text {
                        text: name
                        font.bold: true
                        font.pointSize: 14
                        color: appListMenu.currentIndex === index ? "#2196F3" : "#90ebebeb"
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
            color: "#20ffffff"
            radius: 25
            border.color: "#40ffffff"
            border.width: 1

            CustomBtn1 {
                id: searchAppButton
                x: 5
                y: 5
                width: 40
                height: 40
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
                x: 55
                width: 280
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
                color: "#90ffffff"
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
            color: "#20ffffff"
            radius: 25
            border.color: "#4CAF50"
            border.width: 1

            BusyIndicator {
                id: busyIndicator
                running: true
                width: 35
                height: 35
                Material.accent: "#4CAF50"
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 10
            }

            Text {
                id: notifAreaText
                x: 55
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
                color: "#90ffffff"
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

        delegate: ItemDelegate {
            width: marketplace_comboBox.width
            text: model.text
            font.family: "Arial"
            font.pixelSize: 18
            background: Rectangle {
                color: "#FAF3E0"
                border.color: "#A0A0A0"
                radius: 4
            }
            contentItem: Text {
                text: model.text
                color: "#1A1A2E"
                horizontalAlignment: Text.AlignLeft
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: {
                marketplace_comboBox.currentIndex = index
                marketplace_comboBox.popup.close()
                console.log("Selected index:", index)
                appAsync.setCurrentMarketPlaceIdx(index)
            }
        }

        background: Rectangle {
            color: "#20ffffff"
            radius: 20
            border.color: "#40ffffff"
            border.width: 1
        }

        contentItem: Text {
            text: marketplace_comboBox.currentText
            color: "#90EBEBEB"
            font.family: "Arial"
            font.pixelSize: 18
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            width: marketplace_comboBox.width
        }
    }

    Item {
        id: __materialLibrary__
    }
}