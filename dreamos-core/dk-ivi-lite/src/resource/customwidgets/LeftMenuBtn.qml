// Copyright (c) 2025 Eclipse Foundation.
// 
// This program and the accompanying materials are made available under the
// terms of the MIT License which is available at
// https://opensource.org/licenses/MIT.
// 
// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects // For ColorOverlay

Button{
    id: btnLeftMenu
    text: qsTr("Controls")
    property url btnIconSource: "qrc:/icons/car.png"
    property color btn_color_default: "#212121"
    property color btn_color_active: "#2c2c2c"
    property color text_color_default: "#999999"
    property color text_color_active: "#EBEBEB"
    property int iconWidth: 22
    property int iconHeight: 22
    property bool isActive: false
    property int btn_index: 0

    layer.enabled: true
    hoverEnabled: false
    font.pixelSize: 20
    icon.color: "#ffffff"
    implicitWidth: 350
    implicitHeight: 60

    QtObject{
        id: internal
        property var dynamicColor1: if(isActive){
                                       btn_color_active
                                   } else {
                                       btn_color_default
                                   }
        property var dynamicColor2: if(isActive){
                                       text_color_active
                                   } else {
                                       text_color_default
                                   }
    }

    background:
        Rectangle{
        id: bgBtn
        color: internal.dynamicColor1
        radius: 12
    }

    contentItem: Item{
        anchors.fill: parent
        id: content
        Image {
            id: iconBtn
            y: 0
            source: btnIconSource
            mipmap: true
            smooth: true
            layer.smooth: true
            layer.mipmap: true
            layer.enabled: true
            anchors.verticalCenterOffset: 0
            anchors.leftMargin: 48
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            sourceSize.width: iconWidth
            sourceSize.height: iconHeight
            width: iconWidth
            height: iconHeight
            fillMode: Image.PreserveAspectFit
            visible: false
            antialiasing: true
        }

        ColorOverlay{
            x: 30
            anchors.fill: iconBtn
            source: iconBtn
            anchors.verticalCenterOffset: 0
            anchors.rightMargin: 0
            anchors.bottomMargin: 0
            anchors.topMargin: 0
            anchors.leftMargin: 0
            color: internal.dynamicColor2
            anchors.verticalCenter: parent.verticalCenter
            width: iconWidth
        }
        Text{
            y: 19
            text: btnLeftMenu.text
            anchors.left: parent.left
            anchors.right: parent.right
            font.letterSpacing: 1.5
            font.pixelSize: btnLeftMenu.font.pixelSize
            font.wordSpacing: 1.5
            font.styleName: "Bold"
            anchors.rightMargin: 162
            anchors.leftMargin: 87
            font.bold: true
            font.family: "Arial"
            color: internal.dynamicColor2
        }
    }
}

/*##^##
Designer {
    D{i:0;formeditorZoom:4}
}
##^##*/
