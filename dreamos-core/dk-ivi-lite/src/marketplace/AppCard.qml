// Copyright (c) 2025 Eclipse Foundation.
// 
// This program and the accompanying materials are made available under the
// terms of the MIT License which is available at
// https://opensource.org/licenses/MIT.
// 
// SPDX-License-Identifier: MIT
import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: card
    property var app
    property bool selected: false
    signal cardClicked()

    width: 200; height: 280

    Rectangle {
        anchors.fill: parent
        color: selected ? "#00D4AA15" : "#1A1A1A"
        radius: 20
        border.color: selected ? "#00D4AA" : "#2A2A2A"
        border.width: 1

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // App icon, name, author omitted for brevity…
            // badge, button, etc.

            Button {
                text: app.isInstalled ? qsTr("Installed") : qsTr("Install")
                background: Rectangle {
                    color: app.isInstalled ? "#00D4AA" : "#2196F3"
                    radius: 18
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: card.cardClicked()
    }
}
