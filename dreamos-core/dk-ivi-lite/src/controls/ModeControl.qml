// Copyright (c) 2025 Eclipse Foundation.
// 
// This program and the accompanying materials are made available under the
// terms of the MIT License which is available at
// https://opensource.org/licenses/MIT.
// 
// SPDX-License-Identifier: MIT
import QtQuick 2.15
import QtQuick.Layouts 1.15

RowLayout {
    id: root
    property int maxMode: 7
    property int mode: 0

    property bool modeChangedOnPressed: false

    spacing: 12
    Layout.preferredWidth: 260
    Layout.preferredHeight: 50

    function buttonStyle(rect) {
        rect.radius = 10
        rect.border.width = 1
        rect.border.color = "#555555"
        rect.color = "#2e2e2e"
    }

    Rectangle {
        id: decBtn
        Layout.preferredWidth: 50
        Layout.preferredHeight: 50
        property bool pressed: false

        Text {
            anchors.centerIn: parent
            text: "-"
            color: "#70BCC9"
            font.family: "Segoe UI"
            font.weight: Font.DemiBold
            font.pixelSize: 24
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onPressed: decBtn.pressed = true
            onReleased: {
                decBtn.pressed = false
                if (root.mode > 0) {
                    root.mode--
                    modeChangedOnPressed = !modeChangedOnPressed
                }
            }
            onCanceled: decBtn.pressed = false
        }

        states: State {
            name: "pressed"
            when: decBtn.pressed
            PropertyChanges { target: decBtn; color: "#4a7a83" }
        }
        transitions: Transition {
            NumberAnimation { properties: "color"; duration: 150 }
        }

        Component.onCompleted: buttonStyle(decBtn)
    }

    Rectangle {
        id: modeDisplay
        Layout.preferredWidth: 50
        Layout.preferredHeight: 50
        radius: 10
        color: "#444444"
        border.color: "#555555"
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: root.mode
            color: "#70BCC9"
            font.family: "Segoe UI"
            font.weight: Font.DemiBold
            font.pixelSize: 20
        }
    }

    Rectangle {
        id: incBtn
        Layout.preferredWidth: 50
        Layout.preferredHeight: 50
        property bool pressed: false

        Text {
            anchors.centerIn: parent
            text: "+"
            color: "#70BCC9"
            font.family: "Segoe UI"
            font.weight: Font.DemiBold
            font.pixelSize: 24
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onPressed: incBtn.pressed = true
            onReleased: {
                incBtn.pressed = false
                if (root.mode < root.maxMode) {
                    root.mode++
                    modeChangedOnPressed = !modeChangedOnPressed
                }
            }
            onCanceled: incBtn.pressed = false
        }

        states: State {
            name: "pressed"
            when: incBtn.pressed
            PropertyChanges { target: incBtn; color: "#4a7a83" }
        }
        transitions: Transition {
            NumberAnimation { properties: "color"; duration: 150 }
        }

        Component.onCompleted: buttonStyle(incBtn)
    }
}
