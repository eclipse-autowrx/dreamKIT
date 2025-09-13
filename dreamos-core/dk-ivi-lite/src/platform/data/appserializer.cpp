// core/appserializer.cpp
#include "appserializer.hpp"
#include "dashboardconfig.hpp"
#include <QJsonDocument>
#include <QDebug>

using namespace Core;

AppInfo AppSerializer::fromJson(const QJsonObject &o)
{
    AppInfo a;
    a.id          = o.value("_id").toString();
    a.name        = o.value("name").toString();
    if (o.value("storeId").isObject())
        a.author  = o.value("storeId").toObject()
                          .value("name").toString();
    a.rating      = o.value("rating").toDouble();
    a.downloads   = o.value("downloads").toInt();
    a.iconUrl     = o.value("thumbnail").toString();
    a.folderName  = a.id;
    a.packageLink = o.value("packageLink").toString();

    if (o.contains("dashboardConfig") && o.value("dashboardConfig").isString())
    {
        const auto raw = o.value("dashboardConfig").toString().toUtf8();
        const auto doc = QJsonDocument::fromJson(raw);
        if (doc.isObject())
            a.dashboardConfig = DashboardConfig::fromJson(doc.object());
        else
            qWarning() << "AppSerializer::fromJson bad dashboardConfig" << a.id;
    }
    return a;
}

QJsonObject AppSerializer::toJson(const AppInfo &app)
{
    QJsonObject o;
    o["_id"]       = app.id;
    o["name"]      = app.name;
    QJsonObject sid;
    sid["name"]    = app.author;
    o["storeId"]   = sid;
    o["rating"]    = app.rating;
    o["downloads"] = app.downloads;
    o["thumbnail"] = app.iconUrl;

    QJsonDocument cd(app.dashboardConfig.toJson());
    o["dashboardConfig"] = QString(cd.toJson(QJsonDocument::Compact));
    return o;
}

QList<AppInfo> AppSerializer::listFromJson(const QJsonArray &arr)
{
    QList<AppInfo> out;
    out.reserve(arr.size());
    for (auto v : arr)
        if (v.isObject())
            out << fromJson(v.toObject());
    return out;
}
