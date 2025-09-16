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

Item{
    id: customText
    property color text_color_default: "#EBEBEB"
    property color text_color_active: "#39EBEBEB"
    property alias text: text1.text
    property alias font_size: text1.font.pixelSize
    property bool isActive: false
    width: 40
    height: 40
    layer.enabled: true

    QtObject{
        id: internal
        property var dynamic_text_color: if(isActive){
                                                text_color_default
                                           } else {
                                                text_color_active
                                           }
    }
        Text {
            id: text1
            text: "Text"
            font.family: "Arial"
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            layer.smooth: true
            layer.mipmap: true
            font.styleName: "Bold"
            anchors.verticalCenterOffset: 1
            anchors.horizontalCenterOffset: 1
            font.bold: true
            font.pixelSize: 25
            color: internal.dynamic_text_color
        }
}





/*##^##
Designer {
    D{i:0;formeditorZoom:4}
}
##^##*/
