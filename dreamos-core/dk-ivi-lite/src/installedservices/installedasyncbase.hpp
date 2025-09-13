#pragma once
#include <QObject>
#include <QTimer>
#include <QJsonArray>
#include <QEventLoop>
#include <QCryptographicHash>
#include <QDateTime>
#include <QMutex>
#include <QStandardPaths>

#include "../platform/async/asyncjob.hpp"
#include "../platform/data/datamanager.hpp"
#include "../platform/notifications/notificationmanager.hpp"
#include "../platform/integrations/kubernetes/jobmanager.hpp"
#include "../platform/monitoring/wlanmonitor.hpp"
#include "../platform/monitoring/autorestartmanager.hpp"
#include "installedcheckthread.hpp"

extern QString DK_CONTAINER_ROOT;

/********************************************************************/
template<class TI, class TD>
class InstalledAsyncBase : public QObject
{
public:
    explicit InstalledAsyncBase(QObject *parent = nullptr);
    virtual ~InstalledAsyncBase();

    /* must be provided by concrete subclass */
    virtual QString dbKey()      const = 0;
    virtual QString fileName()   const = 0;
    virtual QString folderRoot() const = 0;
    virtual QString deploymentYaml(const QString &id) const = 0;

    /* ---------- API exposed to QML ------------------------------ */
    Q_INVOKABLE void initInstalledFromDB();
    Q_INVOKABLE void executeServices(int idx, const QString&, const QString id, bool subscribe);
    Q_INVOKABLE void removeServices(int idx);
    Q_INVOKABLE void refreshServiceStatus();  // Manual status refresh
    Q_INVOKABLE virtual void openAppEditor(int) { }          // optional

    // Status accessors
    bool workerNodeOnline() const;
    bool wlanConnected() const;
    
    /* restart options when internet is available */
    Q_INVOKABLE void restartSdvRuntime();
    Q_INVOKABLE void restartApplication(); 
    Q_INVOKABLE void forceRestartBoth();

protected:
    virtual void appendItemToQml(const TI&) = 0;

    /* subclasses return true if they want node monitoring */
    virtual bool wantsNodeMonitor() const { return false; }

    /* subclasses return true if they want WLAN monitoring */
    virtual bool wantsWlanMonitor() const { return false; }
    
    /* subclasses return true if they want auto-restart functionality */
    virtual bool wantsAutoRestart() const { return false; }

    /* subclasses return true if they want VSS model monitoring */
    virtual bool wantsVSSModelMonitor() const { return false; }

    /* helper used by InstalledCheckThread */
    void fileChanged(const QString&);

    /* give read access for openAppEditor() implementation */
    const QList<TI>& items() const { return m_items; }

    /* shared editor launcher (called by the wrappers below) */
    void launchVsCode(int idx);

private slots:
    void onNodeStatusChanged(bool online);
    void onWlanStatusChanged(bool connected);
    void onJobManagerStateChanged(K3s::JobManager::State state);
    void onJobFinished(const QString &operation, bool success, const QString &message);
    
    // Optimized file monitoring slots
    void onFileHashChanged();
    void performCachedStatusUpdate();
    
    // VSS model monitoring slots
    void onVSSModelHashChanged();

private:
    // Enhanced deployment status structure
    struct DeploymentStatus {
        QString id;
        bool isRunning = false;
        QDateTime lastChecked;
        QDateTime lastStatusChange;
        int consecutiveFailures = 0;
        bool hasValidCache = false;
        
        // Constructor
        DeploymentStatus() = default;
        DeploymentStatus(const QString& deploymentId) : id(deploymentId) {}
        
        // Check if cache is still valid
        bool isCacheValid(int maxAgeMs = 10000) const {
            return hasValidCache && 
                   lastChecked.isValid() && 
                   lastChecked.msecsTo(QDateTime::currentDateTime()) < maxAgeMs;
        }
    };

    void updateInstalledList(const QJsonArray&);
    void initializeMonitoring();
    void cleanupMonitoring();
    
    // Optimized file monitoring with MD5
    void initializeFileMonitoring();
    QString calculateFileHash(const QString &filePath);
    
    // VSS model monitoring methods
    void initializeVSSModelMonitoring();
    QString getVSSModelPath() const;
    void handleVSSModelChange();
    
    // Enhanced status caching system
    void initializeStatusCaching();
    void updateDeploymentStatusCache();
    void applyStatusUpdatesToUI();
    void invalidateStatusCache();
    void triggerStatusUpdateIfNeeded();
    bool canPerformOperation(const QString &operation) const;

    // helper method declarations
    bool tryAcquireLocalOperation(const QString &operation);
    void releaseLocalOperation();
    // member variables for request management (add to existing private section)
    mutable QMutex m_operationMutex;
    bool m_operationInProgress {false};
    QString m_currentLocalOperation;
    
    // Core data
    QList<TI>             m_items;
    InstalledCheckThread *m_checkThread {nullptr};
    
    // Central JobManager reference
    K3s::JobManager      *m_jobManager       {nullptr};
    
    // Extracted functionality
    WlanMonitor          *m_wlanMonitor      {nullptr};
    AutoRestartManager   *m_autoRestartMgr   {nullptr};
    
    // Status tracking
    bool                  m_nodeOnline  {true};
    bool                  m_wlanOnline  {false};
    bool                  m_nodeCheckInProgress {false};
    QDateTime             m_lastNodeCheck;

    // Optimized file monitoring with MD5
    QString               m_watchedFilePath;
    QString               m_lastFileHash;
    QTimer               *m_fileHashTimer   {nullptr};
    bool                  m_isBootup        {true};
    
    // VSS model monitoring with MD5
    QString               m_vssModelPath;
    QString               m_lastVSSModelHash;
    QTimer               *m_vssModelTimer   {nullptr};
    
    // Enhanced cached deployment status system
    QHash<QString, DeploymentStatus> m_deploymentStatusCache;
    QMutex                m_cacheMutex;
    bool                  m_statusUpdateInProgress {false};
    bool                  m_autoStatusUpdatesEnabled {true};
    
    // Configuration
    static constexpr int FILE_HASH_CHECK_INTERVAL = 3000;     // 3 seconds
    static constexpr int VSS_MODEL_CHECK_INTERVAL = 5000;     // 5 seconds
    static constexpr int CACHE_VALIDITY_DURATION = 10000;     // 10 seconds
    static constexpr int MAX_CONSECUTIVE_FAILURES = 3;
};

/********************************************************************
 *  I M P L E M E N T A T I O N
 *******************************************************************/
#include <QMetaObject>
#include <QThread>
#include <QFileInfo>
#include <stdexcept>

/* ------------ ctor -------------------------------------------- */
template<class TI,class TD>
InstalledAsyncBase<TI,TD>::InstalledAsyncBase(QObject *parent)
    : QObject(parent)
    , m_jobManager(K3s::JobManager::instance())
{
    if (DK_CONTAINER_ROOT.isEmpty())
        DK_CONTAINER_ROOT = qEnvironmentVariable("DK_CONTAINER_ROOT");

    // Connect to centralized JobManager
    connect(m_jobManager, &K3s::JobManager::jobFinished,
            this, &InstalledAsyncBase::onJobFinished);
    connect(m_jobManager, &K3s::JobManager::stateChanged,
            this, &InstalledAsyncBase::onJobManagerStateChanged);

    // Initialize optimized file monitoring timer
    m_fileHashTimer = new QTimer(this);
    m_fileHashTimer->setSingleShot(false);
    m_fileHashTimer->setInterval(FILE_HASH_CHECK_INTERVAL);
    connect(m_fileHashTimer, &QTimer::timeout,
            this, &InstalledAsyncBase::onFileHashChanged);

    // Initialize VSS model monitoring timer
    m_vssModelTimer = new QTimer(this);
    m_vssModelTimer->setSingleShot(false);
    m_vssModelTimer->setInterval(VSS_MODEL_CHECK_INTERVAL);
    connect(m_vssModelTimer, &QTimer::timeout,
            this, &InstalledAsyncBase::onVSSModelHashChanged);

    // Initialize monitoring after the base constructor knows the v-table
    QTimer::singleShot(0, this, [this](){
        initializeMonitoring();
    });
}

/* ------------ dtor --------------------------------------------- */
template<class TI,class TD>
InstalledAsyncBase<TI,TD>::~InstalledAsyncBase()
{
    cleanupMonitoring();
}

/* ------------ initialize monitoring --------------------------- */
template<class TI,class TD>
void InstalledAsyncBase<TI,TD>::initializeMonitoring()
{
    // 1) Initialize file monitoring with MD5
    initializeFileMonitoring();
    
    // 2) Initialize status caching system
    initializeStatusCaching();

    // 3) Initialize VSS model monitoring (if requested)
    if (wantsVSSModelMonitor()) {
        initializeVSSModelMonitoring();
        qDebug() << "[InstalledAsyncBase] VSS model monitoring enabled";
    }

    // 4) WLAN monitoring (if requested) - simplified
    if (wantsWlanMonitor()) {
        m_wlanMonitor = new WlanMonitor(this);
        m_wlanMonitor->setCheckInterval(30000); // 30 seconds
        connect(m_wlanMonitor, &WlanMonitor::connectionStatusChanged,
                this, &InstalledAsyncBase::onWlanStatusChanged);
        m_wlanMonitor->startMonitoring();
        
        qDebug() << "[InstalledAsyncBase] WLAN monitoring enabled";
    }

    // 5) Auto-restart functionality (if requested)
    if (wantsAutoRestart()) {
        m_autoRestartMgr = new AutoRestartManager(this);
        m_autoRestartMgr->setWlanMonitor(m_wlanMonitor);
        m_autoRestartMgr->setJobManager(m_jobManager);
        
        qDebug() << "[InstalledAsyncBase] Auto-restart functionality enabled";
    }

    // 6) Node monitoring (if requested) - using JobManager
    if (wantsNodeMonitor()) {
        auto *nodeTimer = new QTimer(this);
        nodeTimer->setSingleShot(false);
        
        connect(nodeTimer, &QTimer::timeout, this, [this]() {
            // Skip if a check is already in progress or JobManager is busy
            if (m_nodeCheckInProgress || m_jobManager->isBusy()) {
                return;
            }
            
            // Skip if we checked recently (within last 15 seconds)
            if (m_lastNodeCheck.isValid() && 
                m_lastNodeCheck.msecsTo(QDateTime::currentDateTime()) < 15000) {
                return;
            }
            
            m_nodeCheckInProgress = true;
            m_lastNodeCheck = QDateTime::currentDateTime();
            
            auto *job = m_jobManager->checkNodeReady("vip", 3);
            
            connect(job, &Async::JobBase::finished, this, [this, job](bool success) {
                bool ready = success ? job->result() : false;
                
                if (ready != m_nodeOnline) {
                    qDebug() << "[InstalledAsyncBase] Node status changed:" << m_nodeOnline << "->" << ready;
                    m_nodeOnline = ready;
                    onNodeStatusChanged(ready);
                    
                    // Only trigger status update if node comes online
                    if (ready) {
                        QTimer::singleShot(2000, this, &InstalledAsyncBase::performCachedStatusUpdate);
                    }
                }
                
                m_nodeCheckInProgress = false;
                job->deleteLater();
            });
        });
        
        nodeTimer->start(30000); // 30 seconds
        
        qDebug() << "[InstalledAsyncBase] Node monitoring enabled with JobManager";
    }
}

/* ------------ Initialize file monitoring with MD5 ----------- */
template<class TI,class TD>
void InstalledAsyncBase<TI,TD>::initializeFileMonitoring()
{
    const QString jf = folderRoot() + "installed"
                    + QString(fileName()).remove("vehicle-") + "s.json";
    m_watchedFilePath = jf;
    
    qDebug() << "[InstalledAsyncBase] Initializing file monitoring:" << jf;
    
    // Calculate initial hash
    m_lastFileHash = calculateFileHash(jf);
    m_isBootup = m_lastFileHash.isEmpty();
    
    // Start hash checking timer
    m_fileHashTimer->start();
    
    // Simplified legacy thread for compatibility
    m_checkThread = new InstalledCheckThread(static_cast<TD*>(this), jf, this);
    connect(m_checkThread, &InstalledCheckThread::resultReady,
            static_cast<TD*>(this), &TD::handleResults,
            Qt::QueuedConnection);
    m_checkThread->start();
}

/* ------------ Initialize VSS model monitoring with MD5 -- */
template<class TI,class TD>
void InstalledAsyncBase<TI,TD>::initializeVSSModelMonitoring()
{
    m_vssModelPath = getVSSModelPath();
    
    qDebug() << "[InstalledAsyncBase] Initializing VSS model monitoring:" << m_vssModelPath;
    
    // Calculate initial hash
    m_lastVSSModelHash = calculateFileHash(m_vssModelPath);
    
    // Start VSS model hash checking timer with a delay to allow system to settle
    QTimer::singleShot(5000, this, [this]() {
        if (m_vssModelTimer) {
            m_vssModelTimer->start();
            qDebug() << "[InstalledAsyncBase] VSS model monitoring timer started after 5s delay";
        }
    });
    
    // Initial notification if file exists
    if (!m_lastVSSModelHash.isEmpty()) {
        NOTIFY_INFO("VSS Model", "VSS model monitoring started - watching for changes");
    }
}

/* ------------ Get VSS model file path ------------------- */
template<class TI,class TD>
QString InstalledAsyncBase<TI,TD>::getVSSModelPath() const
{
    // Check if we're running in a container (DK_CONTAINER_ROOT is set)
    if (!DK_CONTAINER_ROOT.isEmpty()) {
        // Container environment - use mounted path
        QString containerPath = DK_CONTAINER_ROOT + "sdv-runtime/vss.json";
        qDebug() << "[InstalledAsyncBase] Container VSS model path:" << containerPath;
        return containerPath;
    }
    
    // Check environment variable override
    QString envPath = qEnvironmentVariable("VSS_MODEL_PATH");
    if (!envPath.isEmpty()) {
        qDebug() << "[InstalledAsyncBase] Using VSS_MODEL_PATH:" << envPath;
        return envPath;
    }
    
    // Fallback to home directory (for native/development execution)
    QString homePath = QStandardPaths::writableLocation(QStandardPaths::HomeLocation);
    QString fallbackPath = homePath + "/.dk/sdv-runtime/vss.json";
    qDebug() << "[InstalledAsyncBase] Using fallback VSS model path:" << fallbackPath;
    return fallbackPath;
}

/* ------------ VSS model hash change handler ------------- */
template<class TI,class TD>
void InstalledAsyncBase<TI,TD>::onVSSModelHashChanged()
{
    QString currentHash = calculateFileHash(m_vssModelPath);
    
    // Check if file was created (from non-existent to existing)
    if (m_lastVSSModelHash.isEmpty() && !currentHash.isEmpty()) {
        m_lastVSSModelHash = currentHash;
        qDebug() << "[InstalledAsyncBase] VSS model file created:" << m_vssModelPath;
        NOTIFY_INFO("VSS Model", "VSS model file detected and monitoring started");
        return;
    }
    
    // Check if file was deleted (from existing to non-existent)
    if (!m_lastVSSModelHash.isEmpty() && currentHash.isEmpty()) {
        m_lastVSSModelHash = currentHash;
        qDebug() << "[InstalledAsyncBase] VSS model file deleted:" << m_vssModelPath;
        NOTIFY_INFO("VSS Model", "VSS model file removed - monitoring continues");
        return;
    }
    
    // Check for changes during runtime (both hashes non-empty and different)
    if (!currentHash.isEmpty() && currentHash != m_lastVSSModelHash) {
        qDebug() << "[InstalledAsyncBase] VSS model file changed - triggering handler";
        
        m_lastVSSModelHash = currentHash;
        handleVSSModelChange();
    }
}

/* ------------ Handle VSS model change ------------------- */
template<class TI,class TD>
void InstalledAsyncBase<TI,TD>::handleVSSModelChange()
{
    qDebug() << "[InstalledAsyncBase] Processing VSS model change";
    
    // Delay the processing slightly to ensure file write is complete
    QTimer::singleShot(1000, this, [this]() {
        try {
            // Read and validate the VSS model file
            QFile vssFile(m_vssModelPath);
            if (!vssFile.exists()) {
                NOTIFY_INFO("VSS Model", "VSS model file was removed");
                return;
            }
            
            if (!vssFile.open(QIODevice::ReadOnly)) {
                qWarning() << "[InstalledAsyncBase] Failed to open VSS model file:" << m_vssModelPath;
                NOTIFY_INFO("VSS Model", "VSS model file changed but could not be read");
                return;
            }
            
            // Try to parse as JSON to validate format
            QByteArray jsonData = vssFile.readAll();
            vssFile.close();
            
            QJsonParseError parseError;
            QJsonDocument doc = QJsonDocument::fromJson(jsonData, &parseError);
            
            if (parseError.error != QJsonParseError::NoError) {
                qWarning() << "[InstalledAsyncBase] Invalid JSON in VSS model file:" << parseError.errorString();
                NOTIFY_INFO("VSS Model", "VSS model file updated but contains invalid JSON");
                return;
            }
            
            // Successfully parsed - notify about the change
            QDateTime now = QDateTime::currentDateTime();
            QString timestamp = now.toString("hh:mm:ss");
            
            NOTIFY_INFO("VSS Model", QString("VSS model updated successfully at %1").arg(timestamp));
            
            qDebug() << "[InstalledAsyncBase] VSS model file processed successfully";
            
        } catch (const std::exception &e) {
            qWarning() << "[InstalledAsyncBase] Exception handling VSS model change:" << e.what();
            NOTIFY_INFO("VSS Model", "VSS model change detected but processing failed");
        }
    });
}

/* ------------ Initialize status caching system -------------- */
template<class TI,class TD>
void InstalledAsyncBase<TI,TD>::initializeStatusCaching()
{
    qDebug() << "[InstalledAsyncBase] Initializing status caching system";
    
    // Initialize cache for current items
    {
        QMutexLocker locker(&m_cacheMutex);
        m_deploymentStatusCache.clear();
        for (const auto &item : m_items) {
            m_deploymentStatusCache[item.id] = DeploymentStatus(item.id);
        }
    }
    
    // Perform initial status update after a short delay
    QTimer::singleShot(3000, this, &InstalledAsyncBase::performCachedStatusUpdate);
}

/* ------------ Calculate file hash ---------------------------- */
template<class TI,class TD>
QString InstalledAsyncBase<TI,TD>::calculateFileHash(const QString &filePath)
{
    QFile file(filePath);
    if (!file.exists() || !file.open(QIODevice::ReadOnly)) {
        return QString();
    }
    
    QCryptographicHash hash(QCryptographicHash::Md5);
    hash.addData(file.readAll());
    return QString(hash.result().toHex());
}

/* ------------ File hash change handler ---------------------- */
template<class TI,class TD>
void InstalledAsyncBase<TI,TD>::onFileHashChanged()
{
    QString currentHash = calculateFileHash(m_watchedFilePath);
    
    // Handle bootup case
    if (m_isBootup) {
        if (!currentHash.isEmpty()) {
            m_lastFileHash = currentHash;
            m_isBootup = false;
            qDebug() << "[InstalledAsyncBase] Bootup: File detected";
            
            QTimer::singleShot(1000, this, [this]() {
                initInstalledFromDB();
            });
        }
        return;
    }
    
    // Check for changes during runtime
    if (currentHash != m_lastFileHash) {
        qDebug() << "[InstalledAsyncBase] File hash changed - triggering reload";
        
        m_lastFileHash = currentHash;
        invalidateStatusCache();
        
        QTimer::singleShot(500, this, [this]() {
            auto *job = new Async::Job<QJsonArray>([=]() -> QJsonArray {
                QThread::msleep(200);
                DataManager dm; 
                return dm.load(dbKey());
            }, this);
            
            connect(job, &Async::JobBase::finished, this, [this, job](bool success) {
                if (success) {
                    updateInstalledList(job->result());
                    initializeStatusCaching();
                }
                job->deleteLater();
            });
        });
    }
}

/* ------------ Manual status refresh -------------------------- */
template<class TI,class TD>
void InstalledAsyncBase<TI,TD>::refreshServiceStatus()
{
    qDebug() << "[InstalledAsyncBase] Manual status refresh requested";
    invalidateStatusCache();
    performCachedStatusUpdate();
}

/* ------------ Enhanced cached status update ------------------ */
template<class TI,class TD>
void InstalledAsyncBase<TI,TD>::performCachedStatusUpdate()
{
    if (m_statusUpdateInProgress || m_items.isEmpty() || !m_autoStatusUpdatesEnabled) {
        return;
    }
    
    // Check if JobManager is busy with more important operations
    if (m_jobManager->isBusy()) {
        auto state = m_jobManager->currentState();
        if (state == K3s::JobManager::State::Installing || 
            state == K3s::JobManager::State::Deploying ||
            state == K3s::JobManager::State::Removing) {
            qDebug() << "[InstalledAsyncBase] Skipping status update - JobManager busy";
            return;
        }
    }
    
    // Check if we have valid cached data first
    bool hasValidCache = false;
    {
        QMutexLocker locker(&m_cacheMutex);
        for (const auto &item : m_items) {
            if (m_deploymentStatusCache.contains(item.id) && 
                m_deploymentStatusCache[item.id].isCacheValid(CACHE_VALIDITY_DURATION)) {
                hasValidCache = true;
                break;
            }
        }
    }
    
    if (hasValidCache) {
        applyStatusUpdatesToUI();
        return;
    }
    
    qDebug() << "[InstalledAsyncBase] Performing status update for" << m_items.size() << "items";
    m_statusUpdateInProgress = true;
    
    // Use JobManager for deployment status checks
    auto *job = new Async::Job<void>([this]() -> bool {
        this->updateDeploymentStatusCache();
        return true;
    }, this);
    
    connect(job, &Async::JobBase::finished, this, [this, job](bool success) {
        if (success) {
            applyStatusUpdatesToUI();
            NOTIFY_SUCCESS("Service Status", "Vehical App/Service page reloaded successfully");
        }
        m_statusUpdateInProgress = false;
        job->deleteLater();
    });
}

/* ------------ Update deployment status cache ----------------- */
template<class TI,class TD>
void InstalledAsyncBase<TI,TD>::updateDeploymentStatusCache()
{
    QMutexLocker locker(&m_cacheMutex);
    QDateTime now = QDateTime::currentDateTime();
    
    for (const auto &item : m_items) {
        if (!m_deploymentStatusCache.contains(item.id)) {
            m_deploymentStatusCache[item.id] = DeploymentStatus(item.id);
        }
        
        DeploymentStatus &status = m_deploymentStatusCache[item.id];
        
        // Skip if cache is still valid
        if (status.isCacheValid(CACHE_VALIDITY_DURATION)) {
            continue;
        }
        
        // Skip if we've had too many consecutive failures
        if (status.consecutiveFailures >= MAX_CONSECUTIVE_FAILURES) {
            if (status.lastChecked.isValid() && 
                status.lastChecked.msecsTo(now) < 60000) {
                continue;
            }
        }
        
        // Use JobManager for status check (lightweight operation)
        bool isRunning = false;
        try {
            // Create temporary event loop for synchronous check
            auto *checkJob = m_jobManager->checkDeploymentAvailable(item.id, 5);
            QEventLoop loop;
            
            connect(checkJob, &Async::JobBase::finished, &loop, [&](bool success) {
                if (success) {
                    isRunning = checkJob->result();
                }
                loop.quit();
            });
            
            loop.exec();
            checkJob->deleteLater();
            
            // Update cache
            bool statusChanged = (status.isRunning != isRunning);
            if (statusChanged) {
                status.lastStatusChange = now;
                qDebug() << "[InstalledAsyncBase] Status changed for" << item.id 
                         << ":" << status.isRunning << "->" << isRunning;
            }
            
            status.isRunning = isRunning;
            status.lastChecked = now;
            status.hasValidCache = true;
            status.consecutiveFailures = 0;
            
        } catch (const std::exception &e) {
            qWarning() << "[InstalledAsyncBase] Exception checking status for" 
                       << item.id << ":" << e.what();
            status.consecutiveFailures++;
            status.lastChecked = now;
            status.hasValidCache = false;
        }
        
        QThread::msleep(100); // Brief pause between checks
    }
}

/* ------------ Apply status updates to UI -------------------- */
template<class TI,class TD>
void InstalledAsyncBase<TI,TD>::applyStatusUpdatesToUI()
{
    QMutexLocker locker(&m_cacheMutex);
    
    int updatedCount = 0;
    for (int i = 0; i < m_items.size(); ++i) {
        const auto &item = m_items[i];
        
        if (m_deploymentStatusCache.contains(item.id)) {
            const DeploymentStatus &status = m_deploymentStatusCache[item.id];
            
            if (status.hasValidCache) {
                static_cast<TD*>(this)->updateServicesRunningSts(
                    item.id, status.isRunning, i);
                updatedCount++;
            }
        }
    }
    
    if (updatedCount > 0) {
        qDebug() << "[InstalledAsyncBase] Applied status updates to UI for" 
                 << updatedCount << "items";
    }
}

/* ------------ Invalidate status cache ------------------------ */
template<class TI,class TD>
void InstalledAsyncBase<TI,TD>::invalidateStatusCache()
{
    QMutexLocker locker(&m_cacheMutex);
    for (auto &status : m_deploymentStatusCache) {
        status.hasValidCache = false;
        status.lastChecked = QDateTime();
    }
}

/* ------------ Check if operation can be performed ------------ */
template<class TI,class TD>
bool InstalledAsyncBase<TI,TD>::canPerformOperation(const QString &operation) const
{
    // First check local operation lock
    {
        QMutexLocker locker(&m_operationMutex);
        if (m_operationInProgress) {
            QString reason = QString("Service operation in progress: %1 (requested: %2)")
                .arg(m_currentLocalOperation, operation);
            NOTIFY_WARNING("Service Status", reason);
            qDebug() << "[InstalledAsyncBase]" << reason;
            return false;
        }
    }
    
    // Then check JobManager state
    if (m_jobManager->isBusy()) {
        QString reason = QString("System busy: %1").arg(m_jobManager->currentOperation());
        NOTIFY_WARNING("Service Status", reason);
        return false;
    }
    
    return true;
}

// these helper methods for operation management:
template<class TI,class TD>
bool InstalledAsyncBase<TI,TD>::tryAcquireLocalOperation(const QString &operation)
{
    QMutexLocker locker(&m_operationMutex);
    if (m_operationInProgress) {
        return false;
    }
    
    m_operationInProgress = true;
    m_currentLocalOperation = operation;
    qDebug() << "[InstalledAsyncBase] Local operation acquired:" << operation;
    return true;
}

template<class TI,class TD>
void InstalledAsyncBase<TI,TD>::releaseLocalOperation()
{
    QMutexLocker locker(&m_operationMutex);
    QString completedOperation = m_currentLocalOperation;
    m_operationInProgress = false;
    m_currentLocalOperation.clear();
    qDebug() << "[InstalledAsyncBase] Local operation released:" << completedOperation;
}

/* ------------ cleanup monitoring ----------------------------- */
template<class TI,class TD>
void InstalledAsyncBase<TI,TD>::cleanupMonitoring()
{
    if (m_fileHashTimer) {
        m_fileHashTimer->stop();
    }
    
    // Cleanup VSS model monitoring
    if (m_vssModelTimer) {
        m_vssModelTimer->stop();
    }
    
    if (m_wlanMonitor) {
        m_wlanMonitor->stopMonitoring();
    }
}

/* ------------ status accessors ------------------------------- */
template<class TI,class TD>
bool InstalledAsyncBase<TI,TD>::workerNodeOnline() const
{
    return m_nodeOnline;
}

template<class TI,class TD>
bool InstalledAsyncBase<TI,TD>::wlanConnected() const
{
    return m_wlanOnline;
}

/* ------------ DB reload -------------------------------------- */
template<class TI,class TD>
void InstalledAsyncBase<TI,TD>::initInstalledFromDB()
{
    emit static_cast<TD*>(this)->clearServicesListView();
    m_items.clear();
    invalidateStatusCache();
    
    DataManager dm;
    updateInstalledList(dm.load(dbKey()));
}

/* ------------ rebuild model & notify QML -------------------- */
template<class TI,class TD>
void InstalledAsyncBase<TI,TD>::updateInstalledList(const QJsonArray &arr)
{
    emit static_cast<TD*>(this)->clearServicesListView();
    m_items.clear();

    for (auto v : arr) {
        if(!v.isObject()) continue;
        auto o = v.toObject();

        TI it;
        it.id          = o.value("id").toString();
        it.name        = o.value("name").toString();
        it.author      = o.value("author").toString();
        it.rating      = o.value("rating").toString();
        it.iconPath    = o.value("thumbnail").toString();
        it.isInstalled = true;
        it.isSubscribed= o.value("subscribed").toBool();

        m_items.append(it);
        appendItemToQml(it);
    }

    static_cast<TD*>(this)->appendLastRowToServicesList(m_items.size());
}

/* ------------ Legacy file watcher slot ---------------------- */
template<class TI,class TD>
void InstalledAsyncBase<TI,TD>::fileChanged(const QString& filePath)
{
    Q_UNUSED(filePath)
    // MD5 system handles the real work now
}

/* ------------ shared editor launcher ------------------------- */
template<class TI,class TD>
void InstalledAsyncBase<TI,TD>::launchVsCode(int idx)
{
    if (idx < 0 || idx >= m_items.size()) return;
    const QString folder = folderRoot() + m_items[idx].id;
    const QString data   = folderRoot() + "vscode_user_data";
    const QString cmd =
        "mkdir -p " + data + "; "
        "code " + folder + " --no-sandbox --user-data-dir=" + data + ";";
    qDebug() << cmd;
    std::system(cmd.toUtf8().constData());
}

/* ------------ Enhanced (un)deploy via JobManager ------------ */
template<class TI,class TD>
void InstalledAsyncBase<TI,TD>::executeServices(
        int idx, const QString&, const QString id, bool subscribe)
{
    if (idx < 0 || idx >= m_items.size()) return;

    const QString operation = QString("%1 %2").arg(subscribe ? "Deploy" : "Stop", id);
    
    // Check if we can perform the operation (includes both local and JobManager checks)
    if (!canPerformOperation(operation)) {
        return;
    }
    
    // Try to acquire local operation lock
    if (!tryAcquireLocalOperation(operation)) {
        NOTIFY_WARNING("Service Status", "Another service operation is already in progress");
        return;
    }

    qDebug() << "[InstalledAsyncBase] executeServices called for" << id << "subscribe:" << subscribe;

    // Prepare deployment info for JobManager
    K3s::JobManager::DeploymentInfo deployInfo;
    deployInfo.id = id;
    deployInfo.name = m_items[idx].name;
    deployInfo.deploymentYaml = deploymentYaml(id);
    deployInfo.subscribe = subscribe;

    // Use JobManager for deployment
    auto *job = m_jobManager->deployService(deployInfo);
    
    connect(job, &Async::JobBase::finished, this, [this, idx, id, subscribe, job, operation](bool success) {
        if (success) {
            K3s::JobManager::JobResult result = job->result();
            
            if (result.success) {
                // Update local model
                if (idx < m_items.size()) {  // Safety check
                    m_items[idx].isSubscribed = subscribe;
                }
                
                // Update status cache immediately
                {
                    QMutexLocker locker(&m_cacheMutex);
                    if (m_deploymentStatusCache.contains(id)) {
                        m_deploymentStatusCache[id].isRunning = subscribe;
                        m_deploymentStatusCache[id].lastChecked = QDateTime::currentDateTime();
                        m_deploymentStatusCache[id].lastStatusChange = QDateTime::currentDateTime();
                        m_deploymentStatusCache[id].consecutiveFailures = 0;
                        m_deploymentStatusCache[id].hasValidCache = true;
                    }
                }
                
                // Apply immediate UI update
                static_cast<TD*>(this)->updateServicesRunningSts(id, subscribe, idx);
                
                m_checkThread->triggerCheckAppStart(id, m_items[idx].name);
                m_checkThread->notifyState(true);
                
                // Schedule verification after deployment settles
                QTimer::singleShot(5000, this, &InstalledAsyncBase::performCachedStatusUpdate);
            } else {
                m_checkThread->notifyState(false);
                qWarning() << "[InstalledAsyncBase] Service deployment failed:" << result.errorMessage;
            }
        } else {
            qWarning() << "[InstalledAsyncBase] Service deployment job failed for:" << id;
        }
        
        // Always release the local operation lock
        releaseLocalOperation();
        job->deleteLater();
    });
}

/* ------------ remove via JobManager ------------------------- */
template<class TI,class TD>
void InstalledAsyncBase<TI,TD>::removeServices(int idx)
{
    if (idx < 0 || idx >= m_items.size()) return;

    const QString id = m_items[idx].id;
    const QString operation = QString("Remove %1").arg(id);
    
    // Check if we can perform the operation
    if (!canPerformOperation(operation)) {
        return;
    }
    
    // Try to acquire local operation lock
    if (!tryAcquireLocalOperation(operation)) {
        NOTIFY_WARNING("Service Status", "Another service operation is already in progress");
        return;
    }

    const QString yaml = deploymentYaml(id);
    qDebug() << "[InstalledAsyncBase] Removing service:" << id;

    // Use JobManager for removal
    auto *job = m_jobManager->removeService(id, yaml);
    
    connect(job, &Async::JobBase::finished, this, [this, idx, id, job, operation](bool success) {
        bool removalSuccess = false;
        
        if (success) {
            K3s::JobManager::JobResult result = job->result();
            removalSuccess = result.success;
            
            if (removalSuccess) {
                // Update database synchronously in a separate thread to avoid blocking
                auto *dbUpdateJob = new Async::Job<bool>([this, id]() -> bool {
                    try {
                        DataManager dm;
                        QJsonArray in = dm.load(dbKey()), out;
                        for (auto v : in) {
                            if (v.toObject().value("id").toString() != id) {
                                out.append(v);
                            }
                        }
                        dm.save(dbKey(), out);
                        return true;
                    } catch (const std::exception &e) {
                        qWarning() << "[InstalledAsyncBase] DB update failed:" << e.what();
                        return false;
                    }
                }, this);
                
                connect(dbUpdateJob, &Async::JobBase::finished, this, [this, id, dbUpdateJob, operation](bool dbSuccess) {
                    if (dbSuccess) {
                        // Remove from status cache after successful DB update
                        {
                            QMutexLocker locker(&m_cacheMutex);
                            m_deploymentStatusCache.remove(id);
                        }
                        
                        // Update UI after successful database update
                        QTimer::singleShot(50, this, [this]() {
                            initInstalledFromDB();
                        });
                        
                        NOTIFY_SUCCESS("Removal", QString("%1 removed successfully").arg(id));
                    } else {
                        NOTIFY_ERROR("Removal", QString("Failed to update database for %1").arg(id));
                    }
                    
                    // CRITICAL: Release operation lock only after everything is complete
                    releaseLocalOperation();
                    dbUpdateJob->deleteLater();
                });
                
            } else {
                NOTIFY_ERROR("Removal", QString("Failed to remove %1: %2").arg(id, result.errorMessage));
                // Release lock immediately on failure
                releaseLocalOperation();
            }
        } else {
            NOTIFY_ERROR("Removal", QString("Failed to remove %1: Job execution failed").arg(id));
            // Release lock immediately on failure
            releaseLocalOperation();
        }
        
        job->deleteLater();
    });
}

/* ------------ restart methods (delegate to AutoRestartManager) */
template<class TI,class TD>
void InstalledAsyncBase<TI,TD>::restartSdvRuntime()
{
    if (m_autoRestartMgr) {
        m_autoRestartMgr->restartSdvRuntime();
    } else {
        NOTIFY_WARNING("Restart Service", "Auto-restart manager not available");
    }
}

template<class TI,class TD>
void InstalledAsyncBase<TI,TD>::restartApplication()
{
    if (m_autoRestartMgr) {
        m_autoRestartMgr->restartApplication();
    } else {
        NOTIFY_WARNING("Restart Service", "Auto-restart manager not available");
    }
}

template<class TI,class TD>
void InstalledAsyncBase<TI,TD>::forceRestartBoth()
{
    if (m_autoRestartMgr) {
        m_autoRestartMgr->forceRestartBoth();
    } else {
        NOTIFY_WARNING("Restart Service", "Auto-restart manager not available");
    }
}

/* ------------ status change handlers -------------------------- */
template<class TI,class TD>
void InstalledAsyncBase<TI,TD>::onNodeStatusChanged(bool online)
{
    if (online) {
        NOTIFY_SUCCESS("ZonalECU","VIP (Vehicle Integration Platform) ~ ONLINE");
        QTimer::singleShot(3000, this, &InstalledAsyncBase::performCachedStatusUpdate);
    } else {
        NOTIFY_WARNING("ZonalECU","VIP (Vehicle Integration Platform) ~ OFFLINE");
        invalidateStatusCache();
    }
    static_cast<TD*>(this)->workerNodeStatusChanged(online);
}

template<class TI,class TD>
void InstalledAsyncBase<TI,TD>::onWlanStatusChanged(bool connected)
{
    bool wasConnected = m_wlanOnline;
    m_wlanOnline = connected;
    
    if (wasConnected != connected) {
        if (connected) {
            QTimer::singleShot(2000, this, &InstalledAsyncBase::performCachedStatusUpdate);
        } else {
            NOTIFY_WARNING("Internet", "Connection lost - services may be affected");
            invalidateStatusCache();
        }
    }
}

template<class TI,class TD>
void InstalledAsyncBase<TI,TD>::onJobManagerStateChanged(K3s::JobManager::State state)
{
    // Pause status updates during critical operations
    m_autoStatusUpdatesEnabled = (state == K3s::JobManager::State::Idle ||
                                  state == K3s::JobManager::State::Checking);
}

template<class TI,class TD>
void InstalledAsyncBase<TI,TD>::onJobFinished(const QString &operation, bool success, const QString &message)
{
    qDebug() << "[InstalledAsyncBase] Job finished:" << operation 
             << "Success:" << success << "Message:" << message;
    
    // Trigger status update for deployment-related operations
    if (success && (operation.contains("deploy") || operation.contains("Deploy"))) {
        QTimer::singleShot(2000, this, &InstalledAsyncBase::performCachedStatusUpdate);
    }
}