// Copyright (c) 2025 Eclipse Foundation.
// 
// This program and the accompanying materials are made available under the
// terms of the MIT License which is available at
// https://opensource.org/licenses/MIT.
// 
// SPDX-License-Identifier: MIT
import QtQuick 2.15

Rectangle {
    id: btn
    width: 180
    height: 60
    radius: 10
    property bool checked: false
    property bool toggled: false
    property alias text: label.text
    property bool hovered: false

    // Background gradient colors change based on checked and hovered states
    gradient: Gradient {
        GradientStop { position: 0.0; color: btn.checked ? "#3A8D99CC" : (btn.hovered ? "#3a3a3a" : "#2E2E2E") }
        GradientStop { position: 1.0; color: btn.checked ? "#1F5F66CC" : (btn.hovered ? "#303030" : "#222222") }
    }

    // Border color changes based on checked
    border.color: btn.checked ? "#70BCC9" : "#555555"
    border.width: 1

    Text {
        id: label
        anchors.fill: parent
        anchors.margins: 8
        text: btn.text
        color: btn.checked ? "#E0F7FA" : "#AAAAAA"
        font.family: "Segoe UI"
        font.weight: Font.DemiBold
        font.pixelSize: 16
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        wrapMode: Text.NoWrap
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            btn.checked = !btn.checked
            btn.toggled = !btn.toggled
        }
        onEntered: btn.hovered = true
        onExited: btn.hovered = false
    }
}
