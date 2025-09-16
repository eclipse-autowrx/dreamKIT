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
    property int iconWidth: 30
    property int iconHeight: 30
    property color btn_color_default: "#212121"
    property color btn_color_active: "#2c2c2c"
    property color text_color_default: "#999999"
    property color text_color_active: "#EBEBEB"
    property color border_color_default: "#2f2f2f"
    property color border_color_active: "#2c2c2c"
    property alias border_width: bkg.border.width
    property alias border_radius: bkg.radius
    property alias colorBtn : bkg.color
    property alias btnIconSource: iconBtn.source
    property alias btnText: textBtn.text
    property alias icon_center_offset: iconBtn.anchors.horizontalCenterOffset
    property alias text_center_offcet: textBtn.anchors.horizontalCenterOffset
    property alias icon_overlay_visible: iconOverlay.visible
    property bool isActive: false
    property int btn_index: 0

    layer.enabled: true
    hoverEnabled: false
    width: 175
    height: 90
    visible: true
    font.pixelSize: 8

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
            source: "../icons/lampon.png"
            anchors.verticalCenterOffset: -1
            anchors.horizontalCenterOffset: -28
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            width: iconWidth
            height: iconHeight
            fillMode: Image.PreserveAspectFit
            visible: false
            antialiasing: true
            mipmap: true
            smooth: true
            layer.smooth: true
            layer.mipmap: true
            layer.enabled: true
        }

        ColorOverlay{
            id: iconOverlay
            anchors.fill: iconBtn
            source: iconBtn
            anchors.verticalCenterOffset: 0
            anchors.rightMargin: 0
            anchors.bottomMargin: 0
            anchors.topMargin: 0
            anchors.leftMargin: 0
            anchors.verticalCenter: parent.verticalCenter
            visible: true
            width: iconWidth
            color: internal.dynamic_text_color
        }

        Text {
                id: textBtn
                text: "Auto"
                font.family: "Arial"
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 16
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.styleName: "Bold"
                anchors.verticalCenterOffset: 0
                anchors.horizontalCenterOffset: 12
                font.bold: true
                color: internal.dynamic_text_color
            }

}

/*##^##
Designer {
    D{i:0;formeditorZoom:3}
}
##^##*/
