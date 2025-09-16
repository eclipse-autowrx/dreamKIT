# Copyright (c) 2025 Eclipse Foundation.
# 
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT
cmake_minimum_required(VERSION 3.16)

project(untitled2 VERSION 0.1 LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_CXX_FLAGS "-fpermissive")

find_package(Qt6 6.2 REQUIRED COMPONENTS Quick Concurrent)


qt_add_executable(dk_ivi
    main/main.cpp
    controls/controls.cpp
    digitalauto/digitalauto.cpp
    marketplace/marketplace.cpp
    installedservices/installedservices.cpp
    installedservices/installedcheckthread.cpp
    installedvapps/installedvapps.cpp
    platform/async/asyncjob.cpp
    platform/data/datamanager.cpp
    platform/data/fetching.cpp
    platform/data/jsonstorage.cpp
    platform/data/appserializer.cpp
    platform/integrations/kubernetes/manifestbuilder.cpp
    platform/integrations/kubernetes/installer.cpp
    platform/integrations/kubernetes/jobmanager.cpp
    platform/integrations/vehicle-api/vapiclient.cpp
    platform/monitoring/wlanmonitor.cpp
    platform/monitoring/autorestartmanager.cpp
    platform/notifications/notificationmanager.cpp
)

qt_add_qml_module(dk_ivi
    URI untitled2
    VERSION 1.0
    QML_FILES
        main/main.qml
        main/settings.qml
        controls/controls.qml
        controls/ModeControl.qml
        controls/ToggleButton.qml
        digitalauto/digitalauto.qml
        marketplace/AppCard.qml
        marketplace/AppGrid.qml
        marketplace/CategoryBar.qml
        marketplace/ConfirmDialog.qml
        marketplace/marketplace.qml
        marketplace/SearchBar.qml
        installedservices/installedservices.qml
        installedvapps/installedvapps.qml
        platform/notifications/notificationoverlay.qml
        resource/customwidgets/CustomBtn1.qml
        resource/customwidgets/CustomBtn2.qml
        resource/customwidgets/IconBtn1.qml
        resource/customwidgets/IconBtn2.qml
        resource/customwidgets/ImgOverlay.qml
        resource/customwidgets/LeftMenuBtn.qml
        resource/customwidgets/TextOverlay.qml
        resource/customwidgets/RowOfBtn.qml
        resource/customwidgets/ValueStepper.qml
    RESOURCES
        resource/icons/bgswlogo.png
        resource/icons/bgswlogo_.png
        resource/icons/boschlogo.jpeg
        resource/icons/boschlogo.png
        resource/icons/bot.png
        resource/icons/cloud-download-alt.png
        resource/icons/digitalautologo.jpeg
        resource/icons/digitalautologo.png
        resource/icons/editicon3.png
        resource/icons/etaslogo.jpeg
        resource/icons/etaslogo.jpg
        resource/icons/logo1_1.png
        resource/icons/logo1.png
        resource/icons/logo2.png
        resource/icons/logo3.png
        resource/icons/logo4.png
        resource/icons/search.png
        resource/icons/sec_car_attack.webp
        resource/icons/sec_car_is_secure.mp3
        resource/icons/sec_car_safe.webp
        resource/icons/sec_car_under_attack.png
        resource/icons/sec_security_processing.gif
        resource/icons/sec_under_attack.mp3
        resource/icons/trashbin2.png
        resource/icons/car.png
        resource/icons/seat.png
)

set_target_properties(dk_ivi PROPERTIES
    MACOSX_BUNDLE_GUI_IDENTIFIER my.example.com
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

# Declare the option with OFF as the default.
message(STATUS "CMAKE_SYSTEM_PROCESSOR: ${CMAKE_SYSTEM_PROCESSOR}")
if(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64")
    message(STATUS "Detected architecture: amd64 (x86_64)")
    set(TARGET_ARCH "amd64")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64")
    message(STATUS "Detected architecture: arm64 (aarch64)")
    set(TARGET_ARCH "arm64")
else()
    message(STATUS "Detected architecture: ${CMAKE_SYSTEM_PROCESSOR}")
endif()

# Check NATIVE_TESTING value.
if(NATIVE_TESTING)
    set(TARGET_ARCH "sk_3.8")
endif()

message(STATUS "TARGET_ARCH: ${TARGET_ARCH}")


# message(STATUS "CMAKE_CURRENT_SOURCE_DIR: ${CMAKE_CURRENT_SOURCE_DIR}")
# Create an imported target for libKuksaClient.so
add_library(KuksaClient SHARED IMPORTED)
# Replace the path below with the actual location of your libKuksaClient.so file.
set_target_properties(KuksaClient PROPERTIES 
    IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/library/target/${TARGET_ARCH}/libKuksaClient.so"
)

target_link_libraries(dk_ivi
    PRIVATE Qt6::Quick Qt6::Concurrent KuksaClient
)

install(TARGETS dk_ivi
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
