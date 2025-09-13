#pragma once
// k3s/installer.hpp
//
// Thin state machine around QProcess that executes a queue of shell
// commands (kubectl …).  Emits ‘busyChanged / finished’.
//
#include <QObject>
#include <QProcess>
#include "../../async/asyncjob.hpp"

namespace K3s {

struct DeploymentCheck {
    QString deploymentId;
    bool    available = false;
    QString output;
};

class Installer : public QObject
{
    Q_OBJECT
public:
    explicit Installer(QObject *parent = nullptr);

    void queueAndRun(const QStringList &commands);
    bool busy() const { return m_busy; }
    /* -------------- synchronous helper ------------------ */
    bool runCommandsSync(const QStringList &commands,
                         QString *stdoutText = nullptr,
                         QString *stderrText = nullptr);
    
    // Returns true if `kubectl get node <name>` reports the node Ready.
    static bool nodeReady(const QString &nodeName,
        int timeoutSec = 5,
        QString *stdoutText = nullptr);

    static Async::Job<bool>* nodeReadyAsync(const QString &nodeName,
                        int timeoutSec = 5,
                        QObject *parent = nullptr);

    // Convenience: return true if kubectl reports the deployment to be
    // available (≥1 ready replica) within <timeoutSec> seconds.
    static bool deploymentAvailable(const QString &deploymentId,
        int timeoutSec = 10,
        QString *stdoutText = nullptr);
    // async helper that uses the common Async::Job
    static Async::Job<DeploymentCheck>* deploymentAvailableAsync(
        const QString &deploymentId,
        int timeoutSec = 10,
        QObject *parent = nullptr);

signals:
    void busyChanged(bool);
    void finished(bool ok);  // ok==true if every command exited 0

private:
    void runNext();
    QProcess   m_proc;
    QStringList m_cmds;
    int         m_idx   = 0;
    bool        m_busy  = false;
};

} // namespace K3s
