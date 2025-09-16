// Copyright (c) 2025 Eclipse Foundation.
// 
// This program and the accompanying materials are made available under the
// terms of the MIT License which is available at
// https://opensource.org/licenses/MIT.
// 
// SPDX-License-Identifier: MIT
import QtQuick 2.15
import QtQuick.Controls 2.15

Dialog {
    id: dlg
    // Public API
    property string dialogTitle   : ""
    property string dialogMessage : ""
    signal           confirmed()
    signal           canceled()

    modal: true
    width: Math.min(380, parent.width * 0.9)
    height: Math.min(260, parent.height * 0.7)
    anchors.centerIn: parent

    // Outer + inner borders
    background: Rectangle {
        color: "#1A1A1A"
        radius: 20
        border.width: 2
        border.color: "#FF444460"
    }

    // Main content
    contentItem: Column {
        anchors.fill: parent
        anchors.margins: 40
        spacing: 32

        // Title
        Text {
            text: dlg.dialogTitle
            width: parent.width
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            color: "#FFFFFF"
            font.family: "Segoe UI"
            font.pixelSize: 18
            font.weight: Font.Medium
            lineHeight: 1.4
        }

        // Message text
        Text {
            text: dlg.dialogMessage
            width: parent.width
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            color: "#B0B0B0"
            font.family: "Segoe UI"
            font.pixelSize: 14
            font.weight: Font.Medium
            lineHeight: 1.4
        }

        // Buttons row
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 20

            // Cancel
            Button {
                text: qsTr("Cancel")
                width: 120; height: 48
                onClicked: {
                    dlg.canceled()
                    dlg.close()
                }
                background: Rectangle {
                    color: parent.hovered ? "#353535" : "#2A2A2A"
                    radius: 24
                    border.width: 1
                    border.color: parent.hovered ? "#606060" : "#404040"

                    Behavior on color        { ColorAnimation { duration: 200 } }
                    Behavior on border.color { ColorAnimation { duration: 200 } }
                }
                contentItem: Text {
                    text: parent.text
                    color: "#FFFFFF"
                    font.family: "Segoe UI"; font.pixelSize: 16; font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment:   Text.AlignVCenter
                }
            }

            // Confirm/Install
            Button {
                text: qsTr("Install")
                width: 120; height: 48
                onClicked: {
                    dlg.confirmed()
                    dlg.close()
                }
                background: Rectangle {
                    color: parent.hovered ? "#FF6666" : "#FF4444"
                    radius: 24
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
                contentItem: Text {
                    text: parent.text
                    color: "#FFFFFF"
                    font.family: "Segoe UI"; font.pixelSize: 16; font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment:   Text.AlignVCenter
                }
            }
        }
    }
}
