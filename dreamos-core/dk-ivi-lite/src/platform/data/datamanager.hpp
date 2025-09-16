// Copyright (c) 2025 Eclipse Foundation.
// 
// This program and the accompanying materials are made available under the
// terms of the MIT License which is available at
// https://opensource.org/licenses/MIT.
// 
// SPDX-License-Identifier: MIT
#pragma once
// datamanager.hpp   (only “business / HTTP” parts remain)

#include <QString>
#include <QJsonDocument>
#include <QJsonArray>
#include <QList>
#include <QMutex>
#include <QRecursiveMutex>
#include <QElapsedTimer>

#include "dashboardconfig.hpp"

extern QString DK_VCU_USERNAME;
extern QString DK_ARCH;
extern QString DK_DOCKER_HUB_NAMESPACE;
extern QString DK_CONTAINER_ROOT;

struct AppInfo {
    QString id, name, author, iconUrl, folderName, packageLink;
    double  rating     = 0;
    int     downloads  = 0;
    bool    isInstalled = false;
    DashboardConfig dashboardConfig;
};

class DataManager
{
public:
    struct FetchOptions {
        QString marketUrl;
        QString loginUrl;
        QString username;
        QString password;
        QString category;
        int     page    = 1;
        int     limit   = 20;
        QString rootFolder;
    };

    // optional second argument lets callers override the default 3-s
    // wait time per call.
    QJsonArray load(const QString &target,
                    int timeoutMs = kJsonLockTimeoutMs);

    bool save(const QString &target, const QJsonArray &arr,
              int timeoutMs = kJsonLockTimeoutMs);

    static QList<AppInfo> fetchAppList(const FetchOptions &opt);

private:
    // RAII helper with timeout
    class MutexTryLocker
    {
    public:
        MutexTryLocker(QRecursiveMutex *m, int t)
            : m_mutex(m), m_locked(m && m->tryLock(t)) {}
        ~MutexTryLocker() { if (m_locked) m_mutex->unlock(); }

        Q_DISABLE_COPY_MOVE(MutexTryLocker)
        bool locked() const { return m_locked; }
    private:
        QRecursiveMutex *m_mutex;
        bool             m_locked;
    };

    static QRecursiveMutex s_jsonMutex;
    static constexpr int   kJsonLockTimeoutMs = 3000;   // default 3 s
};
