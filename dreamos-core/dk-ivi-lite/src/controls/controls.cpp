#include "controls.hpp"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QThread>
#include <QDebug>
#include <QMutex>

#include "library/vapiclient/vapiclient.hpp"

QMap<int, uint32_t> map_ambient_mode2color = {
    {0, 0},
    {1, 255},
    {2, 65280},
    {3, 65535},
    {4, 16711680},
    {5, 16711935},
    {6, 16776960},
    {7, 16777215}
};

QMap<std::string, int> map_ambient_color2mode = {
    {"0", 0},
    {"255", 1},
    {"65280", 2},
    {"65535", 3},
    {"16711680", 4},
    {"16711935", 5},
    {"16776960", 6},
    {"16777215", 7}
};

ControlsAsync::ControlsAsync()
{
    qDebug() << __func__ << " - " << __LINE__ << " ===============================";

    std::vector<std::string> signalPaths;
    signalPaths.push_back(VehicleAPI::V_Bo_Lights_Beam_Low_IsOn);
    signalPaths.push_back(VehicleAPI::V_Bo_Lights_Beam_High_IsOn);
    signalPaths.push_back(VehicleAPI::V_Bo_Lights_Hazard_IsSignaling);
    signalPaths.push_back(VehicleAPI::V_Bo_Trunk_Rear_IsOpen);
    signalPaths.push_back(VehicleAPI::V_Ca_Lights_Ambient_Color);
    signalPaths.push_back(VehicleAPI::V_Ca_Lights_Ambient_Intensity);
    signalPaths.push_back(VehicleAPI::V_Ca_Lights_Ambient_IsLightOn);
    signalPaths.push_back(VehicleAPI::V_Ca_Door_R1_DriverSide_IsOpen);
    signalPaths.push_back(VehicleAPI::V_Ca_Door_R1_PassengerSide_IsOpen);
    signalPaths.push_back(VehicleAPI::V_Ca_HVAC_Station_R1_Driver_FanSpeed);
    signalPaths.push_back(VehicleAPI::V_Ca_HVAC_Station_R1_Passenger_FanSpeed);
    signalPaths.push_back(VehicleAPI::V_PT_Trans_SelectedGear);
    VAPI_CLIENT.subscribeTarget(DK_VAPI_DATABROKER, signalPaths,
        [this](const std::string &updatePath, const std::string &updateValue) {
            this->vssSubsribeCallback(updatePath, updateValue);
        }
    );
}

void ControlsAsync::init()
{
    QThread::msleep(300);

    // qDebug() << __func__ << " - " << __LINE__ << " ===============================";
    bool bool_val = false;
    std::string val = "";

    VAPI_CLIENT.getTargetValue(DK_VAPI_DATABROKER, VehicleAPI::V_Bo_Lights_Beam_Low_IsOn, val);
    if (val == "true") bool_val = true;
    else bool_val = false;
    updateWidget_lightCtr_lowBeam(bool_val);
    VAPI_CLIENT.getTargetValue(DK_VAPI_DATABROKER, VehicleAPI::V_Bo_Lights_Beam_High_IsOn, val);
    if (val == "true") bool_val = true;
    else bool_val = false;
    updateWidget_lightCtr_highBeam(bool_val);
    VAPI_CLIENT.getTargetValue(DK_VAPI_DATABROKER, VehicleAPI::V_Bo_Lights_Hazard_IsSignaling, val);
    if (val == "true") bool_val = true;
    else bool_val = false;
    updateWidget_lightCtr_Hazard(bool_val);

    VAPI_CLIENT.getTargetValue(DK_VAPI_DATABROKER, VehicleAPI::V_Ca_Lights_Ambient_Color, val);
    int mode = map_ambient_color2mode.value(val, 0);
    qDebug() << __func__ << " - " << __LINE__ << " =============================== V_Ca_Lights_Ambient_Color : "<< mode;
    updateWidget_lightCtr_ambient_mode(mode);

    VAPI_CLIENT.getTargetValue(DK_VAPI_DATABROKER, VehicleAPI::V_Ca_Lights_Ambient_Intensity, val);
    int intensity = std::atoi(val.c_str());
    qDebug() << __func__ << " - " << __LINE__ << " =============================== V_Ca_Lights_Ambient_Intensity : "<< intensity;
    updateWidget_lightCtr_ambient_intensity(intensity);

    VAPI_CLIENT.getTargetValue(DK_VAPI_DATABROKER, VehicleAPI::V_PT_Trans_SelectedGear, val);
    mode = std::atoi(val.c_str());
    qDebug() << __func__ << " - " << __LINE__ << " =============================== V_PT_Trans_SelectedGear : "<< mode;
    updateWidget_gear_mode(mode);

    VAPI_CLIENT.getTargetValue(DK_VAPI_DATABROKER, VehicleAPI::V_Ca_Door_R1_DriverSide_IsOpen, val);
    if (val == "true") bool_val = true;
    else bool_val = false;
    updateWidget_door_driverSide_isOpen(bool_val);
    VAPI_CLIENT.getTargetValue(DK_VAPI_DATABROKER, VehicleAPI::V_Ca_Door_R1_PassengerSide_IsOpen, val);
    if (val == "true") bool_val = true;
    else bool_val = false;
    updateWidget_door_passengerSide_isOpen(bool_val);
    VAPI_CLIENT.getTargetValue(DK_VAPI_DATABROKER, VehicleAPI::V_Bo_Trunk_Rear_IsOpen, val);
    if (val == "true") bool_val = true;
    else bool_val = false;
    updateWidget_trunk_rear_isOpen(bool_val);

    VAPI_CLIENT.getTargetValue(DK_VAPI_DATABROKER, VehicleAPI::V_Ca_HVAC_Station_R1_Driver_FanSpeed, val);
    int speed = std::atoi(val.c_str())/10;
    updateWidget_hvac_driverSide_FanSpeed(speed);
    VAPI_CLIENT.getTargetValue(DK_VAPI_DATABROKER, VehicleAPI::V_Ca_HVAC_Station_R1_Passenger_FanSpeed, val);
    speed = std::atoi(val.c_str())/10;
    updateWidget_hvac_passengerSide_FanSpeed(speed);

    // qDebug() << __func__ << " - " << __LINE__ << " ===============================";
}

/*************************************************************************
 ******************** Update Widget sections ******************************
 **************************************************************************/
void ControlsAsync::vssSubsribeCallback(const std::string &updatePath, const std::string &updateValue) 
{
    // qDebug() << "[ControlsAsync::vssSubsribeCallback] Update for " << QString::fromStdString(updatePath) << ": " << QString::fromStdString(updateValue);
    bool bool_val = false;
    if (updateValue == "true") bool_val = true;
    else if (updateValue == "false") bool_val = false;
    
    if (updatePath == VehicleAPI::V_Bo_Lights_Beam_Low_IsOn) {
        updateWidget_lightCtr_lowBeam(bool_val);
    }
    else if (updatePath == VehicleAPI::V_Bo_Lights_Beam_High_IsOn) {
        updateWidget_lightCtr_highBeam(bool_val);
    }
    else if (updatePath == VehicleAPI::V_Bo_Lights_Hazard_IsSignaling) {
        updateWidget_lightCtr_Hazard(bool_val);
    }
    else if (updatePath == VehicleAPI::V_Ca_Lights_Ambient_Color) {
        int mode = map_ambient_color2mode.value(updateValue, 0);
        updateWidget_lightCtr_ambient_mode(mode);
    }
    else if (updatePath == VehicleAPI::V_Ca_Lights_Ambient_Intensity) {
        int intensity = std::atoi(updateValue.c_str());
        updateWidget_lightCtr_ambient_intensity(intensity);
    }
    else if (updatePath == VehicleAPI::V_PT_Trans_SelectedGear) {
        int mode = std::atoi(updateValue.c_str());
        updateWidget_gear_mode(mode);
    }
    else if (updatePath == VehicleAPI::V_Ca_Door_R1_DriverSide_IsOpen) {
        updateWidget_door_driverSide_isOpen(bool_val);
    }
    else if (updatePath == VehicleAPI::V_Ca_Door_R1_PassengerSide_IsOpen) {
        updateWidget_door_passengerSide_isOpen(bool_val);
    }
    else if (updatePath == VehicleAPI::V_Bo_Trunk_Rear_IsOpen) {
        updateWidget_trunk_rear_isOpen(bool_val);
    }
    else if (updatePath == VehicleAPI::V_Ca_HVAC_Station_R1_Driver_FanSpeed) {
        int speed = std::atoi(updateValue.c_str())/10;
        updateWidget_hvac_driverSide_FanSpeed(speed);
    }
    else if (updatePath == VehicleAPI::V_Ca_HVAC_Station_R1_Passenger_FanSpeed) {
        int speed = std::atoi(updateValue.c_str())/10;
        updateWidget_hvac_passengerSide_FanSpeed(speed);
    }
}
/*************************************************************************
 **************** End Update Widget sections ******************************
 **************************************************************************/

/*************************************************************************
 ************************** Set API sections ******************************
 **************************************************************************/
void ControlsAsync::qml_setApi_lightCtr_LowBeam(bool sts)
{
    // qml_setApiTarget(VehicleAPI::V_Bo_Lights_Beam_Low_IsOn, sts);
    VAPI_CLIENT.setTargetValue(DK_VAPI_DATABROKER, VehicleAPI::V_Bo_Lights_Beam_Low_IsOn, sts);
}

void ControlsAsync::qml_setApi_lightCtr_HighBeam(bool sts)
{
    VAPI_CLIENT.setTargetValue(DK_VAPI_DATABROKER, VehicleAPI::V_Bo_Lights_Beam_High_IsOn, sts);
}

void ControlsAsync::qml_setApi_lightCtr_Hazard(bool sts)
{
    VAPI_CLIENT.setTargetValue(DK_VAPI_DATABROKER, VehicleAPI::V_Bo_Lights_Hazard_IsSignaling, sts);
}

void ControlsAsync::qml_setApi_ambient_mode(int mode)
{
    uint32_t color = map_ambient_mode2color.value(mode, 0);
    VAPI_CLIENT.setTargetValue(DK_VAPI_DATABROKER, VehicleAPI::V_Ca_Lights_Ambient_Color, color);
}

void ControlsAsync::qml_setApi_ambient_intensity(uint8_t intensity)
{
    VAPI_CLIENT.setTargetValue(DK_VAPI_DATABROKER, VehicleAPI::V_Ca_Lights_Ambient_Intensity, intensity);
}

void ControlsAsync::qml_setApi_gear(int mode)
{
    VAPI_CLIENT.setTargetValue(DK_VAPI_DATABROKER, VehicleAPI::V_PT_Trans_SelectedGear, mode);
}

void ControlsAsync::qml_setApi_door_driverSide_isOpen(bool isOpen)
{
    VAPI_CLIENT.setTargetValue(DK_VAPI_DATABROKER, VehicleAPI::V_Ca_Door_R1_DriverSide_IsOpen, isOpen);
}

void ControlsAsync::qml_setApi_door_passengerSide_isOpen(bool isOpen)
{
    VAPI_CLIENT.setTargetValue(DK_VAPI_DATABROKER, VehicleAPI::V_Ca_Door_R1_PassengerSide_IsOpen, isOpen);
}

void ControlsAsync::qml_setApi_trunk_rear_isOpen(bool isOpen)
{
    VAPI_CLIENT.setTargetValue(DK_VAPI_DATABROKER, VehicleAPI::V_Bo_Trunk_Rear_IsOpen, isOpen);
}

void ControlsAsync::qml_setApi_hvac_driverSide_FanSpeed(uint8_t speed)
{
    VAPI_CLIENT.setTargetValue(DK_VAPI_DATABROKER, VehicleAPI::V_Ca_HVAC_Station_R1_Driver_FanSpeed, (uint8_t)(speed*10));
} 

void ControlsAsync::qml_setApi_hvac_passengerSide_FanSpeed(uint8_t speed)
{
    VAPI_CLIENT.setTargetValue(DK_VAPI_DATABROKER, VehicleAPI::V_Ca_HVAC_Station_R1_Passenger_FanSpeed, (uint8_t)(speed*10));
} 

/*************************************************************************
 ************************** End Set API sections **************************
 **************************************************************************/

ControlsAsync::~ControlsAsync()
{
    qDebug() << __func__ << " - " << __LINE__ << " ControlsAsync instance is destroyed  ===========================";
}
