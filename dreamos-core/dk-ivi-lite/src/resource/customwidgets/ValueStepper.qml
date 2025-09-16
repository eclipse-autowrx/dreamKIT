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
import QtQuick.Window
import "../controls"

Item {
    id: root
    width: 190
    height: 60

    property real currentValue: 2
    property real stepValue: 1
    property real maxValue: 5
    property real minValue: 0
    property bool showText: false
    property alias icon: icon_btn.btnIconSource

    signal valueChange(real newValue)

    CustomBtn1 {
        id: decrease_btn
        width: 30
        height: 30
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 0
        iconWidth: 25
        iconHeight: 25
        btn_color_overlay: "#ffffff"
        btnIconSource: "../icons/angle-small-left.png"
        btn_border_color: "#00d5d7d7"
        btn_background_color: "#00ffffff"
        onClicked: {
            //console.log("decrease_btn clicked")
            let newValue = root.currentValue - root.stepValue
            //console.log(newValue)
            newValue = Math.max(newValue, root.minValue)
            newValue = Math.min(newValue, root.maxValue)
            //console.log(newValue)
            root.valueChange(newValue)
        }
    }
    
    CustomBtn1 {
        id: increase_btn
        x: 135
        width: 30
        height: 30
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 0
        antialiasing: false
        iconHeight: 25
        iconWidth: 25
        btn_color_overlay: "#ffffff"
        btnIconSource: "../icons/angle-small-right.png"
        btn_border_color: "#00d5d7d7"
        btn_background_color: "#00ffffff"
        onClicked: {
            //console.log("increase_btn clicked")
            let newValue = root.currentValue + stepValue
            //console.log(newValue)
            newValue = Math.max(newValue, root.minValue)
            newValue = Math.min(newValue, root.maxValue)
            //console.log(newValue)
            root.valueChange(newValue)
        }
    }

    CustomBtn1 {
        id: icon_btn
        visible: !showText
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: decrease_btn.right
        anchors.right: increase_btn.left
        anchors.rightMargin: 0
        anchors.leftMargin: 0
        height: 53
        antialiasing: false
        iconHeight: 35
        iconWidth: 35
        btn_color_overlay: "#ffffff"
        btnIconSource: "../icons/mute.png"
        btn_border_color: "#00d5d7d7"
        btn_background_color: "#00ffffff"
    }

    Text {
        id: lblValue
        visible: showText
        x: 93
        anchors.left: decrease_btn.right
        anchors.right: increase_btn.left
        font.pixelSize: 47
        height: 53
        antialiasing: false
        color:'white'
        text: currentValue
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        anchors.rightMargin: 0
        anchors.leftMargin: 0
        font.family: "Arial"
        font.bold: false
        layer.enabled: true
    }

}
