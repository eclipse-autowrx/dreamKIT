// Copyright (c) 2025 Eclipse Foundation.
// 
// This program and the accompanying materials are made available under the
// terms of the MIT License which is available at
// https://opensource.org/licenses/MIT.
// 
// SPDX-License-Identifier: MIT
#ifndef CONTROLPAGE_H
#define CONTROLPAGE_H

#include <QObject>
#include <QTextStream>
#include <QFile>
#include "QString"
#include <QThread>
#include <QList>
#include <QFileSystemWatcher>
#include <QTimer>
#include <QMap>
#include "QVariant"

class ControlsAsync: public QObject
{
    Q_OBJECT
public:
    ControlsAsync();
    ~ControlsAsync();

    Q_INVOKABLE void init();
    // Lighting controls
    Q_INVOKABLE void qml_setApi_lightCtr_LowBeam(bool sts);
    Q_INVOKABLE void qml_setApi_lightCtr_HighBeam(bool sts);
    Q_INVOKABLE void qml_setApi_lightCtr_Hazard(bool sts);
    // Seat controls
    Q_INVOKABLE void qml_setApi_seat_driverSide_position(int position);
    // HVAC controls
    Q_INVOKABLE void qml_setApi_hvac_driverSide_FanSpeed(uint8_t speed);
    Q_INVOKABLE void qml_setApi_hvac_passengerSide_FanSpeed(uint8_t speed);

    // Connection management methods for QML
    Q_INVOKABLE bool isConnected() const;
    Q_INVOKABLE void forceReconnect();
    Q_INVOKABLE int getReconnectionAttempts() const;

    void vssSubsribeCallback(const std::string &updatePath, const std::string &updateValue); 

Q_SIGNALS:
    // Lighting signals
    void updateWidget_lightCtr_lowBeam(bool sts);
    void updateWidget_lightCtr_highBeam(bool sts);
    void updateWidget_lightCtr_Hazard(bool sts);
    // Seat signals
    void updateWidget_seat_driverSide_position(int position);
    // HVAC signals
    void updateWidget_hvac_driverSide_FanSpeed(int speed);
    void updateWidget_hvac_passengerSide_FanSpeed(int speed);

    // Connection state signals
    void connectionStateChanged(bool connected);
    void connectionError(const QString &errorMessage);
    void reconnectionAttempt(int attemptNumber);
    void subscriptionsRestored();

private:
    // Connection monitoring members
    QTimer *connectionMonitorTimer;
    bool lastKnownConnectionState;
    int reconnectionAttempts;
    bool subscriptionsActive;
    QTimer *reconnectionTimer;

    // Internal methods for connection management
    void checkConnectionState();
    void handleConnectionLost();
    void handleConnectionRestored();
    void reestablishSubscriptions();
    void enableAutoReconnection();
};

#endif // CONTROLPAGE_H