// Copyright (c) 2025 Eclipse Foundation.
// 
// This program and the accompanying materials are made available under the
// terms of the MIT License which is available at
// https://opensource.org/licenses/MIT.
// 
// SPDX-License-Identifier: MIT
#include "jobmanager.hpp"
#include <QDebug>
#include <QThread>
#include <QCoreApplication>
#include <QMetaObject>
#include <QMutexLocker>
#include "../../notifications/notificationmanager.hpp"

using namespace K3s;

// Static members
QMutex JobManager::s_instanceMutex;
JobManager* JobManager::s_instance = nullptr;

JobManager::JobManager(QObject *parent)
    : QObject(parent)
    , m_installer(new Installer(this))
    , m_mainThread(QThread::currentThread())
    , m_state(State::Idle)
{
    connect(m_installer, &Installer::finished,
            this, &JobManager::onInstallerFinished);
    
    qDebug() << "[JobManager] Initialized with state management";
}

JobManager::~JobManager()
{
    QMutexLocker locker(&s_instanceMutex);
    if (s_instance == this) {
        s_instance = nullptr;
    }
}

JobManager* JobManager::instance()
{
    QMutexLocker locker(&s_instanceMutex);
    if (!s_instance) {
        if (QThread::currentThread() == qApp->thread()) {
            s_instance = new JobManager(qApp);
        } else {
            s_instance = new JobManager(nullptr);
            s_instance->moveToThread(qApp->thread());
        }
    }
    return s_instance;
}

bool JobManager::tryAcquireState(State newState, const QString &operation)
{
    QMutexLocker locker(&m_stateMutex);
    
    if (m_state != State::Idle) {
        QString reason = QString("JobManager busy with: %1 (requested: %2)")
            .arg(m_currentOperation, operation);
        qWarning() << "[JobManager]" << reason;
        emit requestRejected(reason);
        return false;
    }
    
    m_state = newState;
    m_currentOperation = operation;
    
    emit busyChanged(true);
    emit stateChanged(newState);
    emit currentOperationChanged(operation);
    emit jobStarted(operation);
    
    qDebug() << "[JobManager] State acquired:" << operation;
    return true;
}

void JobManager::releaseState()
{
    QMutexLocker locker(&m_stateMutex);
    
    QString completedOperation = m_currentOperation;
    m_state = State::Idle;
    m_currentOperation.clear();
    
    emit busyChanged(false);
    emit stateChanged(State::Idle);
    emit currentOperationChanged(QString());
    
    qDebug() << "[JobManager] State released:" << completedOperation;
}

void JobManager::setState(State newState, const QString &operation)
{
    QMutexLocker locker(&m_stateMutex);
    
    if (!operation.isEmpty()) {
        m_currentOperation = operation;
        emit currentOperationChanged(operation);
    }
    
    if (newState != m_state) {
        m_state = newState;
        emit stateChanged(newState);
        emit busyChanged(newState != State::Idle);
    }
}

template<typename T>
Async::Job<T>* JobManager::createJobSafely(std::function<T()> task)
{
    try {
        Async::Job<T>* job = nullptr;
        
        if (QThread::currentThread() == m_mainThread) {
            job = new Async::Job<T>(task, this);
        } else {
            QMetaObject::invokeMethod(this, [&]() {
                job = new Async::Job<T>(task, this);
            }, Qt::BlockingQueuedConnection);
        }
        
        return job;
        
    } catch (const std::exception &e) {
        qCritical() << "[JobManager] Exception in createJobSafely:" << e.what();
        return nullptr;
    }
}

Async::Chain* JobManager::createChainSafely()
{
    Async::Chain* chain = nullptr;
    
    if (QThread::currentThread() == m_mainThread) {
        chain = new Async::Chain(this);
    } else {
        QMetaObject::invokeMethod(this, [&]() {
            chain = new Async::Chain(this);
        }, Qt::BlockingQueuedConnection);
    }
    
    return chain;
}

Async::Job<JobManager::JobResult>* JobManager::deployService(const DeploymentInfo &info)
{
    const QString operation = QString("Deploy %1").arg(info.name);
    
    if (!tryAcquireState(State::Deploying, operation)) {
        // Return a job that immediately fails
        return createJobSafely<JobResult>([]() -> JobResult {
            JobResult result;
            result.success = false;
            result.errorMessage = "JobManager busy";
            return result;
        });
    }
    
    auto *job = createJobSafely<JobResult>([=]() -> JobResult {
        JobResult result = this->performDeployment(info);
        return result;
    });
    
    connect(job, &Async::JobBase::finished, this, [=](bool success) {
        emit jobFinished(operation, success, 
            success ? QString("Service %1 %2").arg(info.name, info.subscribe ? "deployed" : "stopped")
                   : "Deployment failed");
        releaseState();
        job->deleteLater();
    });
    
    return job;
}
    
Async::Job<JobManager::JobResult>* JobManager::removeService(const QString &id, const QString &deploymentYaml)
{
    const QString operation = QString("Remove %1").arg(id);
    
    if (!tryAcquireState(State::Removing, operation)) {
        return createJobSafely<JobResult>([]() -> JobResult {
            JobResult result;
            result.success = false;
            result.errorMessage = "JobManager busy";
            return result;
        });
    }
    
    auto *job = createJobSafely<JobResult>([=]() -> JobResult {
        JobResult result = this->performRemoval(id, deploymentYaml);
        return result;
    });
    
    connect(job, &Async::JobBase::finished, this, [=](bool success) {
        emit jobFinished(operation, success && job->result().success, 
            success && job->result().success ? QString("Service %1 removed").arg(id) : "Removal failed");
        releaseState();
        job->deleteLater();
    });
    
    return job;
}

Async::Job<JobManager::JobResult>* JobManager::restartDeployment(const QString &deploymentName)
{
    const QString operation = QString("Restart %1").arg(deploymentName);
    
    if (!tryAcquireState(State::Restarting, operation)) {
        return createJobSafely<JobResult>([]() -> JobResult {
            JobResult result;
            result.success = false;
            result.errorMessage = "JobManager busy";
            return result;
        });
    }
    
    auto *job = createJobSafely<JobResult>([=]() -> JobResult {
        JobResult result;
        
        const QString cmd = QString("kubectl rollout restart deployment/%1 -n default")
            .arg(deploymentName);
        
        result = executeCommandsSync({cmd});
        return result;
    });
    
    connect(job, &Async::JobBase::finished, this, [=](bool success) {
        const QString message = success && job->result().success
            ? QString("Restart initiated for %1").arg(deploymentName)
            : QString("Failed to restart %1").arg(deploymentName);
            
        emit jobFinished(operation, success && job->result().success, message);
        releaseState();
        job->deleteLater();
    });
    
    return job;
}

Async::Job<JobManager::JobResult>* JobManager::scaleDeployment(const QString &deploymentName, int replicas)
{
    const QString operation = QString("Scale %1 to %2 replicas").arg(deploymentName).arg(replicas);
    
    if (!tryAcquireState(State::Deploying, operation)) {
        return createJobSafely<JobResult>([]() -> JobResult {
            JobResult result;
            result.success = false;
            result.errorMessage = "JobManager busy";
            return result;
        });
    }
    
    auto *job = createJobSafely<JobResult>([=]() -> JobResult {
        JobResult result;
        
        const QString cmd = QString("kubectl scale deployment %1 --replicas=%2 -n default")
            .arg(deploymentName).arg(replicas);
        
        result = executeCommandsSync({cmd});
        return result;
    });
    
    connect(job, &Async::JobBase::finished, this, [=](bool success) {
        const QString message = success && job->result().success
            ? QString("Scaled %1 to %2 replicas").arg(deploymentName).arg(replicas)
            : QString("Failed to scale %1").arg(deploymentName);
            
        emit jobFinished(operation, success && job->result().success, message);
        releaseState();
        job->deleteLater();
    });
    
    return job;
}

Async::Job<JobManager::JobResult>* JobManager::installApplication(const InstallationRequest &request)
{
    const QString operation = QString("Install %1").arg(request.appName);
    
    if (!tryAcquireState(State::Installing, operation)) {
        return createJobSafely<JobResult>([]() -> JobResult {
            JobResult result;
            result.success = false;
            result.errorMessage = "JobManager busy - installation rejected";
            return result;
        });
    }
    
    auto *job = createJobSafely<JobResult>([=]() -> JobResult {
        JobResult result = this->performInstallation(request);
        return result;
    });
    
    connect(job, &Async::JobBase::finished, this, [=](bool success) {
        emit jobFinished(operation, success, 
            success ? QString("Application %1 installed").arg(request.appName) 
                   : "Installation failed");
        releaseState();
        job->deleteLater();
    });
    
    return job;
}

Async::Job<JobManager::JobResult>* JobManager::runCommands(const QStringList &commands, const QString &operation)
{
    const QString op = operation.isEmpty() ? "Run Commands" : operation;
    
    if (!tryAcquireState(State::Installing, op)) {
        return createJobSafely<JobResult>([]() -> JobResult {
            JobResult result;
            result.success = false;
            result.errorMessage = "JobManager busy";
            return result;
        });
    }
    
    auto *job = createJobSafely<JobResult>([=]() -> JobResult {
        JobResult result = this->executeCommandsSync(commands);
        return result;
    });
    
    connect(job, &Async::JobBase::finished, this, [=](bool success) {
        emit jobFinished(op, success, success ? "Commands executed" : "Commands failed");
        releaseState();
        job->deleteLater();
    });
    
    return job;
}

Async::Job<bool>* JobManager::checkNodeReady(const QString &nodeName, int timeoutSec)
{
    // Node checks are lightweight and don't need state management
    return createJobSafely<bool>([=]() -> bool {
        try {
            const QString cmd = QString("kubectl get node %1 --no-headers 2>/dev/null").arg(nodeName);
            JobResult result = executeCommandsSync({cmd});
            
            if (!result.success) {
                return false;
            }
            
            bool ready = result.output.contains("Ready") && !result.output.contains("NotReady");
            qDebug() << "[JobManager] Node" << nodeName << "ready:" << ready;
            return ready;
            
        } catch (const std::exception &e) {
            qWarning() << "[JobManager] Node check exception:" << e.what();
            return false;
        }
    });
}

Async::Job<bool>* JobManager::checkDeploymentAvailable(const QString &deploymentId, int timeoutSec)
{
    // Deployment checks are lightweight and don't need state management
    return createJobSafely<bool>([=]() -> bool {
        try {
            return Installer::deploymentAvailable(deploymentId, timeoutSec);
        } catch(...) {
            return false;
        }
    });
}

Async::Chain* JobManager::createAutoRestartChain(const QString &deploymentName)
{
    const QString operation = QString("Auto Restart %1").arg(deploymentName);
    
    if (!tryAcquireState(State::Restarting, operation)) {
        // Return a chain that immediately fails
        auto *chain = createChainSafely();
        chain->add([]() -> bool { return false; });
        return chain;
    }
    
    auto *chain = createChainSafely();
    auto deploymentExists = std::make_shared<bool>(false);
    
    // Step 1: Check deployment exists
    chain->add([=]() -> bool {
        *deploymentExists = this->deploymentExists(deploymentName);
        return true;
    });
    
    // Step 2: Scale down
    chain->add([=]() -> bool {
        if (!*deploymentExists) return true;
        
        const QString cmd = QString("kubectl scale deployment %1 --replicas=0 -n default")
            .arg(deploymentName);
        JobResult result = executeCommandsSync({cmd});
        return result.success;
    });
    
    // Step 3: Wait for termination
    chain->add([=]() -> bool {
        if (!*deploymentExists) return true;
        return waitForPodTermination(deploymentName, 30);
    });
    
    // Step 4: Scale up
    chain->add([=]() -> bool {
        if (!*deploymentExists) return true;
        
        QThread::sleep(3); // Brief pause
        const QString cmd = QString("kubectl scale deployment %1 --replicas=1 -n default")
            .arg(deploymentName);
        JobResult result = executeCommandsSync({cmd});
        return result.success;
    });
    
    // Step 5: Wait for ready
    chain->add([=]() -> bool {
        if (!*deploymentExists) return true;
        return waitForPodsReady(deploymentName, 60);
    });
    
    connect(chain, &Async::Chain::finished, this, [=](bool success) {
        emit jobFinished(operation, success, 
            success ? "Auto-restart completed" : "Auto-restart failed");
        releaseState();
    });
    
    return chain;
}

JobManager::JobResult JobManager::performDeployment(const DeploymentInfo &info)
{
    JobResult result;
    result.success = true;
    
    try {
        setState(State::Deploying, QString("Deploying %1").arg(info.name));
        
        if (info.subscribe) {
            // Check node ready first
            auto nodeJob = checkNodeReady("vip", 3);
            QEventLoop loop;
            bool nodeReady = false;
            
            connect(nodeJob, &Async::JobBase::finished, &loop, [&](bool success) {
                if (success) nodeReady = nodeJob->result();
                loop.quit();
            });
            
            loop.exec();
            nodeJob->deleteLater();
            
            if (!nodeReady) {
                NOTIFY_WARNING("Deployment", "ZonalECU - VIP is not ready");
            }
            
            // Force cleanup existing
            QString cleanupCmd = QString("kubectl delete deployment %1 -n default --ignore-not-found --wait=true").arg(info.id);
            executeCommandsSync({cleanupCmd});
            QThread::msleep(2000);
        }
        
        // Execute deployment
        const QString cmd = info.subscribe 
            ? QString("kubectl apply -f %1").arg(info.deploymentYaml)
            : QString("kubectl delete -f %1 --ignore-not-found").arg(info.deploymentYaml);
        
        result = executeCommandsSync({cmd});
        
        // Verify deployment if subscribing
        if (result.success && info.subscribe) {
            QString waitCmd = QString("kubectl rollout status deployment/%1 --timeout=60s").arg(info.id);
            JobResult waitResult = executeCommandsSync({waitCmd});
            
            if (!waitResult.success) {
                result.errorMessage = "Deployment applied but not ready: " + waitResult.errorMessage;
                qWarning() << "[JobManager]" << result.errorMessage;
            }
        }
        
        const QString action = info.subscribe ? "deployed" : "stopped";
        const QString message = QString("Service '%1' %2").arg(info.name, action);
        
        if (result.success) {
            NOTIFY_INFO("Deployment", message);
        } else {
            NOTIFY_ERROR("Deployment", QString("Failed to %1 %2: %3")
                .arg(action, info.name, result.errorMessage));
        }
        
    } catch (const std::exception &e) {
        result.success = false;
        result.errorMessage = QString("Exception: %1").arg(e.what());
    }
    
    return result;
}

JobManager::JobResult JobManager::performRemoval(const QString &id, const QString &deploymentYaml)
{
    JobResult result;
    result.success = true;
    
    try {
        setState(State::Removing, QString("Removing %1").arg(id));
        
        QStringList cleanupCommands;
        cleanupCommands << QString("kubectl scale deployment %1 --replicas=0 -n default --ignore-not-found").arg(id);
        cleanupCommands << QString("kubectl wait --for=delete pod -l app=%1 -n default --timeout=30s || true").arg(id);
        cleanupCommands << QString("kubectl delete -f %1 --ignore-not-found --wait=true").arg(deploymentYaml);
        cleanupCommands << QString("kubectl delete job pull-%1 mirror-%1 --ignore-not-found").arg(id);
        
        for (const QString &cmd : cleanupCommands) {
            JobResult cmdResult = executeCommandsSync({cmd});
            if (!cmdResult.success && !cmd.contains("--ignore-not-found") && !cmd.contains("|| true")) {
                qWarning() << "[JobManager] Cleanup command failed:" << cmd;
            }
        }
        
        NOTIFY_INFO("Removal", QString("Service %1 removed successfully").arg(id));
        
    } catch (const std::exception &e) {
        result.success = false;
        result.errorMessage = QString("Exception: %1").arg(e.what());
        NOTIFY_ERROR("Removal", result.errorMessage);
    }
    
    return result;
}

JobManager::JobResult JobManager::performInstallation(const InstallationRequest &request)
{
    JobResult result;
    result.success = true; // Start with success assumption
    
    try {
        setState(State::Installing, QString("Installing %1").arg(request.appName));
        
        qDebug() << "[JobManager] Starting installation of" << request.appName 
                 << "with" << request.commands.size() << "commands";
        
        // Execute installation commands sequentially
        for (int i = 0; i < request.commands.size(); ++i) {
            const QString &cmd = request.commands[i];
            qDebug() << "[JobManager] Executing command" << (i+1) << "of" << request.commands.size() << ":" << cmd;
            
            JobResult cmdResult = executeCommandsSync({cmd});
            
            if (!cmdResult.success) {
                result.success = false;
                result.errorMessage = QString("Command %1 failed: %2").arg(i+1).arg(cmdResult.errorMessage);
                result.output = cmdResult.output;
                
                qWarning() << "[JobManager] Installation failed at command" << (i+1) << ":" << result.errorMessage;
                qWarning() << "[JobManager] Command output:" << cmdResult.output;
                
                NOTIFY_ERROR("Installation", QString("Failed to install %1: %2")
                    .arg(request.appName, result.errorMessage));
                return result;
            }
            
            qDebug() << "[JobManager] Command" << (i+1) << "completed successfully";
            
            // Brief pause between commands to avoid overwhelming the system
            if (i < request.commands.size() - 1) {
                QThread::msleep(500);
            }
        }
        
        // All commands succeeded
        result.success = true;
        result.errorMessage.clear();
        
        qDebug() << "[JobManager] Installation of" << request.appName << "completed successfully";
        NOTIFY_INFO("Installation", QString("%1 installed successfully").arg(request.appName));
        
    } catch (const std::exception &e) {
        result.success = false;
        result.errorMessage = QString("Exception during installation: %1").arg(e.what());
        
        qCritical() << "[JobManager] Exception in performInstallation:" << e.what();
        NOTIFY_ERROR("Installation", QString("Installation failed: %1").arg(result.errorMessage));
    }
    
    return result;
}

JobManager::JobResult JobManager::executeCommandsSync(const QStringList &commands)
{
    JobResult result;
    result.success = false;
    
    if (commands.isEmpty()) {
        result.errorMessage = "No commands provided";
        return result;
    }
    
    try {
        QString command = commands.first();
        
        QProcess process;
        process.setProcessChannelMode(QProcess::MergedChannels);
        
        // Set environment
        QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
        QString path = env.value("PATH");
        if (!path.contains("/usr/local/bin")) {
            path += ":/usr/local/bin";
        }
        env.insert("PATH", path);
        process.setProcessEnvironment(env);
        
        qDebug() << "[JobManager] Executing command:" << command;
        process.start("/bin/bash", QStringList() << "-c" << command);
        
        if (!process.waitForStarted(5000)) {
            result.errorMessage = QString("Failed to start process: %1").arg(process.errorString());
            qWarning() << "[JobManager]" << result.errorMessage;
            return result;
        }
        
        // Determine timeout based on command type
        int timeout = 30000; // default 30 seconds
        if (command.contains("kubectl wait")) {
            timeout = 300000; // 5 minutes for wait commands
        } else if (command.contains("kubectl apply")) {
            timeout = 60000; // 1 minute for apply commands
        } else if (command.contains("get node")) {
            timeout = 10000; // 10 seconds for node checks
        }
        
        if (!process.waitForFinished(timeout)) {
            qWarning() << "[JobManager] Command timed out after" << timeout << "ms:" << command;
            process.kill();
            process.waitForFinished(2000);
            result.errorMessage = QString("Command timed out after %1 seconds").arg(timeout / 1000);
            return result;
        }
        
        int exitCode = process.exitCode();
        QProcess::ExitStatus exitStatus = process.exitStatus();
        
        result.output = QString::fromUtf8(process.readAll()).trimmed();
        
        result.success = (exitStatus == QProcess::NormalExit && exitCode == 0);
        
        if (!result.success) {
            result.errorMessage = QString("Command failed with exit code %1").arg(exitCode);
            if (!result.output.isEmpty()) {
                result.errorMessage += QString(": %1").arg(result.output);
            }
        }
        
        qDebug() << "[JobManager] Command result - Success:" << result.success 
                 << "Exit code:" << exitCode
                 << "Output size:" << result.output.length() << "chars";
        
        if (!result.success) {
            qWarning() << "[JobManager] Command failed:" << command;
            qWarning() << "[JobManager] Error:" << result.errorMessage;
            qWarning() << "[JobManager] Output:" << result.output;
        }
        
    } catch (const std::exception &e) {
        result.success = false;
        result.errorMessage = QString("Exception: %1").arg(e.what());
        qCritical() << "[JobManager] Exception in executeCommandsSync:" << e.what();
    } catch (...) {
        result.success = false;
        result.errorMessage = "Unknown error occurred";
        qCritical() << "[JobManager] Unknown exception in executeCommandsSync";
    }
    
    return result;
}

bool JobManager::waitForPodTermination(const QString &deploymentName, int maxWaitSec)
{
    for (int i = 0; i < maxWaitSec; ++i) {
        const QString cmd = QString("kubectl get deployment %1 -n default -o jsonpath='{.status.replicas}' 2>/dev/null")
            .arg(deploymentName);
        
        JobResult result = executeCommandsSync({cmd});
        
        if (result.success) {
            QString output = result.output.trimmed();
            if (output.isEmpty() || output == "0") {
                return true;
            }
        }
        
        QThread::sleep(1);
    }
    
    return false;
}

bool JobManager::waitForPodsReady(const QString &deploymentName, int maxWaitSec)
{
    for (int i = 0; i < maxWaitSec; i += 3) {
        const QString cmd = QString("kubectl get deployment %1 -n default -o jsonpath='{.status.readyReplicas}/{.status.replicas}' 2>/dev/null")
            .arg(deploymentName);
        
        JobResult result = executeCommandsSync({cmd});
        
        if (result.success && !result.output.isEmpty() && result.output.contains('/')) {
            QStringList parts = result.output.trimmed().split('/');
            if (parts.size() == 2) {
                int ready = parts[0].toInt();
                int total = parts[1].toInt();
                
                if (ready > 0 && ready == total) {
                    return true;
                }
            }
        }
        
        QThread::sleep(3);
    }
    
    return false;
}

bool JobManager::forceDeletePods(const QString &deploymentName)
{
    const QString cmd = QString("kubectl delete pods -l app=%1 -n default --force --grace-period=0 --ignore-not-found")
        .arg(deploymentName);
    
    JobResult result = executeCommandsSync({cmd});
    return result.success;
}

bool JobManager::deploymentExists(const QString &deploymentName)
{
    const QString cmd = QString("kubectl get deployment %1 -n default --no-headers 2>/dev/null")
        .arg(deploymentName);
    
    JobResult result = executeCommandsSync({cmd});
    return result.success && !result.output.trimmed().isEmpty();
}

void JobManager::onInstallerFinished(bool success)
{
    qDebug() << "[JobManager] Installer finished:" << success;
}