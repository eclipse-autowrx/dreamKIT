// Copyright (c) 2025 Eclipse Foundation.
// 
// This program and the accompanying materials are made available under the
// terms of the MIT License which is available at
// https://opensource.org/licenses/MIT.
// 
// SPDX-License-Identifier: MIT
#pragma once
#include <QObject>
#include <QTimer>
#include <QCoreApplication>
#include <memory>
#include "../monitoring/wlanmonitor.hpp"
#include "../integrations/kubernetes/jobmanager.hpp"
#include "../async/asyncjob.hpp"

/**
 * @brief Manages automatic restart functionality when internet connection is restored
 * 
 * This class encapsulates the auto-restart logic that was previously embedded
 * in InstalledAsyncBase template class, providing a clean interface for
 * managing service restarts.
 */
class AutoRestartManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool enabled READ isEnabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(bool restartInProgress READ isRestartInProgress NOTIFY restartInProgressChanged)
    Q_PROPERTY(int restartCycleLimit READ restartCycleLimit WRITE setRestartCycleLimit NOTIFY restartCycleLimitChanged)
    Q_PROPERTY(int restartDelay READ restartDelay WRITE setRestartDelay NOTIFY restartDelayChanged)
    
public:
    explicit AutoRestartManager(QObject *parent = nullptr);
    ~AutoRestartManager();
    
    // Configuration
    bool isEnabled() const { return m_enabled; }
    void setEnabled(bool enabled);
    
    int restartCycleLimit() const { return m_restartCycleLimit; }
    void setRestartCycleLimit(int limit);
    
    int restartDelay() const { return m_restartDelay; }
    void setRestartDelay(int delayMs);
    
    // Status
    bool isRestartInProgress() const { return m_restartInProgress; }
    int currentRestartCycle() const { return m_restartCycleCount; }
    
    // Dependencies injection
    void setWlanMonitor(WlanMonitor *monitor);
    void setJobManager(K3s::JobManager *jobManager);
    
public slots:
    // Manual restart methods
    void restartSdvRuntime();
    void restartApplication(); 
    void forceRestartBoth();
    void resetRestartCycleCount();
    
signals:
    void enabledChanged(bool enabled);
    void restartInProgressChanged(bool inProgress);
    void restartCycleLimitChanged(int limit);
    void restartDelayChanged(int delayMs);
    void restartStarted(const QString &reason);
    void restartCompleted(bool success, const QString &message);
    void restartCycleLimitReached();
    
private slots:
    void onConnectionRestored();
    void onAutoRestartFinished(bool success);
    void performDelayedAutoRestart();
    
private:
    void triggerAutoRestart();
    void performApplicationRestart();
    void saveStateBeforeRestart();
    bool checkInternetRequired(const QString &operation);
    
    WlanMonitor *m_wlanMonitor;
    K3s::JobManager *m_jobManager;
    QTimer *m_restartDelayTimer;
    
    bool m_enabled;
    bool m_restartInProgress;
    int m_restartCycleLimit;
    int m_restartCycleCount;
    int m_restartDelay;
    
    QString m_currentOperation;
    Async::Chain *m_currentRestartChain;
    
    // Default configuration
    static constexpr int DEFAULT_RESTART_CYCLE_LIMIT = 3;
    static constexpr int DEFAULT_RESTART_DELAY = 2000; // 2 seconds
};