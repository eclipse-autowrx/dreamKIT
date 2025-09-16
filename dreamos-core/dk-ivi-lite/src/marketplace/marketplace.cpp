// Copyright (c) 2025 Eclipse Foundation.
// 
// This program and the accompanying materials are made available under the
// terms of the MIT License which is available at
// https://opensource.org/licenses/MIT.
// 
// SPDX-License-Identifier: MIT
#include "marketplace.hpp"
#include "../platform/notifications/notificationmanager.hpp"

using namespace Async;
using K3s::ManifestBuilder;
using K3s::JobManager;

extern QString DK_VCU_USERNAME;
extern QString DK_ARCH;
extern QString DK_DOCKER_HUB_NAMESPACE;
extern QString DK_CONTAINER_ROOT;

//-----------------------------------------------------------------------------
// AppListModel implementation (unchanged - keeping existing code)
//-----------------------------------------------------------------------------
AppListModel::AppListModel(QObject* p)
  : QAbstractListModel(p)
{}

int AppListModel::rowCount(const QModelIndex&) const { return m_apps.size(); }

QVariant AppListModel::data(const QModelIndex &idx, int role) const {
    if (!idx.isValid() || idx.row() < 0 || idx.row() >= m_apps.size()) return {};
    const auto &a = m_apps.at(idx.row());
    switch(role) {
      case IdRole:         return a.id;
      case NameRole:       return a.name;
      case AuthorRole:     return a.author;
      case RatingRole:     return a.rating;
      case DownloadsRole:  return a.downloads;
      case IconRole:       return a.iconUrl;
      case InstalledRole:  return a.isInstalled;
      case FolderRole:     return a.folderName;
      case PackageLinkRole:return a.packageLink;
      default:             return {};
    }
}

QHash<int,QByteArray> AppListModel::roleNames() const {
    return {
      {IdRole,         "id"},
      {NameRole,       "name"},
      {AuthorRole,     "author"},
      {RatingRole,     "rating"},
      {DownloadsRole,  "downloads"},
      {IconRole,       "iconUrl"},
      {InstalledRole,  "isInstalled"},
      {FolderRole,     "folderName"},
      {PackageLinkRole,"packageLink"}
    };
}

QVariantMap AppListModel::get(int row) const {
    QVariantMap m;
    if (row<0||row>=m_apps.size()) return m;
    const auto &a = m_apps.at(row);
    m["id"]           = a.id;
    m["name"]         = a.name;
    m["author"]       = a.author;
    m["rating"]       = a.rating;
    m["downloads"]    = a.downloads;
    m["iconUrl"]      = a.iconUrl;
    m["isInstalled"]  = a.isInstalled;
    m["folderName"]   = a.folderName;
    m["packageLink"]  = a.packageLink;
    return m;
}

void AppListModel::updateApps(const QList<AppInfo> &apps) {
    beginResetModel();
      m_apps = apps;
    endResetModel();
}

void AppListModel::setAppInstalled(int idx, bool inst) {
    if (idx<0||idx>=m_apps.size()) return;
    m_apps[idx].isInstalled = inst;
    QModelIndex mi = index(idx,0);
    emit dataChanged(mi, mi, {InstalledRole});
}

//-----------------------------------------------------------------------------
// CategoryListModel implementation (unchanged)
//-----------------------------------------------------------------------------
CategoryListModel::CategoryListModel(QObject* p)
  : QAbstractListModel(p)
{}

int CategoryListModel::rowCount(const QModelIndex&) const { return m_list.size(); }

QVariant CategoryListModel::data(const QModelIndex &idx, int role) const {
    if (!idx.isValid()||idx.row()<0||idx.row()>=m_list.size()) return {};
    const auto &c = m_list.at(idx.row());
    switch(role){
      case NameRole:     return c.name;
      case UrlRole:      return c.url;
      case LoginUrlRole: return c.loginUrl;
      default:           return {};
    }
}

QHash<int,QByteArray> CategoryListModel::roleNames() const {
    return {
      {NameRole,     "displayName"},
      {UrlRole,      "marketUrl"},
      {LoginUrlRole, "loginUrl"}
    };
}

void CategoryListModel::loadFromJsonFile(const QString &filePath) {
    QFile f(filePath);
    if (!f.exists()) {
        QDir().mkpath(QFileInfo(filePath).path());
        QJsonArray arr;
        QJsonObject def;
        def["name"]            = "BGSV Marketplace";
        def["marketplace_url"] = "https://store-be.digitalauto.tech";
        def["login_url"]       = "";
        arr.append(def);
        if (f.open(QIODevice::WriteOnly)) {
            f.write(QJsonDocument(arr).toJson());
            f.close();
        }
    }
    if (!f.open(QIODevice::ReadOnly)) return;
    auto doc = QJsonDocument::fromJson(f.readAll());
    f.close();
    if (!doc.isArray()) return;

    beginResetModel();
      m_list.clear();
      for (auto v : doc.array()) {
        if (!v.isObject()) continue;
        auto o = v.toObject();
        Info info;
        info.name     = o["name"].toString();
        info.url      = o["marketplace_url"].toString();
        info.loginUrl = o["login_url"].toString();
        m_list.append(info);
      }
    endResetModel();
}

//-----------------------------------------------------------------------------
// Simplified InstallationWorker using JobManager
//-----------------------------------------------------------------------------
InstallationWorker::InstallationWorker(QObject *parent)
    : QObject(parent)
    , m_jobManager(JobManager::instance())
{
    qDebug() << "[InstallationWorker] Using centralized JobManager";
}

InstallationWorker::~InstallationWorker()
{
    // JobManager is singleton, no cleanup needed
}

void InstallationWorker::startInstallation(const AppInfo &app, const QString &category)
{
    qDebug() << "[InstallationWorker] Starting installation for:" << app.name;
    
    // Store installation info
    m_currentApp = app;
    m_currentCategory = category;
    
    emit installationProgress("Preparing installation...");
    
    // Create installation request
    JobManager::InstallationRequest request;
    request.appId = app.id;
    request.appName = app.name;
    request.category = category;
    
    try {
        // Prepare manifest
        emit installationProgress("Creating deployment manifest...");
        K3s::ManifestInfo manifest = K3s::ManifestBuilder::write(app);
        
        // Build installation commands
        request.commands = buildInstallationCommands(app, manifest);
        
        if (request.commands.isEmpty()) {
            emit installationFailed(app.id, "No installation commands generated");
            return;
        }
        
        // Submit to JobManager
        auto *job = m_jobManager->installApplication(request);
        
        connect(job, &Async::JobBase::finished, this, [=](bool jobSuccess) {
            // jobSuccess indicates if the async job completed without crashing
            // We also need to check the actual result
            if (jobSuccess) {
                JobManager::JobResult result = job->result();
                if (result.success) {
                    qDebug() << "[InstallationWorker] Installation completed successfully for" << m_currentApp.id;
                    this->updateInstallationRecord(m_currentApp, m_currentCategory);
                    emit installationCompleted(m_currentApp.id);
                } else {
                    qWarning() << "[InstallationWorker] Installation failed:" << result.errorMessage;
                    qWarning() << "[InstallationWorker] Command output:" << result.output;
                    emit installationFailed(m_currentApp.id, result.errorMessage);
                }
            } else {
                qCritical() << "[InstallationWorker] Installation job crashed or failed to execute";
                emit installationFailed(m_currentApp.id, "Installation job execution failed");
            }
            job->deleteLater();
        });
        
    } catch (const std::exception &e) {
        emit installationFailed(app.id, QString("Exception: %1").arg(e.what()));
    }
}

void InstallationWorker::cancelInstallation()
{
    // JobManager doesn't support cancellation yet, but we can emit failure
    emit installationFailed(m_currentApp.id, "Installation cancelled by user");
}

QStringList InstallationWorker::buildInstallationCommands(const AppInfo &app, const K3s::ManifestInfo &manifest)
{
    QStringList commands;
    
    qDebug() << "[InstallationWorker] Building installation commands for" << app.id;
    qDebug() << "[InstallationWorker] Manifest - isRemoteNode:" << manifest.isRemoteNode;
    qDebug() << "[InstallationWorker] Manifest - pullJobYaml:" << manifest.pullJobYaml;
    qDebug() << "[InstallationWorker] Manifest - mirrorJobYaml:" << manifest.mirrorJobYaml;
    
    // Cleanup jobs to ensure environment is clean
    if (1) {
        emit installationProgress("Cleaning up installation jobs...");
        commands << QString("kubectl delete job mirror-%1 pull-%1 --ignore-not-found").arg(app.id);
    }

    // Node readiness check (lightweight)
    if (manifest.isRemoteNode) {
        emit installationProgress("Checking remote node availability...");
        commands << QString("kubectl get node vip --no-headers || (echo 'ZonalECU - VIP is not ready' && exit 1)");
    }
    
    // Mirror job (if remote node)
    if (manifest.isRemoteNode && !manifest.mirrorJobYaml.isEmpty()) {
        emit installationProgress("Setting up image mirroring...");
        commands << QString("kubectl apply -f %1").arg(manifest.mirrorJobYaml);
        commands << "sleep 20";  // Initial wait
        
        // Check mirror job status before proceeding
        commands << QString(R"(
            # Check mirror job status
            if kubectl get job mirror-%1 -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' | grep -q True; then
                echo "Mirror job failed immediately"
                kubectl logs job/mirror-%1 --tail=5
                exit 1
            elif kubectl get pods -l job-name=mirror-%1 -o jsonpath='{.items[0].status.containerStatuses[0].state.waiting.reason}' | grep -qE "ImagePullBackOff|ErrImagePull"; then
                echo "Mirror job image pull failed"
                exit 1
            fi
            echo "Mirror job status check passed"
        )").arg(app.id);
        commands << QString("kubectl wait --for=condition=complete job/mirror-%1 --timeout=300s").arg(app.id);
    }
    
    // Pull job
    if (!manifest.pullJobYaml.isEmpty()) {
        emit installationProgress("Pulling container image...");
        commands << QString("kubectl apply -f %1").arg(manifest.pullJobYaml);
        commands << "sleep 25";  // Initial wait for job to start
        
        // Check pull job status before long wait
        commands << QString(R"(
            # Quick status check after job creation
            if kubectl get job pull-%1 -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' | grep -q True; then
                echo "Pull job failed immediately"
                kubectl logs job/pull-%1 --tail=5
                exit 1
            elif kubectl get pods -l job-name=pull-%1 -o jsonpath='{.items[0].status.containerStatuses[0].state.waiting.reason}' | grep -qE "ImagePullBackOff|ErrImagePull"; then
                echo "Pull job image pull failed - check registry access"
                exit 1
            fi
            echo "Pull job initial status check passed"
        )").arg(app.id);
        
        // Wait for pull completion
        commands << QString("kubectl wait --for=condition=complete job/pull-%1 --timeout=1200s").arg(app.id);
    }
    
    // Cleanup jobs after successful pull
    if (!commands.isEmpty()) {
        emit installationProgress("Cleaning up installation jobs...");
        commands << QString("kubectl delete job mirror-%1 pull-%1 --ignore-not-found").arg(app.id);
    }
    
    qDebug() << "[InstallationWorker] Generated" << commands.size() << "installation commands:";
    for (int i = 0; i < commands.size(); ++i) {
        qDebug() << "[InstallationWorker] Command" << (i+1) << ":" << commands[i];
    }
    
    return commands;
}

void InstallationWorker::updateInstallationRecord(const AppInfo &app, const QString &category)
{
    try {
        DataManager dm;
        QJsonArray arr = dm.load(category);
        
        // Check if already exists
        bool exists = false;
        for (auto v : arr) {
            if (v.isObject() && v.toObject().value("id").toString() == app.id) {
                exists = true;
                break;
            }
        }
        
        if (!exists) {
            QJsonObject rec;
            rec["id"] = app.id;
            rec["name"] = app.name;
            rec["author"] = app.author;
            rec["rating"] = app.rating;
            rec["thumbnail"] = app.iconUrl;
            rec["installedAt"] = QDateTime::currentDateTime().toString(Qt::ISODate);
            arr.append(rec);
            dm.save(category, arr);
            qDebug() << "[InstallationWorker] Installation record updated for:" << app.id;
        }
        
    } catch (const std::exception &e) {
        qWarning() << "[InstallationWorker] Failed to update installation record:" << e.what();
    }
}

//-----------------------------------------------------------------------------
// Simplified MarketplaceViewModel
//-----------------------------------------------------------------------------
MarketplaceViewModel::MarketplaceViewModel(QObject *parent)
  : QObject(parent)
  , m_apps(new AppListModel(this))
  , m_cats(new CategoryListModel(this))
  , m_installWorker(new InstallationWorker(this))
  , m_jobManager(JobManager::instance())
{
    // Load categories
    QString cfg = DK_CONTAINER_ROOT + "dk_marketplace/marketplaceselection.json";
    m_cats->loadFromJsonFile(cfg);

    // Connect installation worker signals
    connect(m_installWorker, &InstallationWorker::installationProgress,
            this, &MarketplaceViewModel::onInstallationProgress);
    connect(m_installWorker, &InstallationWorker::installationCompleted,
            this, &MarketplaceViewModel::onInstallationCompleted);
    connect(m_installWorker, &InstallationWorker::installationFailed,
            this, &MarketplaceViewModel::onInstallationFailed);
    
    // Connect JobManager signals for UI feedback
    connect(m_jobManager, &JobManager::requestRejected,
            this, &MarketplaceViewModel::onJobManagerBusy);
            
    qDebug() << "[MarketplaceViewModel] Initialized with JobManager integration";
}

void MarketplaceViewModel::setCurrentCategory(int idx) {
    if (idx<0 || idx>=m_cats->rowCount()) return;
    if (m_currentCategory==idx) return;
    m_currentCategory = idx;
    emit currentCategoryChanged(idx);
    search(m_lastSearchTerm);
}

void MarketplaceViewModel::search(const QString &term)
{
    m_lastSearchTerm = term.isEmpty() ? QStringLiteral("vehicle") : term;
    m_apps->updateApps({});

    DataManager::FetchOptions opt;
    const QModelIndex mi = m_cats->index(m_currentCategory, 0);
    opt.marketUrl  = m_cats->data(mi, CategoryListModel::UrlRole).toString();
    opt.loginUrl   = m_cats->data(mi, CategoryListModel::LoginUrlRole).toString();
    opt.category   = m_lastSearchTerm;
    opt.page       = 1;
    opt.limit      = 100;
    opt.rootFolder = DK_CONTAINER_ROOT + "dk_marketplace/";

    if (m_searchJob) m_searchJob->deleteLater();
    m_searchJob = new Job<QList<AppInfo>>(
        [=](){ return DataManager::fetchAppList(opt); },
        this);

    connect(m_searchJob, &JobBase::finished,
            this, [this](bool ok){
        if (!ok) { 
            emit searchError(); 
            return; 
        }

        const QList<AppInfo> apps = m_searchJob->result();
        if (apps.isEmpty()) {
            emit searchError();
            return;
        }

        // Check which apps are already installed
        QSet<QString> installed;
        DataManager dm;
        const QJsonArray arr = dm.load(m_lastSearchTerm);
        for (auto v : arr)
            if (v.isObject())
                installed.insert(v.toObject().value("id").toString());

        QList<AppInfo> finalList = apps;
        for (auto &a : finalList)
            a.isInstalled = installed.contains(a.id);

        m_lastApps = finalList;
        m_apps->updateApps(finalList);
        emit searchFinished();
        
        m_searchJob->deleteLater();
        m_searchJob = nullptr;
    });
}

void MarketplaceViewModel::appSelected(int idx) {
    if (idx < 0 || idx >= m_lastApps.size()) return;
    
    QVariantMap info = m_apps->get(idx);
    
    if (!info.value("isInstalled").toBool()) {
        // Check if JobManager is busy
        if (m_jobManager->isBusy()) {
            NOTIFY_WARNING("Installation", "System busy: " + m_jobManager->currentOperation());
            return;
        }
        
        m_pendingIndex   = idx;
        m_pendingName    = info.value("name").toString();
        m_installPending = true;
        m_installingIndex = idx;
        m_isInstalling   = false;
        
        emit pendingAppNameChanged(m_pendingName);
        emit installPendingChanged(true);
        emit installingIndexChanged(m_installingIndex);
        emit isInstallingChanged(false);
    }
}

void MarketplaceViewModel::confirmInstall()
{
    if (!m_installPending || m_pendingIndex < 0 || m_pendingIndex >= m_lastApps.size()) {
        qWarning() << "[MarketplaceViewModel] Invalid install state";
        return;
    }
    
    // Double-check JobManager isn't busy
    if (m_jobManager->isBusy()) {
        NOTIFY_WARNING("Installation", "System busy: " + m_jobManager->currentOperation());
        cancelInstall();
        return;
    }
    
    const AppInfo app = m_lastApps[m_pendingIndex];
    
    // Update UI state
    m_isInstalling = true;
    emit isInstallingChanged(true);
    
    // Start installation
    m_installWorker->startInstallation(app, m_lastSearchTerm);
    
    qDebug() << "[MarketplaceViewModel] Started installation for:" << app.name;
}

void MarketplaceViewModel::cancelInstall() {
    if (!m_installPending) return;
    
    m_installWorker->cancelInstallation();
    
    // Reset state
    resetInstallationState();
}

void MarketplaceViewModel::resetInstallationState()
{
    m_installPending = false;
    m_isInstalling = false;
    m_installingIndex = -1;
    m_pendingIndex = -1;
    
    emit installPendingChanged(false);
    emit isInstallingChanged(false);
    emit installingIndexChanged(-1);
}

void MarketplaceViewModel::onInstallationProgress(const QString &message)
{
    emit installProgressChanged(message);
}

void MarketplaceViewModel::onInstallationCompleted(const QString &appId)
{
    qDebug() << "[MarketplaceViewModel] Installation completed:" << appId;
    
    // Update app as installed
    if (m_pendingIndex >= 0) {
        m_apps->setAppInstalled(m_pendingIndex, true);
        emit installFinished();
    }
    
    resetInstallationState();
    NOTIFY_SUCCESS("Installation", "Application installed successfully: " + appId);
}

void MarketplaceViewModel::onInstallationFailed(const QString &appId, const QString &error)
{
    qDebug() << "[MarketplaceViewModel] Installation failed:" << appId << error;
    
    resetInstallationState();
    emit installError();
    
    NOTIFY_ERROR("Installation", "Installation failed: " + error);
}

void MarketplaceViewModel::onJobManagerBusy(const QString &reason)
{
    qDebug() << "[MarketplaceViewModel] JobManager busy:" << reason;
    NOTIFY_WARNING("Installation", QString("System busy: %1").arg(reason));
    
    // If we have a pending installation, cancel it
    if (m_installPending) {
        resetInstallationState();
    }
}