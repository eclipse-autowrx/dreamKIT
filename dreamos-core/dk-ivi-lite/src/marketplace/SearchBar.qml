import QtQuick 2.15
import QtQuick.Controls 2.15
import "../resource/customwidgets"  // for CustomBtn1

Item {
    id: root
    signal searchRequested(string term)
    
    // text property and placeholder:
    property alias text: searchTextInput.text
    property string placeholderText: "Search apps and services..."

    // original fixed size
    implicitWidth: 380
    implicitHeight: 56

    // background rounded rect
    Rectangle {
        id: search_area
        width: parent.width
        height: parent.height
        color: "#1A1A1A"
        radius: 28
        border.color: "#2A2A2A"
        border.width: 1

        Row {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 12

            // custom search icon button
            CustomBtn1 {
                id: searchAppButton
                width: 40; height: 40
                btnIconSource: "../icons/search.png"
                iconWidth: 20; iconHeight: 20
                colorDefault: "#00D4AA20"
                colorClicked: "#00D4AA40"
                btn_border_color: "transparent"
                btn_background_color: "transparent"
                btn_color_overlay: "#00D4AA40"
                onClicked: root.searchRequested(searchTextInput.text)
            }

            // text input
            TextInput {
                id: searchTextInput
                width: parent.width - searchAppButton.width - 8*2 - 12
                height: 40
                anchors.verticalCenter: parent.verticalCenter
                // placeholderText: root.placeholderText
                font.pixelSize: 16
                font.family: "Segoe UI"
                horizontalAlignment: Text.AlignLeft
                verticalAlignment: Text.AlignVCenter
                color: activeFocus ? "#FFFFFF" : "#707070"
                clip: true

                onAccepted: root.searchRequested(text)
            }
        }
    }
}
