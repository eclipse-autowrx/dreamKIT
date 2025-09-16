// Copyright (c) 2025 Eclipse Foundation.
// 
// This program and the accompanying materials are made available under the
// terms of the MIT License which is available at
// https://opensource.org/licenses/MIT.
// 
// SPDX-License-Identifier: MIT
#ifndef DIGITALAUTO_H
#define DIGITALAUTO_H

#include "QString"
#include <QObject>
#include <QThread>
#include <QList>
#include <QFileSystemWatcher>
#include <QTimer>

typedef struct {
    QString appId;
    QString name;
    QString lastDeploy;
//    QString noofdownload;
//    QString iconPath;
//    QString foldername;
//    QString packagelink;
    bool isSubscribed = false;
} DigitalAutoAppListStruct;

//void digitalauto_appstore_readAppList(const QString searchName, QList<DigitalAutoAppListStruct> &appListInfo);
class DigitalAutoAppAsync;

class DigitalAutoAppCheckThread : public QThread
{
    Q_OBJECT

public:
    DigitalAutoAppCheckThread(DigitalAutoAppAsync *parent);
    void run();
    void triggerCheckAppStart(QString id, QString name);

Q_SIGNALS:
    void resultReady(QString appId, bool isStarted, QString msg);

private:
    QString m_appId;
    QString m_appName;
    bool m_istriggeredAppStart = false;
    DigitalAutoAppAsync *m_digitalAutoAppAsync = nullptr;
    QFileSystemWatcher *m_filewatcher = nullptr;
};

class DigitalAutoAppAsync: public QObject
{
    Q_OBJECT
public:
    DigitalAutoAppAsync();

    Q_INVOKABLE void initSubscribeAppFromDB();

    Q_INVOKABLE void executeApp(const QString name, const QString appId, bool isSubsribed);

    Q_INVOKABLE void removeApp(int idx);

    Q_INVOKABLE void openAppEditor(int idx);


Q_SIGNALS:
    void appendAppInfoToAppList(QString name, QString appId, bool isSubscribed);
    void updateStartAppMsg(QString appId, bool isStarted, QString msg);
    void updateAppRunningSts(QString appId, bool isStarted, int idx);
    void clearAppListView();
    void updateProgressValue(int percent);
    void setProgressVisibility(bool visible);
    void updateBoardSerialNumber(QString serial);

public Q_SLOTS:
    void handleResults(QString appId, bool isStarted, QString msg);
    void fileChanged(const QString& path);
    void updateDeploymentProgress();
    void checkRunningAppSts();

private:
    QList<DigitalAutoAppListStruct> m_appListInfo;
    DigitalAutoAppCheckThread *workerThread;
    QTimer *m_timer;
    QTimer *m_timer_apprunningcheck;
    int m_deploymentProgressPercent = 0;
    QString m_serialNo;
};

#endif // DIGITALAUTO_H
