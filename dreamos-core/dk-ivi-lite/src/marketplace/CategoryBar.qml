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
    id: root
    implicitHeight: 60
    implicitWidth: parent ? parent.width : 360

    // PUBLIC API
    readonly property int    currentIndex    : listView.currentIndex
    readonly property string currentCategory : listView.model.get(currentIndex).categoryKey
    signal                   indexChanged(int newIndex)

    ListView {
        id: listView
        anchors.fill: parent
        orientation: ListView.Horizontal
        spacing: 24

        // start on tab 0
        currentIndex: 0
        highlightFollowsCurrentItem: true

        // two fixed tabs
        model: ListModel {
            ListElement { displayName: "Vehicle App";      categoryKey: "vehicle" }
            ListElement { displayName: "Vehicle Service";  categoryKey: "vehicle-service" }
        }

        // This “highlight” rectangle is our outline
        highlight: Rectangle {
            id: outline
            // snap to the currentItem’s geometry
            width:  currentItem ? currentItem.width  : 0
            height: currentItem ? currentItem.height : 0
            x:      currentItem ? currentItem.x      : 0
            y:      currentItem ? currentItem.y      : 0

            color: "transparent"
            border.width: 1
            border.color: "#00D4AA"
            radius: 4

            // animate moves & resizes
            Behavior on x     { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }

            // animate color changes (in case you want to tween to another color later)
            Behavior on border.color { ColorAnimation { duration: 200 } }
        }

        delegate: Item {
            id: del
            // size to the text width + a bit of padding
            width: text.paintedWidth + 24
            height: listView.height

            Text {
                id: text
                text: displayName
                anchors.centerIn: parent
                font.family: "Segoe UI"
                font.pointSize: 16
                font.weight: listView.currentIndex === index ? Font.Medium : Font.Normal
                color:      listView.currentIndex === index ? "#00D4AA" : "#B0B0B0"
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    listView.currentIndex = index
                    root.indexChanged(index)
                }
            }
        }

        // fire once on startup so your page can kick off vm.search(...)
        Component.onCompleted: root.indexChanged(currentIndex)
    }
}
