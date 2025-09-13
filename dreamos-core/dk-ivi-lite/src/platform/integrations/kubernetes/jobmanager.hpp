#pragma once
#include <QObject>
#include <QTimer>
#include <QProcess>
#include <QEventLoop>
#include <QMutex>
#include <QThread>
#include <QQueue>
#include <memory>
#include "../../async/asyncjob.hpp"
#include "installer.hpp"

namespace K3s {

/**
 * @brief Centralized, thread-safe manager for all K3s operations with state management
 */
class JobManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool busy READ isBusy NOTIFY busyChanged)
    Q_PROPERTY(QString currentOperation READ currentOperation NOTIFY currentOperationChanged)
    
public:
    enum class State {
        Idle,
        Installing,
        Deploying,
        Removing,
        Checking,
        Restarting
    };
    Q_ENUM(State)
    
    struct JobResult {
        bool success = false;
        QString errorMessage;
        QString output;
    };
    
    struct DeploymentInfo {
        QString id;
        QString name;
        QString deploymentYaml;
        bool subscribe = false;
    };
    
    struct InstallationRequest {
        QString appId;
        QString appName;
        QStringList commands;
        QString category;
    };
    
    explicit JobManager(QObject *parent = nullptr);
    ~JobManager();
    
    // State accessors
    bool isBusy() const { return m_state != State::Idle; }
    State currentState() const { return m_state; }
    QString currentOperation() const { return m_currentOperation; }
    
    // Core operations - all go through central orchestration
    Q_INVOKABLE Async::Job<JobResult>* deployService(const DeploymentInfo &info);
    Q_INVOKABLE Async::Job<JobResult>* removeService(const QString &id, const QString &deploymentYaml);
    Q_INVOKABLE Async::Job<bool>* checkNodeReady(const QString &nodeName = "vip", int timeoutSec = 5);
    Q_INVOKABLE Async::Job<bool>* checkDeploymentAvailable(const QString &deploymentId, int timeoutSec = 10);
    
    // Installation operations (moved from InstallationWorker)
    Q_INVOKABLE Async::Job<JobResult>* installApplication(const InstallationRequest &request);
    Q_INVOKABLE Async::Job<JobResult>* runCommands(const QStringList &commands, const QString &operation = "Command");
    
    // Auto-restart functionality
    Q_INVOKABLE Async::Chain* createAutoRestartChain(const QString &deploymentName = "sdv-runtime");
    Q_INVOKABLE Async::Job<JobResult>* restartDeployment(const QString &deploymentName);
    Q_INVOKABLE Async::Job<JobResult>* scaleDeployment(const QString &deploymentName, int replicas);
    
    // Singleton access for thread-safe usage
    static JobManager* instance();
    
signals:
    void busyChanged(bool busy);
    void stateChanged(State newState);
    void currentOperationChanged(const QString &operation);
    void jobStarted(const QString &operation);
    void jobFinished(const QString &operation, bool success, const QString &message);
    void requestRejected(const QString &reason);

private slots:
    void onInstallerFinished(bool success);
    
private:
    // Central state management
    bool tryAcquireState(State newState, const QString &operation);
    void releaseState();
    void setState(State newState, const QString &operation = QString());
    
    // Thread-safe job creation
    template<typename T>
    Async::Job<T>* createJobSafely(std::function<T()> task);
    Async::Chain* createChainSafely();
    
    // Core execution methods
    JobResult executeCommandsSync(const QStringList &commands);
    JobResult performDeployment(const DeploymentInfo &info);
    JobResult performRemoval(const QString &id, const QString &deploymentYaml);
    JobResult performInstallation(const InstallationRequest &request);
    
    // Helper methods
    bool waitForPodTermination(const QString &deploymentName, int maxWaitSec = 30);
    bool waitForPodsReady(const QString &deploymentName, int maxWaitSec = 180);
    bool forceDeletePods(const QString &deploymentName);
    bool deploymentExists(const QString &deploymentName);
    
    Installer *m_installer;
    QThread *m_mainThread;
    
    // State management
    State m_state;
    QString m_currentOperation;
    mutable QMutex m_stateMutex;
    
    // Singleton
    static QMutex s_instanceMutex;
    static JobManager *s_instance;
};

} // namespace K3s