// Copyright (c) 2025 Eclipse Foundation.
// 
// This program and the accompanying materials are made available under the
// terms of the MIT License which is available at
// https://opensource.org/licenses/MIT.
// 
// SPDX-License-Identifier: MIT
#include "datamanager.hpp"
#include "fetching.hpp"

#include "jsonstorage.hpp"
#include "appserializer.hpp"

#include <QDebug>

using Core::JsonStorage;
using Core::AppSerializer;

QRecursiveMutex DataManager::s_jsonMutex;

/* ------------------------------ load ----------------------------- */
QJsonArray DataManager::load(const QString &target, int timeoutMs)
{
    const QString folder   = DK_CONTAINER_ROOT + "dk_marketplace/";
    const QString filePath = (target == QLatin1String("vehicle"))
                           ? folder + "installedapps.json"
                           : folder + "installedservices.json";

    MutexTryLocker guard(&s_jsonMutex, timeoutMs);
    if (!guard.locked()) {
        qWarning() << "DataManager::load: timeout (" << timeoutMs
                   << "ms) waiting for" << filePath;
        return {};                                       // early return
    }

    const auto doc = JsonStorage::load(filePath, QJsonValue(QJsonArray()));
    if (doc.isNull())  {
        qWarning() << "DataManager::load: cannot read" << filePath;
        return {};
    }
    if (!doc.isArray()) {
        qWarning() << "DataManager::load: array expected in" << filePath;
        return {};
    }
    return doc.array();                      // guard unlocks automatically
}

/* ------------------------------ save ----------------------------- */
bool DataManager::save(const QString &target,
                       const QJsonArray &arr,
                       int timeoutMs)
{
    const QString folder   = DK_CONTAINER_ROOT + "dk_marketplace/";
    const QString filePath = (target == QLatin1String("vehicle"))
                           ? folder + "installedapps.json"
                           : folder + "installedservices.json";

    QJsonDocument doc(arr);

    MutexTryLocker guard(&s_jsonMutex, timeoutMs);
    if (!guard.locked()) {
        qWarning() << "DataManager::save: timeout (" << timeoutMs
                   << "ms) waiting for" << filePath;
        return false;                                    // early return
    }

    if (!JsonStorage::save(filePath, doc)) {
        qWarning() << "DataManager::save: cannot write" << filePath;
        return false;
    }
    qDebug() << "DataManager::save: saved" << filePath;
    return true;                                         // guard unlocks
}

QList<AppInfo> DataManager::fetchAppList(const FetchOptions &opt)
{
    // 1) optional auth
    QString token;
    if (!opt.loginUrl.isEmpty())
        token = marketplace_login(opt.loginUrl,
                                  opt.username,
                                  opt.password);

    // 2) HTTP request (writes marketplace_data_installcfg.json)
    if (!queryMarketplacePackages(opt.marketUrl, token,
                                  opt.page, opt.limit, opt.category))
    {
        qWarning() << "[DataManager::fetchAppList] HTTP failed";
        return {};
    }

    // 3) load JSON that fetcher stored
    const QString listPath = opt.rootFolder + "/marketplace_data_installcfg.json";
    const auto doc = JsonStorage::load(listPath, QJsonValue(QJsonArray()));
    if (!doc.isArray()) {
        qWarning() << "[DataManager::fetchAppList] array expected in" << listPath;
        return {};
    }

    // 4) parse
    return AppSerializer::listFromJson(doc.array());
}
