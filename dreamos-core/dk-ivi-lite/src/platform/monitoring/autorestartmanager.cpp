// Copyright (c) 2025 Eclipse Foundation.
// 
// This program and the accompanying materials are made available under the
// terms of the MIT License which is available at
// https://opensource.org/licenses/MIT.
// 
// SPDX-License-Identifier: MIT
#include "autorestartmanager.hpp"
#include <QDebug>
#include <QProcess>
#include <QThread>
#include <QJsonObject>
#include <QJsonArray>
#include <QDateTime>
#include "../data/datamanager.hpp"
#include "../notifications/notificationmanager.hpp"

AutoRestartManager::AutoRestartManager(QObject *parent)
    : QObject(parent)
    , m_wlanMonitor(nullptr)
    , m_jobManager(nullptr)
    , m_restartDelayTimer(new QTimer(this))
    , m_enabled(true)
    , m_restartInProgress(false)
    , m_restartCycleLimit(DEFAULT_RESTART_CYCLE_LIMIT)
    , m_restartCycleCount(0)
    , m_restartDelay(DEFAULT_RESTART_DELAY)
    , m_currentRestartChain(nullptr)
{
    // Configure delay timer
    m_restartDelayTimer->setSingleShot(true);
    connect(m_restartDelayTimer, &QTimer::timeout,
            this, &AutoRestartManager::performDelayedAutoRestart);
}

AutoRestartManager::~AutoRestartManager()
{
    if (m_currentRestartChain) {
        m_currentRestartChain->deleteLater();
    }
}

void AutoRestartManager::setEnabled(bool enabled)
{
    if (m_enabled == enabled) {
        return;
    }
    
    m_enabled = enabled;
    emit enabledChanged(m_enabled);
    
    qDebug() << "[AutoRestartManager] Auto-restart" << (enabled ? "enabled" : "disabled");
}

void AutoRestartManager::setRestartCycleLimit(int limit)
{
    if (limit <= 0) {
        qWarning() << "[AutoRestartManager] Invalid restart cycle limit:" << limit;
        return;
    }
    
    if (m_restartCycleLimit == limit) {
        return;
    }
    
    m_restartCycleLimit = limit;
    emit restartCycleLimitChanged(m_restartCycleLimit);
    
    qDebug() << "[AutoRestartManager] Restart cycle limit set to:" << limit;
}

void AutoRestartManager::setRestartDelay(int delayMs)
{
    if (delayMs < 0) {
        qWarning() << "[AutoRestartManager] Invalid restart delay:" << delayMs;
        return;
    }
    
    if (m_restartDelay == delayMs) {
        return;
    }
    
    m_restartDelay = delayMs;
    emit restartDelayChanged(m_restartDelay);
    
    qDebug() << "[AutoRestartManager] Restart delay set to:" << delayMs << "ms";
}

void AutoRestartManager::setWlanMonitor(WlanMonitor *monitor)
{
    if (m_wlanMonitor == monitor) {
        return;
    }
    
    // Disconnect old monitor
    if (m_wlanMonitor) {
        disconnect(m_wlanMonitor, &WlanMonitor::connectionRestored,
                   this, &AutoRestartManager::onConnectionRestored);
    }
    
    m_wlanMonitor = monitor;
    
    // Connect new monitor
    if (m_wlanMonitor) {
        connect(m_wlanMonitor, &WlanMonitor::connectionRestored,
                this, &AutoRestartManager::onConnectionRestored);
        qDebug() << "[AutoRestartManager] WLAN monitor connected";
    }
}

void AutoRestartManager::setJobManager(K3s::JobManager *jobManager)
{
    m_jobManager = jobManager;
    if (m_jobManager) {
        qDebug() << "[AutoRestartManager] Job manager connected";
    }
}

void AutoRestartManager::restartSdvRuntime()
{
    if (!checkInternetRequired("SDV Runtime restart")) {
        return;
    }
    
    if (!m_jobManager) {
        qWarning() << "[AutoRestartManager] No job manager available for SDV restart";
        return;
    }
    
    m_currentOperation = "Manual SDV Runtime Restart";
    emit restartStarted(m_currentOperation);
    
    NOTIFY_INFO("SDV Runtime", "Manually restarting SDV runtime deployment...");
    qDebug() << "[AutoRestartManager] Starting manual SDV restart";
    
    auto *job = m_jobManager->restartDeployment("sdv-runtime");
    
    connect(job, &Async::JobBase::finished, this, [this](bool success) {
        const QString message = success 
            ? "SDV runtime deployment restart initiated"
            : "Failed to restart SDV runtime deployment";
            
        emit restartCompleted(success, message);
        
        if (success) {
            NOTIFY_SUCCESS("SDV Runtime", message);
        } else {
            NOTIFY_ERROR("SDV Runtime", message);
        }
    });
    
    connect(job, &Async::JobBase::finished, job, &QObject::deleteLater);
}

void AutoRestartManager::restartApplication()
{
    if (!checkInternetRequired("Application restart")) {
        return;
    }
    
    m_currentOperation = "Manual Application Restart";
    emit restartStarted(m_currentOperation);
    
    NOTIFY_INFO("Application", "Manually restarting sdv-runtime application in 3 seconds...");
    qDebug() << "[AutoRestartManager] Manual application restart requested";
    
    QTimer::singleShot(3000, this, [this]() {
        this->performApplicationRestart();
    });
}

void AutoRestartManager::forceRestartBoth()
{
    if (!checkInternetRequired("Force restart")) {
        return;
    }
    
    m_currentOperation = "Force Restart Both";
    emit restartStarted(m_currentOperation);
    
    NOTIFY_WARNING("Force Restart", "Force restarting both SDV runtime and application...");
    qDebug() << "[AutoRestartManager] Force restart both requested";
    
    if (!m_jobManager) {
        qWarning() << "[AutoRestartManager] No job manager available for force restart";
        emit restartCompleted(false, "No job manager available");
        return;
    }
    
    // Create a chain to restart SDV first, then application
    auto *chain = new Async::Chain(this);
    
    // Step 1: Restart SDV runtime
    chain->add([this]() -> bool {
        auto *job = m_jobManager->restartDeployment("sdv-runtime");
        QEventLoop loop;
        bool success = false;

        connect(job, &Async::JobBase::finished, &loop, [&](bool ok) {
            success = ok;
            loop.quit();
        });
        
        loop.exec();
        job->deleteLater();
        
        if (success) {
            qDebug() << "[AutoRestartManager] SDV runtime restart completed";
            QThread::msleep(5000); // Wait for SDV restart to begin
        }
        
        return success; // Continue even if SDV restart fails
    });
    
    // Step 2: Restart application (commented out as per original)
    chain->add([this]() -> bool {
        this->restartApplication();
        return true;
    });
    
    connect(chain, &Async::Chain::finished, this, [this](bool success) {
        const QString message = success 
            ? "Force restart sequence completed"
            : "Force restart completed with issues";
            
        emit restartCompleted(success, message);
        
        if (success) {
            NOTIFY_SUCCESS("Force Restart", message);
        } else {
            NOTIFY_WARNING("Force Restart", message);
        }
    });
    
    connect(chain, &Async::Chain::finished, chain, &QObject::deleteLater);
    chain->start();
}

void AutoRestartManager::resetRestartCycleCount()
{
    qDebug() << "[AutoRestartManager] Resetting restart cycle count from" << m_restartCycleCount;
    m_restartCycleCount = 0;
}

void AutoRestartManager::onConnectionRestored()
{
    if (!m_enabled) {
        qDebug() << "[AutoRestartManager] Auto-restart disabled, ignoring connection restoration";
        NOTIFY_INFO("Auto Restart", "Auto-restart is disabled");
        return;
    }
    
    if (m_restartInProgress) {
        qDebug() << "[AutoRestartManager] Restart already in progress, ignoring connection restoration";
        NOTIFY_INFO("Auto Restart", "Restart already in progress");
        return;
    }
    
    if (m_restartCycleCount >= m_restartCycleLimit) {
        qDebug() << "[AutoRestartManager] Restart cycle limit reached, ignoring connection restoration";
        NOTIFY_WARNING("Auto Restart", QString("Restart cycle limit reached (%1/%2)").arg(m_restartCycleCount).arg(m_restartCycleLimit));
        emit restartCycleLimitReached();
        return;
    }
    
    NOTIFY_INFO("Auto Restart", QString("Internet restored - scheduling SDV runtime auto-restart (cycle %1/%2)").arg(m_restartCycleCount + 1).arg(m_restartCycleLimit));
    qDebug() << "[AutoRestartManager] Connection restored, scheduling auto-restart";
    
    // Schedule delayed restart
    if (m_restartDelay > 0) {
        m_restartDelayTimer->setInterval(m_restartDelay);
        m_restartDelayTimer->start();
    } else {
        performDelayedAutoRestart();
    }
}

void AutoRestartManager::performDelayedAutoRestart()
{
    triggerAutoRestart();
}

void AutoRestartManager::triggerAutoRestart()
{
    if (m_restartInProgress) {
        qDebug() << "[AutoRestartManager] Restart already in progress, skipping";
        return;
    }
    
    if (m_restartCycleCount >= m_restartCycleLimit) {
        NOTIFY_WARNING("Auto Restart", "Restart cycle limit reached");
        qDebug() << "[AutoRestartManager] Restart cycle limit reached";
        emit restartCycleLimitReached();
        return;
    }
    
    m_restartInProgress = true;
    emit restartInProgressChanged(true);
    
    m_restartCycleCount++;
    m_currentOperation = QString("Auto Restart (Cycle %1/%2)")
        .arg(m_restartCycleCount).arg(m_restartCycleLimit);
    
    emit restartStarted(m_currentOperation);
    
    NOTIFY_INFO("Auto Restart", "Auto-restarting services due to internet restoration...");
    qDebug() << "[AutoRestartManager] Starting auto-restart sequence, cycle" 
             << m_restartCycleCount << "of" << m_restartCycleLimit;
    
    if (!m_jobManager) {
        qWarning() << "[AutoRestartManager] No job manager available for auto-restart";
        onAutoRestartFinished(false);
        return;
    }
    
    // Create and start the auto-restart chain
    m_currentRestartChain = m_jobManager->createAutoRestartChain("sdv-runtime");

    connect(m_currentRestartChain, &Async::Chain::finished,
            this, &AutoRestartManager::onAutoRestartFinished);
    
    m_currentRestartChain->start();
}

void AutoRestartManager::onAutoRestartFinished(bool success)
{
    m_restartInProgress = false;
    emit restartInProgressChanged(false);
    
    QString message;
    if (success) {
        message = QString("Auto-restart cycle %1 completed successfully")
            .arg(m_restartCycleCount);
        NOTIFY_SUCCESS("Auto Restart", "Services restart sequence completed successfully");
        qDebug() << "[AutoRestartManager] Auto-restart sequence completed successfully";
    } else {
        message = QString("Auto-restart cycle %1 completed with issues")
            .arg(m_restartCycleCount);
        NOTIFY_WARNING("Auto Restart", "Services restart sequence completed with issues");
        qDebug() << "[AutoRestartManager] Auto-restart completed with issues";
    }
    
    emit restartCompleted(success, message);
    
    // Clean up the chain
    if (m_currentRestartChain) {
        m_currentRestartChain->deleteLater();
        m_currentRestartChain = nullptr;
    }
}

void AutoRestartManager::performApplicationRestart()
{
    qDebug() << "[AutoRestartManager] Saving state and preparing application restart";
    
    // Save current state
    saveStateBeforeRestart();
    
    // Try multiple restart methods
    QString appPath = QCoreApplication::applicationFilePath();
    QStringList args = QCoreApplication::arguments();
    args.removeFirst(); // Remove program name
    
    qDebug() << "[AutoRestartManager] App path:" << appPath;
    qDebug() << "[AutoRestartManager] Args:" << args;
    
    // Method 1: Try systemctl restart (most reliable for service)
    if (QProcess::execute("systemctl", QStringList() << "is-active" << "sdv-runtime") == 0) {
        qDebug() << "[AutoRestartManager] Using systemctl restart";
        QProcess::startDetached("systemctl", QStringList() << "restart" << "sdv-runtime");
        QTimer::singleShot(1000, []() { QCoreApplication::quit(); });
        return;
    }
    
    // Method 2: Direct executable restart
    qDebug() << "[AutoRestartManager] Using direct executable restart";
    if (QProcess::startDetached(appPath, args)) {
        QTimer::singleShot(500, []() { QCoreApplication::quit(); });
    } else {
        // Method 3: Force exit and let external process manager restart
        qDebug() << "[AutoRestartManager] Force exit - relying on external restart";
        QTimer::singleShot(500, []() { 
            QCoreApplication::exit(42); // Special exit code for restart
        });
    }
}

void AutoRestartManager::saveStateBeforeRestart()
{
    try {
        DataManager dm;
        QJsonObject metadata;
        metadata["timestamp"] = QDateTime::currentDateTime().toString(Qt::ISODate);
        metadata["reason"] = m_currentOperation;
        metadata["restart_cycle"] = m_restartCycleCount;
        
        QJsonArray stateArray;
        stateArray.append(metadata);
        
        dm.save("auto_restart_state", stateArray);
        qDebug() << "[AutoRestartManager] State saved before restart";
        
    } catch (const std::exception &e) {
        qDebug() << "[AutoRestartManager] Failed to save state:" << e.what();
    }
}

bool AutoRestartManager::checkInternetRequired(const QString &operation)
{
    if (!m_wlanMonitor) {
        qDebug() << "[AutoRestartManager] No WLAN monitor, allowing" << operation;
        return true; // Allow if we can't check
    }
    
    if (!m_wlanMonitor->isConnected()) {
        NOTIFY_WARNING("Restart", "Internet connection required for " + operation.toLower());
        qDebug() << "[AutoRestartManager] Internet required for" << operation;
        return false;
    }
    
    return true;
}