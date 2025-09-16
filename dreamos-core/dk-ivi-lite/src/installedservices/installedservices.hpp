// Copyright (c) 2025 Eclipse Foundation.
// 
// This program and the accompanying materials are made available under the
// terms of the MIT License which is available at
// https://opensource.org/licenses/MIT.
// 
// SPDX-License-Identifier: MIT
#pragma once
#include "installedasyncbase.hpp"

/* DTO */
struct VsersListStruct
{
    QString id,category,name,author,rating,noofdownload,
            iconPath,foldername,packagelink;
    bool    isInstalled=false, isSubscribed=false;
};
Q_DECLARE_METATYPE(VsersListStruct)

class VsersAsync : public InstalledAsyncBase<VsersListStruct,VsersAsync>
{
    Q_OBJECT
    Q_PROPERTY(bool workerNodeOnline READ workerNodeOnline
               NOTIFY workerNodeStatusChanged)
public:
    explicit VsersAsync(QObject *p=nullptr) : InstalledAsyncBase(p) {}

    /* identity ---------------------------------------------------- */
    QString dbKey()      const override { return "vehicle-service"; }
    QString fileName()   const override { return "vehicle-service"; }
    QString folderRoot() const override
    { return DK_CONTAINER_ROOT + "dk_marketplace/"; }
    QString deploymentYaml(const QString &id) const override
    { return QString("%1/%2/%2_deployment.yaml").arg(folderRoot(),id); }

    /* ---------- QML-visible wrappers ---------------------------- */
    Q_INVOKABLE void initInstalledFromDB()             { InstalledAsyncBase::initInstalledFromDB(); }
    Q_INVOKABLE void executeServices(int i,const QString &n,const QString &id,bool sub)
                                                    { InstalledAsyncBase::executeServices(i,n,id,sub); }
    Q_INVOKABLE void removeServices(int i)           { InstalledAsyncBase::removeServices(i); }
    Q_INVOKABLE void openAppEditor(int idx) { launchVsCode(idx); }

    /* slot needed by InstalledCheckThread string-connect */
    Q_SLOT void fileChanged(const QString &p)         { InstalledAsyncBase::fileChanged(p); }

signals:
    void workerNodeStatusChanged(bool);
    void clearServicesListView();
    void appendServicesInfoToServicesList(QString,QString,QString,QString,
                                          QString,bool,QString,bool);
    void appendLastRowToServicesList(int);
    void updateServicesRunningSts(QString,bool,int);
    void updateStartAppMsg(QString,bool,QString);

public slots:
    void handleResults(QString id,bool ok,QString msg)
    { emit updateStartAppMsg(id,ok,msg); }

protected:
    /* specific for VsersAsync, to monitor various system components */
    bool wantsNodeMonitor() const override { return true; }
    bool wantsWlanMonitor() const override { return true; }
    bool wantsAutoRestart() const override { return true; }
    
    /* Enable VSS model monitoring for this class */
    bool wantsVSSModelMonitor() const override { return true; }

    void appendItemToQml(const VsersListStruct &it) override
    { emit appendServicesInfoToServicesList(it.name,it.author,it.rating,
                                            it.noofdownload,it.iconPath,
                                            it.isInstalled,it.id,it.isSubscribed); }
};
