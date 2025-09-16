// Copyright (c) 2025 Eclipse Foundation.
// 
// This program and the accompanying materials are made available under the
// terms of the MIT License which is available at
// https://opensource.org/licenses/MIT.
// 
// SPDX-License-Identifier: MIT
#pragma once
#include <QObject>
#include <QAbstractListModel>
#include <QStandardPaths>
#include <QDir>
#include <QDateTime>

// bring in your existing fetch helpers:
#include "../platform/async/asyncjob.hpp"
#include "../platform/data/fetching.hpp"
#include "../platform/data/datamanager.hpp"
#include "../platform/integrations/kubernetes/manifestbuilder.hpp"
#include "../platform/integrations/kubernetes/jobmanager.hpp"

class AppListModel : public QAbstractListModel {
    Q_OBJECT
  public:
    enum Roles {
      IdRole = Qt::UserRole+1,
      NameRole, AuthorRole, RatingRole,
      DownloadsRole, IconRole,
      InstalledRole, FolderRole, PackageLinkRole
    };
    explicit AppListModel(QObject* parent=nullptr);

    // QAbstractListModel overrides
    int rowCount(const QModelIndex& = QModelIndex()) const override;
    QVariant data(const QModelIndex& idx, int role) const override;
    QHash<int,QByteArray> roleNames() const override;

    // helper to read out a full row as a map
    Q_INVOKABLE QVariantMap get(int row) const;

    // update the list wholesale
    void updateApps(const QList<AppInfo>& apps);
    // mark one item installed
    void setAppInstalled(int index, bool installed);

  private:
    QList<AppInfo> m_apps;
};

class CategoryListModel : public QAbstractListModel {
    Q_OBJECT
  public:
    enum Roles {
      NameRole      = Qt::UserRole+1,
      UrlRole,
      LoginUrlRole
    };
    explicit CategoryListModel(QObject* parent=nullptr);

    int rowCount(const QModelIndex& = QModelIndex()) const override;
    QVariant data(const QModelIndex& idx, int role) const override;
    QHash<int,QByteArray> roleNames() const override;

    // load (or create + load) your JSON of marketplaces
    Q_INVOKABLE void loadFromJsonFile(const QString& filePath);

  private:
    struct Info { QString name, url, loginUrl; };
    QList<Info> m_list;
};

//-----------------------------------------------------------------------------
// Simplified InstallationWorker using JobManager
//-----------------------------------------------------------------------------
class InstallationWorker : public QObject {
    Q_OBJECT

public:
    explicit InstallationWorker(QObject *parent = nullptr);
    ~InstallationWorker();

    void startInstallation(const AppInfo &app, const QString &category);
    void cancelInstallation();

signals:
    void installationProgress(const QString &message);
    void installationCompleted(const QString &appId);
    void installationFailed(const QString &appId, const QString &error);

private:
    QStringList buildInstallationCommands(const AppInfo &app, const K3s::ManifestInfo &manifest);
    void updateInstallationRecord(const AppInfo &app, const QString &category);

    K3s::JobManager *m_jobManager;
    AppInfo m_currentApp;
    QString m_currentCategory;
};

class MarketplaceViewModel : public QObject {
    Q_OBJECT

    // expose our two models + state
    Q_PROPERTY(AppListModel*       appsModel        READ appsModel       CONSTANT)
    Q_PROPERTY(CategoryListModel*  categoriesModel  READ categoriesModel CONSTANT)
    Q_PROPERTY(int                 currentCategory  READ currentCategory WRITE setCurrentCategory NOTIFY currentCategoryChanged)
    Q_PROPERTY(bool                isInstalling     READ isInstalling    NOTIFY isInstallingChanged)
    Q_PROPERTY(int                 installingIndex  READ installingIndex NOTIFY installingIndexChanged)
    Q_PROPERTY(bool                installPending   READ installPending  NOTIFY installPendingChanged)
    Q_PROPERTY(QString             pendingAppName   READ pendingAppName  NOTIFY pendingAppNameChanged)

  public:
    explicit MarketplaceViewModel(QObject* parent=nullptr);

    AppListModel*      appsModel() const       { return m_apps; }
    CategoryListModel* categoriesModel() const { return m_cats; }
    int                currentCategory() const { return m_currentCategory; }
    bool               isInstalling() const    { return m_isInstalling; }
    int                installingIndex() const { return m_installingIndex; }
    bool               installPending() const  { return m_installPending; }
    QString            pendingAppName() const  { return m_pendingName; }

  public slots:
    // called by QML
    void search(const QString& term);
    void setCurrentCategory(int idx);   // setter for Q_PROPERTY
    void appSelected(int idx);
    void confirmInstall();
    void cancelInstall();

  signals:
    void currentCategoryChanged(int);
    void isInstallingChanged(bool);
    void installingIndexChanged(int newIndex);
    void installPendingChanged(bool);
    void pendingAppNameChanged(const QString&);
    void installProgressChanged(const QString &message);  // Progress updates
    // 
    void searchFinished();
    void searchError();
    void installFinished();
    void installError();

  private slots:
    void onInstallationProgress(const QString &message);
    void onInstallationCompleted(const QString &appId);
    void onInstallationFailed(const QString &appId, const QString &error);
    void onJobManagerBusy(const QString &reason);

  private:
    void resetInstallationState();
    
    AppListModel*      m_apps         = nullptr;
    CategoryListModel* m_cats         = nullptr;
    QList<AppInfo>     m_lastApps;

    Async::Job<QList<AppInfo>>     *m_searchJob  = nullptr;

    // Simplified: Just use the worker with JobManager integration
    InstallationWorker             *m_installWorker = nullptr;
    K3s::JobManager               *m_jobManager = nullptr;

    int     m_currentCategory = 0;
    bool    m_isInstalling    = false;
    int     m_installingIndex = -1;
    bool    m_installPending  = false;
    QString m_pendingName;
    int     m_pendingIndex    = -1;
    QString m_lastSearchTerm;
};