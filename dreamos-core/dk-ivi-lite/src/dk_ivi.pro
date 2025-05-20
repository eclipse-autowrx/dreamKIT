QT += quick core gui network
QT += widgets
#QT += virtualkeyboard
CONFIG += c++11
CONFIG += console
CONFIG += no_keywords

QMAKE_CXXFLAGS += -fpermissive

# The following define makes your compiler Q_EMIT warnings if you use
# any Qt feature that has been marked deprecated (the exact warnings
# depend on your compiler). Refer to the documentation for the
# deprecated API to know how to port your code away from it.
DEFINES += QT_DEPRECATED_WARNINGS

# You can also make your code fail to compile if it uses deprecated APIs.
# In order to do so, uncomment the following line.
# You can also select to disable deprecated APIs only up to a certain version of Qt.
#DEFINES += QT_DISABLE_DEPRECATED_BEFORE=0x060000    # disables all the APIs deprecated before Qt 6.0.0

SOURCES += \
    main/main.cpp \
    controls/controls.cpp \
    digitalauto/digitalauto.cpp \
    marketplace/marketplace.cpp \
    marketplace/fetching.cpp \
    installedservices/installedservices.cpp \
    installedservices/unsafeparamcheck.cpp \
    installedvapps/installedvapps.cpp \
    library/vapiclient/vapiclient.cpp

RESOURCES += main/main.qml \
    controls/controls.qml \
    controls/ModeControl.qml \
    controls/ToggleButton.qml \
    digitalauto/digitalauto.qml \
    marketplace/marketplace.qml \
    installedservices/installedservices.qml \
    installedvapps/installedvapps.qml \
    resource/customwidgets/CustomBtn1.qml \
    resource/customwidgets/CustomBtn2.qml \
    resource/customwidgets/IconBtn1.qml \
    resource/customwidgets/IconBtn2.qml \
    resource/customwidgets/ImgOverlay.qml \
    resource/customwidgets/LeftMenuBtn.qml \
    resource/customwidgets/TextOverlay.qml \
    resource/customwidgets/RowOfBtn.qml \
    resource/customwidgets/ValueStepper.qml \
    resource/icons/bgswlogo.png \
    resource/icons/bgswlogo_.png \
    resource/icons/boschlogo.jpeg \
    resource/icons/boschlogo.png \
    resource/icons/bot.png \
    resource/icons/cloud-download-alt.png \
    resource/icons/digitalautologo.jpeg \
    resource/icons/digitalautologo.png \
    resource/icons/editicon3.png \
    resource/icons/etaslogo.jpeg \
    resource/icons/etaslogo.jpg \
    resource/icons/logo1_1.png \
    resource/icons/logo1.png \
    resource/icons/logo2.png \
    resource/icons/logo3.png \
    resource/icons/logo4.png \
    resource/icons/search.png \
    resource/icons/sec_car_attack.webp \
    resource/icons/sec_car_is_secure.mp3 \
    resource/icons/sec_car_safe.webp \
    resource/icons/sec_car_under_attack.png \
    resource/icons/sec_security_processing.gif \
    resource/icons/sec_under_attack.mp3 \
    resource/icons/trashbin2.png \

# Additional import path used to resolve QML modules in Qt Creator's code model
QML_IMPORT_PATH =

# Additional import path used to resolve QML modules just for Qt Quick Designer
QML_DESIGNER_IMPORT_PATH =

# Default rules for deployment.
qnx: target.path = /tmp/$${TARGET}/bin
else: unix:!android: target.path = /opt/$${TARGET}/bin
!isEmpty(target.path): INSTALLS += target

HEADERS += \
    controls/controls.hpp \
    digitalauto/digitalauto.hpp \
    marketplace/marketplace.hpp \
    marketplace/fetching.hpp \
    installedservices/installedservices.hpp \
    installedservices/unsafeparamcheck.hpp \
    installedvapps/installedvapps.hpp \
    library/vapiclient/vapiclient.hpp \

INCLUDEPATH += library/vapiclient


# this is for Orin
# LIBS += -lrt
# LIBS += -L$$PWD/library/target/sk_3.8/ -lKuksaClient -lrt
# Set base path
LIB_BASE = $$PWD/library/target

# Detect architecture and set the subdirectory
contains(QT_ARCH, arm64) | contains(QT_ARCH, aarch64) {
    LIB_DIR = $$LIB_BASE/arm64
} else:contains(QT_ARCH, x86_64) {
    LIB_DIR = $$LIB_BASE/amd64
} else {
    error("Unsupported architecture: $$QT_ARCH")
}

INCLUDEPATH += $$PWD/../library/include
LIBS += -L$$LIB_DIR -lKuksaClient -lrt


CONFIG += SOCKET_IT_CLIENT_CONFIG

SOCKET_IT_CLIENT_CONFIG {
    DEFINES += USING_SOCKET_IO_CLIENT
    LIBS += -lssl -lcrypto
}


# this is for NUC
#LIBS += -lrt

