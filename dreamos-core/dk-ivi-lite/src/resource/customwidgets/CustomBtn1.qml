// Copyright (c) 2025 Eclipse Foundation.
// 
// This program and the accompanying materials are made available under the
// terms of the MIT License which is available at
// https://opensource.org/licenses/MIT.
// 
// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Controls
//import Qt5Compat.GraphicalEffects // For ColorOverlay

Button {
    id: button
    property int iconWidth: 45
    property int iconHeight: 45
    property url btnIconSource: "../icons/car.png"
    property color colorDefault: "#212121"
    property color colorClicked: "#646868"
    property alias btn_icon_visible: iconBtn.visible
    property color btn_color_overlay: "#EBEBEB"
    property alias btn_background_color : background.color
    property alias btn_border_color : background.border.color
    property int btn_index: 0

    layer.enabled: true
    hoverEnabled: false
    width: 100
    height: 50
    visible: true
    icon.color: "#ffffff"
    font.bold: true
    font.family: "Arial"
    palette.buttonText: "#646868"

    Text {
            id: textBtn
            width: 61
            height: 23
            text: ""
            font.family: "Arial"
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.styleName: "Bold"
            anchors.verticalCenterOffset: 1
            anchors.horizontalCenterOffset: 1
            font.bold: true
            font.pixelSize: 20
        }
    background: Rectangle{
        id: background
        color: internal.dynamicColor
        border.color: "#D5D7D7"
        border.width: 2.5
        radius: 6

        Image {
            id: iconBtn
            source: btnIconSource
            layer.enabled: true
            layer.smooth: true
            layer.mipmap: true
            mipmap: true
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            width: iconWidth
            height: iconHeight
            fillMode: Image.PreserveAspectFit
            visible: true
            antialiasing: true
        }

        //ColorOverlay{
        //    x: 30
        //    anchors.fill: iconBtn
        //    source: iconBtn
        //    anchors.verticalCenterOffset: 0
        //    anchors.rightMargin: 0
        //    anchors.bottomMargin: 0
        //    anchors.topMargin: 0
        //    anchors.leftMargin: 0
        //    color: btn_color_overlay
        //    anchors.verticalCenter: parent.verticalCenter
        //    width: iconWidth
        //}
    }
}


/*##^##
Designer {
    D{i:0;formeditorZoom:4}
}
##^##*/
