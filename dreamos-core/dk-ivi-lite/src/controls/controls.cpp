// Copyright (c) 2025 Eclipse Foundation.
// 
// This program and the accompanying materials are made available under the
// terms of the MIT License which is available at
// https://opensource.org/licenses/MIT.
// 
// SPDX-License-Identifier: MIT
#include "controls.hpp"
#include <QThread>
#include <QDebug>
#include <QMetaObject>
#include <QString>

#include "../platform/integrations/vehicle-api/vapiclient.hpp"

//------------------------------------------------------------------------------
// Vehicle API keys
//
// These inline constants define the available keys for the vehicle Software Update API.
// Using these constants throughout your code enables code completion and minimizes errors.
//------------------------------------------------------------------------------
QString DK_VSS_VER = "VSS_4.0";
namespace VehicleAPI {
  std::string V_Bo_Lights_Beam_Low_IsOn               = "Vehicle.Body.Lights.Beam.Low.IsOn";
  std::string V_Bo_Lights_Beam_High_IsOn              = "Vehicle.Body.Lights.Beam.High.IsOn";
  std::string V_Bo_Lights_Hazard_IsSignaling          = "Vehicle.Body.Lights.Hazard.IsSignaling";
  std::string V_Ca_HVAC_Station_R1_Driver_FanSpeed    = "Vehicle.Cabin.HVAC.Station.Row1.Passenger.FanSpeed";
  std::string V_Ca_HVAC_Station_R1_Passenger_FanSpeed = "Vehicle.Cabin.HVAC.Station.Row1.Driver.FanSpeed";
  std::string V_Ca_Seat_R1_DriverSide_Position        = "Vehicle.Cabin.Seat.Row1.DriverSide.Position";
}

//------------------------------------------------------------------------------
ControlsAsync::ControlsAsync()
{
    qDebug() << __func__ << __LINE__ << "  constructing ControlsAsync";

    // Initialize the VAPI client instance.
    DK_VSS_VER = qgetenv("DK_VSS_VER");

    if(DK_VSS_VER == "VSS_3.0") {
      VehicleAPI::V_Bo_Lights_Beam_Low_IsOn               = "Vehicle.Body.Lights.IsLowBeamOn";
      VehicleAPI::V_Bo_Lights_Beam_High_IsOn              = "Vehicle.Body.Lights.IsHighBeamOn";
      VehicleAPI::V_Bo_Lights_Hazard_IsSignaling          = "Vehicle.Body.Lights.IsHazardOn";
      VehicleAPI::V_Ca_HVAC_Station_R1_Driver_FanSpeed    = "Vehicle.Cabin.HVAC.Station.Row1.Left.FanSpeed";
      VehicleAPI::V_Ca_HVAC_Station_R1_Passenger_FanSpeed = "Vehicle.Cabin.HVAC.Station.Row1.Right.FanSpeed";
      VehicleAPI::V_Ca_Seat_R1_DriverSide_Position        = "Vehicle.Cabin.Seat.Row1.Pos1.Position";
    }

    // 1) Build the list of signal paths we want to subscribe to:
    std::vector<std::string> signalPaths = {
        VehicleAPI::V_Bo_Lights_Beam_Low_IsOn,
        VehicleAPI::V_Bo_Lights_Beam_High_IsOn,
        VehicleAPI::V_Bo_Lights_Hazard_IsSignaling,
        VehicleAPI::V_Ca_Seat_R1_DriverSide_Position,
        VehicleAPI::V_Ca_HVAC_Station_R1_Driver_FanSpeed,
        VehicleAPI::V_Ca_HVAC_Station_R1_Passenger_FanSpeed
    };

    // 2) Connect once (with those paths so the client can internally
    //    store them if it needs them for subscribeAll).
    if (!VAPI_CLIENT.connectToServer(DK_VAPI_DATABROKER, signalPaths)) {
        qCritical() << "Could not connect to VAPI server:" << DK_VAPI_DATABROKER;
        return;
    }

    // 3) Now subscribe to *target*‐value updates.
    //    Our SubscribeCallback signature is:
    //      (const std::string &path,
    //       const std::string &value,
    //       const int         &field)
    //
    //    We ignore the ‘field’ here (always target).  Because
    //    subscribeTarget() will spawn its own thread, we must
    //    marshal back to the Qt main thread:
    VAPI_CLIENT.subscribeTarget(
      DK_VAPI_DATABROKER,
      signalPaths,
      [this](const std::string &path,
             const std::string &value,
             const int         &field) {
        Q_UNUSED(field);
        // invoke our member function in the GUI thread:
        QMetaObject::invokeMethod(
          this,
          [this, path, value]() {
            this->vssSubsribeCallback(path, value);
          },
          Qt::QueuedConnection
        );
      }
    );
    VAPI_CLIENT.subscribeCurrent(
      DK_VAPI_DATABROKER,
      signalPaths,
      [this](const std::string &path,
             const std::string &value,
             const int         &field) {
        Q_UNUSED(field);
        // invoke our member function in the GUI thread:
        QMetaObject::invokeMethod(
          this,
          [this, path, value]() {
            this->vssSubsribeCallback(path, value);
          },
          Qt::QueuedConnection
        );
      }
    );
}

void ControlsAsync::init()
{
    // Give the subscription threads a moment to spin up.
    QThread::msleep(300);

    // Use the templated getTargetValueAs<T>() so we don't
    // have to do manual stoi/string compares:
    bool b     = false;
    int  i_val = 0;

    if (VAPI_CLIENT.getTargetValueAs<bool>(
          DK_VAPI_DATABROKER,
          VehicleAPI::V_Bo_Lights_Beam_Low_IsOn,
          b)) {
      updateWidget_lightCtr_lowBeam(b);
    }
    
    if (VAPI_CLIENT.getTargetValueAs<bool>(
          DK_VAPI_DATABROKER,
          VehicleAPI::V_Bo_Lights_Beam_High_IsOn,
          b)) {
      updateWidget_lightCtr_highBeam(b);
    }

    if (VAPI_CLIENT.getTargetValueAs<bool>(
          DK_VAPI_DATABROKER,
          VehicleAPI::V_Bo_Lights_Hazard_IsSignaling,
          b)) {
      updateWidget_lightCtr_Hazard(b);
    }

    if (VAPI_CLIENT.getTargetValueAs<int>(
          DK_VAPI_DATABROKER,
          VehicleAPI::V_Ca_Seat_R1_DriverSide_Position,
          i_val)) {
      updateWidget_seat_driverSide_position(i_val);
    }

    if (VAPI_CLIENT.getTargetValueAs<int>(
          DK_VAPI_DATABROKER,
          VehicleAPI::V_Ca_HVAC_Station_R1_Driver_FanSpeed,
          i_val)) {
      int speed = (i_val)/10;
      updateWidget_hvac_driverSide_FanSpeed(speed);
    }

    if (VAPI_CLIENT.getTargetValueAs<int>(
          DK_VAPI_DATABROKER,
          VehicleAPI::V_Ca_HVAC_Station_R1_Passenger_FanSpeed,
          i_val)) {
      int speed = (i_val)/10;
      updateWidget_hvac_passengerSide_FanSpeed(speed);
    }
}

void ControlsAsync::vssSubsribeCallback(const std::string &path,
                                        const std::string &value)
{
    qDebug() << "[SubsCB]" 
             << QString::fromStdString(path)
             << "->" 
             << QString::fromStdString(value);

    // Mirror exactly what you had before, but now
    // you're assured this runs on the Qt main thread:

    if (path == VehicleAPI::V_Bo_Lights_Beam_Low_IsOn) {
      bool b = (value == "true");
      updateWidget_lightCtr_lowBeam(b);
    }
    if (path == VehicleAPI::V_Bo_Lights_Beam_High_IsOn) {
      bool b = (value == "true");
      updateWidget_lightCtr_highBeam(b);
    }
    else if (path == VehicleAPI::V_Bo_Lights_Hazard_IsSignaling) {
      bool b = (value == "true");
      updateWidget_lightCtr_Hazard(b);
    }
    else if (path == VehicleAPI::V_Ca_Seat_R1_DriverSide_Position) {
      try {
        int p = std::stoi(value);
        updateWidget_seat_driverSide_position(p);
      }
      catch (...) { /* ignore parse errors */ }
    }
    else if (path == VehicleAPI::V_Ca_HVAC_Station_R1_Driver_FanSpeed) {
      try {
        int speed = std::stoi(value)/10;
        updateWidget_hvac_driverSide_FanSpeed(speed);
      }
      catch (...) { }
    }
    else if (path == VehicleAPI::V_Ca_HVAC_Station_R1_Passenger_FanSpeed) {
      try {
        int speed = std::stoi(value)/10;
        updateWidget_hvac_passengerSide_FanSpeed(speed);
      }
      catch (...) { }
    }
}

// QML‐invokable slots also make use of the templated get…As<T>() and
// setCurrent/TargetValue<T>() to simplify:

void ControlsAsync::qml_setApi_lightCtr_LowBeam(bool sts)
{
    qDebug() << "QML → set LowBeam =" << sts;
    VAPI_CLIENT.setCurrentValue<bool>(
      DK_VAPI_DATABROKER,
      VehicleAPI::V_Bo_Lights_Beam_Low_IsOn,
      sts);
    VAPI_CLIENT.setTargetValue<bool>(
      DK_VAPI_DATABROKER,
      VehicleAPI::V_Bo_Lights_Beam_Low_IsOn,
      sts);

    // verify
    bool newSts = false;
    if (VAPI_CLIENT.getTargetValueAs<bool>(
          DK_VAPI_DATABROKER,
          VehicleAPI::V_Bo_Lights_Beam_Low_IsOn,
          newSts)) {
      qDebug() << "Verified LowBeam =" << newSts;
    }
}

void ControlsAsync::qml_setApi_lightCtr_HighBeam(bool sts)
{
    qDebug() << "QML → set HighBeam =" << sts;
    VAPI_CLIENT.setCurrentValue<bool>(
      DK_VAPI_DATABROKER,
      VehicleAPI::V_Bo_Lights_Beam_High_IsOn, sts);
    VAPI_CLIENT.setTargetValue<bool>(
      DK_VAPI_DATABROKER,
      VehicleAPI::V_Bo_Lights_Beam_High_IsOn, sts);

    bool newSts = false;
    if (VAPI_CLIENT.getTargetValueAs<bool>(
          DK_VAPI_DATABROKER,
          VehicleAPI::V_Bo_Lights_Beam_High_IsOn,
          newSts)) {
      qDebug() << "Verified HighBeam =" << newSts;
    }
}

void ControlsAsync::qml_setApi_lightCtr_Hazard(bool sts)
{
    qDebug() << "QML → set Hazard =" << sts;
    VAPI_CLIENT.setCurrentValue<bool>(
      DK_VAPI_DATABROKER,
      VehicleAPI::V_Bo_Lights_Hazard_IsSignaling,
      sts);
    VAPI_CLIENT.setTargetValue<bool>(
      DK_VAPI_DATABROKER,
      VehicleAPI::V_Bo_Lights_Hazard_IsSignaling,
      sts);

    bool newSts = false;
    if (VAPI_CLIENT.getTargetValueAs<bool>(
          DK_VAPI_DATABROKER,
          VehicleAPI::V_Bo_Lights_Hazard_IsSignaling,
          newSts)) {
      qDebug() << "Verified Hazard =" << newSts;
    }
}

void ControlsAsync::qml_setApi_seat_driverSide_position(int position)
{
    if (position < 1 || position > 10) {
        qWarning() << "Invalid seat position:" << position;
        return;
    }
    qDebug() << "QML → set SeatPos =" << position;
    uint8_t p = static_cast<uint8_t>(position);

    VAPI_CLIENT.setCurrentValue<uint8_t>(
      DK_VAPI_DATABROKER,
      VehicleAPI::V_Ca_Seat_R1_DriverSide_Position,
      p);
    VAPI_CLIENT.setTargetValue<uint8_t>(
      DK_VAPI_DATABROKER,
      VehicleAPI::V_Ca_Seat_R1_DriverSide_Position,
      p);

    int newPos = 0;
    if (VAPI_CLIENT.getTargetValueAs<int>(
          DK_VAPI_DATABROKER,
          VehicleAPI::V_Ca_Seat_R1_DriverSide_Position,
          newPos)) {
      qDebug() << "Verified SeatPos =" << newPos;
    }
}

void ControlsAsync::qml_setApi_hvac_driverSide_FanSpeed(uint8_t speed)
{
  uint8_t scaledSpeed = speed * 10;
    qDebug() << "QML → set DriverFanSpeed =" << speed << "(scaled" << scaledSpeed << ")";
    VAPI_CLIENT.setCurrentValue<uint8_t>(
      DK_VAPI_DATABROKER,
      VehicleAPI::V_Ca_HVAC_Station_R1_Driver_FanSpeed,
      scaledSpeed);
    VAPI_CLIENT.setTargetValue<uint8_t>(
      DK_VAPI_DATABROKER,
      VehicleAPI::V_Ca_HVAC_Station_R1_Driver_FanSpeed,
      scaledSpeed);

    int newSpeed = 0;
    if (VAPI_CLIENT.getTargetValueAs<int>(
          DK_VAPI_DATABROKER,
          VehicleAPI::V_Ca_HVAC_Station_R1_Driver_FanSpeed,
          newSpeed)) {
      qDebug() << "Verified DriverFanSpeed =" << (newSpeed);
    }
}

void ControlsAsync::qml_setApi_hvac_passengerSide_FanSpeed(uint8_t speed)
{
  uint8_t scaledSpeed = speed * 10;
    qDebug() << "QML → set PassengerFanSpeed =" << speed << "(scaled" << scaledSpeed << ")";
    VAPI_CLIENT.setCurrentValue<uint8_t>(
      DK_VAPI_DATABROKER,
      VehicleAPI::V_Ca_HVAC_Station_R1_Passenger_FanSpeed,
      scaledSpeed);
    VAPI_CLIENT.setTargetValue<uint8_t>(
      DK_VAPI_DATABROKER,
      VehicleAPI::V_Ca_HVAC_Station_R1_Passenger_FanSpeed,
      scaledSpeed);

    int newSpeed = 0;
    if (VAPI_CLIENT.getTargetValueAs<int>(
          DK_VAPI_DATABROKER,
          VehicleAPI::V_Ca_HVAC_Station_R1_Passenger_FanSpeed,
          newSpeed)) {
      qDebug() << "Verified PassengerFanSpeed =" << (newSpeed);
    }
}

ControlsAsync::~ControlsAsync()
{
    qDebug() << __func__ << __LINE__ << "  destroying ControlsAsync";

    // Use async shutdown to prevent blocking Qt application termination
    // This detaches subscription threads immediately without waiting for them to join
    // Prevents "QThread: Destroyed while thread is still running" errors
    // while allowing quick application shutdown
    VAPI_CLIENT.shutdownAsync();

    qDebug() << __func__ << __LINE__ << "  destroyed ControlsAsync";
}
