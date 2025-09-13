#pragma once
// core/appserializer.hpp
//
// Pure conversion helpers:  AppInfo <-> QJsonObject / QJsonArray
//
#include "datamanager.hpp"     // supplies struct AppInfo
#include <QJsonArray>

namespace Core {

class AppSerializer
{
public:
    static AppInfo        fromJson(const QJsonObject &o);
    static QJsonObject    toJson(const AppInfo &app);
    static QList<AppInfo> listFromJson(const QJsonArray &arr);
};

} // namespace Core
