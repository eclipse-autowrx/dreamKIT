// Copyright (c) 2025 Eclipse Foundation.
// 
// This program and the accompanying materials are made available under the
// terms of the MIT License which is available at
// https://opensource.org/licenses/MIT.
// 
// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

RowLayout {
    id: root
    property var listData: ["Item 1", "Item 2", "Item 3"]
    property var listIcon: ["", "", ""]
    property int btnMinWidth: 60
    property int fontSizeNormal: 14
    property int fontSizeSmall: 11
    property int activeIndex: 0
    property string activeColor: "brown"
    property string color: "red"
    property string txtColor: "white"
    property string displayMode: "text" // text, icon-text, icon

    layer.enabled: true
    spacing: 0
    property int iconMargin: 10

    signal activeIndexChange(int newIndex)

    Repeater {
        model: listData
        Rectangle {
            id: btn
            width: Math.max(root.btnMinWidth, (root.width-root.spacing*(listData.length-1))/listData.length)
            height: root.height
            color: root.activeIndex===index?root.activeColor:root.color
            clip: true


            // mode Text only
            Text  {
                visible: root.displayMode==="text"
                text: root.listData&&root.listData.length>index?root.listData[index]:''
                anchors.verticalCenter: parent.verticalCenter
                anchors.fill: btn
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                anchors.horizontalCenter: parent.horizontalCenter
                color: root.txtColor
                font.pointSize: root.fontSizeNormal
            }

            // mode Icon only
            Image {
                visible: root.displayMode==="icon"
                anchors.fill: btn
                anchors.margins: root.iconMargin
                fillMode: Image.PreserveAspectFit
                source: root.listIcon&&root.listIcon.length>index?root.listIcon[index]:''
            }

            // mode Icon - Text
            Image {
                visible: root.displayMode==="icon-text"
                anchors.top: parent.top
                anchors.bottom: smallText.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: root.iconMargin
                fillMode: Image.PreserveAspectFit
                source: root.listIcon&&root.listIcon.length>index?root.listIcon[index]:''
            }
            Text  {
                id:smallText
                visible: root.displayMode==="icon-text"
                text: root.listData&&root.listData.length>index?root.listData[index]:''
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                height: root.fontSizeSmall + 8
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                color: root.txtColor
                font.pointSize: root.fontSizeSmall
            }


            MouseArea {
                anchors.fill: btn
                onClicked: {
                    if(root.activeIndex!==model.index) {
                        root.activeIndexChange(model.index)
                    }
                }
            }
        }
    }
}
