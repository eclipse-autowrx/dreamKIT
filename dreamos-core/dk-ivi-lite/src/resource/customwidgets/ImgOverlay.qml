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

Item {
    property int img_width: 100
    property int img_height: 100
    property color default_color_overlay: "#EBEBEB"
    property color active_color_overlay: "#222222"
    property url default_img_source: "../icons/bluetooth.png"
    property url active_img_source: "../icons/highbeam.png"
    property bool isActive: false

    layer.enabled: true
    width: 50
    height: 50
    QtObject{
        id: internal
        property var dynamic_img_source: if(isActive){
                                       active_img_source
                                   } else {
                                       default_img_source
                                   }
        property var dynamic_color_overlay: if(isActive){
                                       active_color_overlay
                                   } else {
                                       default_color_overlay
                                   }
    }

    Image {
        id: image
        width: img_width
        height: img_height
        anchors.fill: parent
        source: internal.dynamic_img_source
        mipmap: true
        smooth: true
        layer.smooth: true
        layer.mipmap: true
        layer.enabled: true
        fillMode: Image.PreserveAspectFit
        antialiasing: true
        visible: false
    }
    //ColorOverlay{
    //    anchors.fill: image
    //    source: image
    //    anchors.verticalCenterOffset: 0
    //    anchors.rightMargin: 0
    //    anchors.bottomMargin: 0
    //    anchors.topMargin: 0
    //    anchors.leftMargin: 0
    //    anchors.verticalCenter: parent.verticalCenter
    //    width: img_width
    //    height: img_height
    //    color: internal.dynamic_color_overlay
    //}
}

/*##^##
Designer {
    D{i:0;formeditorZoom:16}
}
##^##*/
