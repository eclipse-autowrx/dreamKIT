#pragma once
#include <QString>
#include <QJsonObject>
#include <QJsonArray>
#include <QVector>
#include <QMutex>
#include <QMutexLocker>

// one entry in "SignalList"
struct DashboardSignal {
    QString vssApi, vssType, datatype, description;
    QString vss2dbcSignal, dbc2vssSignal;

    static DashboardSignal fromJson(const QJsonObject &o) {
        DashboardSignal s;
        s.vssApi        = o.value("vss_api").toString();
        s.vssType       = o.value("vss_type").toString();
        s.datatype      = o.value("datatype").toString();
        s.description   = o.value("description").toString();
        s.vss2dbcSignal = o.value("vss2dbc_signal").toString();
        s.dbc2vssSignal = o.value("dbc2vss_signal").toString();
        return s;
    }

    QJsonObject toJson() const {
        QJsonObject o;
        o["vss_api"]          = vssApi;
        o["vss_type"]         = vssType;
        o["datatype"]         = datatype;
        o["description"]      = description;
        o["vss2dbc_signal"]   = vss2dbcSignal;
        o["dbc2vss_signal"]   = dbc2vssSignal;
        return o;
    }
};

// the JSON object at key "dashboardConfig"
struct DashboardConfig {
    QString Target;
    QString Platform;
    QString DockerImageURL;
    QJsonObject RuntimeCfg;
    QVector<DashboardSignal> SignalList;

    static DashboardConfig fromJson(const QJsonObject &o) {
        DashboardConfig c;
        c.Target         = o.value("Target").toString();
        c.Platform       = o.value("Platform").toString();
        c.DockerImageURL = o.value("DockerImageURL").toString();
        c.RuntimeCfg     = o.value("RuntimeCfg").toObject();
        for (auto v : o.value("SignalList").toArray())
            if (v.isObject())
              c.SignalList.append(
                DashboardSignal::fromJson(v.toObject()));
        return c;
    }

    QJsonObject toJson() const {
        QJsonObject o;
        o["Target"]         = Target;
        o["Platform"]       = Platform;
        o["DockerImageURL"] = DockerImageURL;
        o["RuntimeCfg"]     = RuntimeCfg;
        QJsonArray arr;
        for (auto &sig : SignalList)
            arr.append(sig.toJson());
        o["SignalList"] = arr;
        return o;
    }
};
