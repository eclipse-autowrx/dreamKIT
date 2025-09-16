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

Button {
    id: button
    property int iconWidth: 50
    property int iconHeight: 50
    property color btn_color_default: "#212121"
    property color btn_color_active: "#1852ff"
    property color text_color_default: "#999999"
    property color text_color_active: "#EBEBEB"
    property color border_color_default: "#2f2f2f"
    property color border_color_active: "#1852ff"
    property alias border_width: bkg.border.width
    property alias border_color: bkg.border.color
    property alias border_radius: bkg.radius
    property alias colorBtn : bkg.color
    property alias btnIconSource: iconBtn.source
    property alias btnText: textBtn.text
    property bool isActive: false
    property int btn_index: 0

    layer.enabled: true
    hoverEnabled: false
    width: 175
    height: 175
    visible: true
    icon.color: "#ffffff"

    QtObject{
        id: internal
        property var dynamic_background_color: if(isActive){
                                       btn_color_active
                                   } else {
                                       btn_color_default
                                   }
        property var dynamic_text_color: if(isActive){
                                       text_color_active
                                   } else {
                                       text_color_default
                                   }
        property var dynamic_border_color: if(isActive){
                                       border_color_active
                                   } else {
                                       border_color_default
                                   }
    }

    background: Rectangle{
        id: bkg
        color: internal.dynamic_background_color
        border.color: internal.dynamic_border_color
        border.width: 2
        radius: 5
    }

        Image {
            id: iconBtn
            source: ""
            anchors.verticalCenterOffset: -15
            anchors.horizontalCenterOffset: 0
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            sourceSize.width: iconWidth
            sourceSize.height: iconHeight
            width: iconWidth
            height: iconHeight
            fillMode: Image.PreserveAspectFit
            visible: true
            antialiasing: true
            mipmap: true
            smooth: true
            layer.smooth: true
            layer.mipmap: true
            layer.enabled: true
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
            anchors.verticalCenter: parent.verticalCenter
            width: iconWidth
            color: internal.dynamic_text_color
        }

        Text {
                id: textBtn
                text: "Windows Lock"
                font.family: "Arial"
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.styleName: "Bold"
                anchors.verticalCenterOffset: 40
                anchors.horizontalCenterOffset: 0
                font.bold: true
                font.pixelSize: 15
                color: internal.dynamic_text_color
            }
}

/*##^##
Designer {
    D{i:0;formeditorZoom:2}
}
##^##*/
