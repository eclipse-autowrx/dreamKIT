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
    property int iconWidth: 45
    property int iconHeight: 45
    property color btn_color_default: "#212121"
    property color btn_color_active: "#2c2c2c"
    property color text_color_default: "#999999"
    property color text_color_active: "#EBEBEB"
    property color border_color_default: "#2f2f2f"
    property color border_color_active: "#2c2c2c"
    property alias btnIconSource: iconBtn.source
    property alias border_width: bkg.border.width
    property alias border_radius: bkg.radius
    property bool isActive: false
    property alias btnText: textBtn.text
    property alias btnText_size: textBtn.font.pixelSize
    property int btn_index: 0

    hoverEnabled: false
    layer.enabled: true
    width: 100
    height: 50
    visible: true

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

    Text {
            id: textBtn
            text: "On"
            font.family: "Arial"
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.styleName: "Bold"
            font.bold: true
            font.pixelSize: 15
            color: internal.dynamic_text_color
        }

        Image {
            id: iconBtn
            source: ""
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
}

/*##^##
Designer {
    D{i:0;formeditorZoom:3}
}
##^##*/
