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
    Q_INVOKABLE void qml_setApi_lightCtr_LowBeam(bool sts);
    Q_INVOKABLE void qml_setApi_lightCtr_HighBeam(bool sts);
    Q_INVOKABLE void qml_setApi_lightCtr_Hazard(bool sts);
    Q_INVOKABLE void qml_setApi_ambient_mode(int mode);
    Q_INVOKABLE void qml_setApi_ambient_intensity(uint8_t intensity);
    Q_INVOKABLE void qml_setApi_gear(int mode);
    Q_INVOKABLE void qml_setApi_door_driverSide_isOpen(bool isOpen);
    Q_INVOKABLE void qml_setApi_door_passengerSide_isOpen(bool isOpen);
    Q_INVOKABLE void qml_setApi_trunk_rear_isOpen(bool isOpen);
    Q_INVOKABLE void qml_setApi_hvac_driverSide_FanSpeed(uint8_t speed);
    Q_INVOKABLE void qml_setApi_hvac_passengerSide_FanSpeed(uint8_t speed);
    void qml_setApiTarget(const char *api, QVariant var);
    void vssSubsribeCallback(const std::string &updatePath, const std::string &updateValue); 

Q_SIGNALS:
    void updateWidget_lightCtr_lowBeam(bool sts);
    void updateWidget_lightCtr_highBeam(bool sts);
    void updateWidget_lightCtr_Hazard(bool sts);
    void updateWidget_lightCtr_ambient_mode(int mode);
    void updateWidget_lightCtr_ambient_intensity(int intensity);
    void updateWidget_gear_mode(int mode);
    void updateWidget_door_driverSide_isOpen(bool sts);
    void updateWidget_door_passengerSide_isOpen(bool sts);
    void updateWidget_trunk_rear_isOpen(bool sts);
    void updateWidget_hvac_driverSide_FanSpeed(int speed);
    void updateWidget_hvac_passengerSide_FanSpeed(int speed);

private:
};

#endif // CONTROLPAGE_H
