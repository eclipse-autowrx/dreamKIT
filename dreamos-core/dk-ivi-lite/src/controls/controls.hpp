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
    Q_INVOKABLE void qml_setApi_lightCtr_Brake(bool sts);
    Q_INVOKABLE void qml_setApi_lightCtr_Hazard(bool sts);
    // Seat controls
    Q_INVOKABLE void qml_setApi_seat_driverSide_position(int position);
    // HVAC controls
    Q_INVOKABLE void qml_setApi_hvac_driverSide_FanSpeed(uint8_t speed);
    Q_INVOKABLE void qml_setApi_hvac_passengerSide_FanSpeed(uint8_t speed);
    
    void vssSubsribeCallback(const std::string &updatePath, const std::string &updateValue); 

Q_SIGNALS:
    // Lighting signals
    void updateWidget_lightCtr_lowBeam(bool sts);
    void updateWidget_lightCtr_highBeam(bool sts);
    void updateWidget_lightCtr_brake(bool sts);
    void updateWidget_lightCtr_Hazard(bool sts);
    // Seat signals
    void updateWidget_seat_driverSide_position(int position);
    // HVAC signals
    void updateWidget_hvac_driverSide_FanSpeed(int speed);
    void updateWidget_hvac_passengerSide_FanSpeed(int speed);

private:
};

#endif // CONTROLPAGE_H