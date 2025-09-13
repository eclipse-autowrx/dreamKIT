import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import MyApp 1.0
import "."

Page {
    Layout.fillWidth: true
    Layout.fillHeight: true

    MarketplaceViewModel { id: vm }

    background: Rectangle {
        color: "#1A1A1A"
        radius: 16
        border.color: "#2A2A2A"
        border.width: 1
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        // SEARCH
        SearchBar {
            Layout.alignment: Qt.AlignHCenter
            placeholderText: qsTr("Search apps and services…")
            onSearchRequested: vm.search(text)
        }

        // CATEGORY TABS
        CategoryBar {
            Layout.fillWidth: true
            onIndexChanged: vm.search(currentCategory)
        }

        // GRID
        AppGrid {
            Layout.fillWidth: true
            Layout.fillHeight: true
            modelData: vm.appsModel
            onAppSelected: function(idx) { vm.appSelected(idx) }
        }
    }

    ConfirmDialog {
        dialogTitle:   qsTr("Confirm Install")
        dialogMessage: qsTr("Install “%1”?").arg(vm.pendingAppName)
        visible:       vm.installPending
        onConfirmed:   vm.confirmInstall()
        onCanceled:    vm.cancelInstall()
    }
}
