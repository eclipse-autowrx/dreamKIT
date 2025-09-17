// Copyright (c) 2025 Eclipse Foundation.
// 
// This program and the accompanying materials are made available under the
// terms of the MIT License which is available at
// https://opensource.org/licenses/MIT.
// 
// SPDX-License-Identifier: MIT
#include "installer.hpp"
#include <QDebug>

using namespace K3s;

Installer::Installer(QObject *p) : QObject(p)
{
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    QString path = env.value("PATH");
    if (!path.contains("/usr/local/bin"))
        path += ":/usr/local/bin";
    env.insert("PATH", path);
    m_proc.setProcessEnvironment(env);

    m_proc.setProcessChannelMode(QProcess::MergedChannels);

    connect(&m_proc, &QProcess::started, this, [](){
        qDebug() << "[K3s::Installer] process started";
    });
    connect(&m_proc,
            static_cast<void(QProcess::*)(QProcess::ProcessError)>(&QProcess::errorOccurred),
            this, [this](QProcess::ProcessError e){
        qWarning() << "[K3s::Installer] errorOccurred:" << e
                   << m_proc.errorString();
        m_proc.kill();
        m_busy = false;
        emit busyChanged(false);
        emit finished(false);
    });
    connect(&m_proc,
            QOverload<int,QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this](int code, QProcess::ExitStatus st){
        const bool ok = (st == QProcess::NormalExit && code == 0);
        qDebug() << "[K3s::Installer] step" << m_idx
                 << "finished; ok=" << ok
                 << "exit code:" << code
                 << "exit status:" << st;
        if (ok) runNext();
        else {
            m_busy = false;
            emit busyChanged(false);
            emit finished(false);
        }
    });
}

void Installer::queueAndRun(const QStringList &commands)
{
    if (m_busy) return;
    m_cmds = commands;
    m_idx  = 0;
    m_busy = true;
    emit busyChanged(true);
    runNext();
}

void Installer::runNext()
{
    if (m_idx >= m_cmds.size()) {
        qDebug() << "[K3s::Installer] all steps done.";
        m_busy = false;
        emit busyChanged(false);
        emit finished(true);
        return;
    }
    const QString cmd = m_cmds.at(m_idx++);
    qDebug() << "[K3s::Installer] running" << cmd;
    
    // Prepend a command to dump environment and then run the actual command
    QString fullCmd = QString("echo 'PATH:' $PATH; echo 'KUBECONFIG:' $KUBECONFIG; %1").arg(cmd);
    m_proc.start("bash", {"-l", "-c", fullCmd});
    if (!m_proc.waitForStarted(1000)) {
        qWarning() << "[K3s::Installer] process did not start";
        m_busy = false;
        emit busyChanged(false);
        emit finished(false);
        return;
    }
}

bool Installer::runCommandsSync(const QStringList &commands,
                                QString *stdoutText,
                                QString *stderrText)
{
    /*  we create a *temporary* event loop that blocks the caller
     *  until the existing async machinery has processed every
     *  command in the list.                                     */
    QEventLoop loop;
    bool okFlag = false;
    QByteArray allOut, allErr;

    /* collect output if requested */
    auto accOut = [&](const QByteArray &d){ allOut += d; };
    auto accErr = [&](const QByteArray &d){ allErr += d; };

    /* connect before starting to not miss initial signals */
    connect(this, &Installer::finished,
            &loop, [&](bool ok){ okFlag = ok; loop.quit(); });

    if (stdoutText)
        connect(&m_proc, &QProcess::readyReadStandardOutput,
                this, [&](){ allOut += m_proc.readAllStandardOutput(); });
    if (stderrText)
        connect(&m_proc, &QProcess::readyReadStandardError,
                this, [&](){ allErr += m_proc.readAllStandardError(); });

    queueAndRun(commands);           // << asynchronous start
    loop.exec();                     // << wait here

    if (stdoutText) *stdoutText = QString::fromUtf8(allOut);
    if (stderrText) *stderrText = QString::fromUtf8(allErr);

    return okFlag;                   // Chain will use this
}

/* static */
bool Installer::nodeReady(const QString &nodeName,
                          int timeoutSec,
                          QString *stdoutText)
{
    QProcess proc;
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    QString p = env.value("PATH");
    if (!p.contains("/usr/local/bin"))
        p += ":/usr/local/bin";
    env.insert("PATH", p);
    proc.setProcessEnvironment(env);

    /* ask for full JSON to avoid shell quoting hell                */
    proc.setProgram("kubectl");
    proc.setArguments({ "get", "node", nodeName, "-o", "json" });
    proc.setProcessChannelMode(QProcess::MergedChannels);

    proc.start();
    if (!proc.waitForStarted(1000)) {
        qWarning() << "[Installer::nodeReady] kubectl not start";
        return false;
    }
    
    // Use a shorter, non-blocking approach
    bool finished = proc.waitForFinished(timeoutSec * 1000);
    if (!finished) {
        qWarning() << "[Installer::nodeReady] kubectl timed out after" << timeoutSec << "seconds";
        proc.kill();
        proc.waitForFinished(1000); // Brief wait for cleanup
        return false;
    }

    QByteArray raw = proc.readAll();          // may contain noise
    if (stdoutText)
        *stdoutText = QString::fromUtf8(raw);

    // Check exit code first
    if (proc.exitCode() != 0) {
        qDebug() << "[Installer::nodeReady] kubectl failed with exit code:" << proc.exitCode();
        return false;
    }

    /* strip everything before first "{" so that QJson parses cleanly */
    int pos = raw.indexOf('{');
    if (pos < 0) {
        qWarning() << "[Installer::nodeReady] no JSON found";
        return false;
    }
    QByteArray jsonPart = raw.mid(pos);

    const QJsonDocument doc = QJsonDocument::fromJson(jsonPart);
    if (doc.isNull() || !doc.isObject()) {
        qWarning() << "[Installer::nodeReady] invalid JSON";
        return false;
    }

    const QJsonArray conditions =
            doc["status"].toObject()
               ["conditions"].toArray();

    for (const QJsonValue &v : conditions) {
        const QJsonObject o = v.toObject();
        if (o["type"] == QLatin1String("Ready"))
            return o["status"] == QLatin1String("True");
    }
    qWarning() << "[Installer::nodeReady] Ready condition missing";
    return false;
}

/* static */
Async::Job<bool> *Installer::nodeReadyAsync(const QString &name,
                                            int timeoutSec,
                                            QObject *parent)
{
    return new Async::Job<bool>(
        [=](){ return nodeReady(name, timeoutSec); }, parent);
}

/* static */
bool Installer::deploymentAvailable(const QString &deploymentId,
                                    int timeoutSec,
                                    QString *stdoutText)
{
    // 1) prepare env   make sure kubectl is found
    QProcess proc;
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    QString p = env.value("PATH");
    if (!p.contains("/usr/local/bin"))
        p += ":/usr/local/bin";
    env.insert("PATH", p);
    proc.setProcessEnvironment(env);

    // 2) configure the command
    proc.setProgram("kubectl");
    proc.setArguments({ "wait",
                        "--for=condition=available",
                        "deployment/" + deploymentId,
                        QString("--timeout=%1s").arg(timeoutSec) });
    proc.setProcessChannelMode(QProcess::MergedChannels);

    // 3) run synchronously
    proc.start();
    if (!proc.waitForStarted(1000)) {
        qWarning() << "[Installer] kubectl did not start";
        return false;
    }
    proc.waitForFinished((timeoutSec + 1) * 1000);   // block

    // 4) collect output and evaluate result
    const QString out = QString::fromUtf8(proc.readAll()).trimmed();
    if (stdoutText)
        *stdoutText = out;

    const bool ok = proc.exitStatus() == QProcess::NormalExit
                    && proc.exitCode() == 0;

    // if (!ok)
    //     qWarning() << "[Installer] kubectl wait failed for" << deploymentId
    //                << "exitCode=" << proc.exitCode()
    //                << "output:"   << out;

    return ok;
}

Async::Job<DeploymentCheck>*
Installer::deploymentAvailableAsync(const QString &id,
                                    int timeoutSec, QObject *parent)
{
    return new Async::Job<DeploymentCheck>(
        [=](){
            DeploymentCheck r;
            r.deploymentId = id;
            QString out;
            r.available = deploymentAvailable(id, timeoutSec, &out);
            r.output    = out;
            return r;
        },
        parent);
}
