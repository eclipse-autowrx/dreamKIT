#include "installedcheckthread.hpp"
#include <QFile>

QString InstalledCheckThread::m_appId;
QString InstalledCheckThread::m_appName;
bool    InstalledCheckThread::m_triggered = false;

InstalledCheckThread::InstalledCheckThread(QObject *receiver,
                                           const QString &json,
                                           QObject *parent)
    : QThread(parent)
{
    m_watcher = new QFileSystemWatcher(this);
    if (m_watcher && QFile::exists(json)) {
        m_watcher->addPath(json);
        /* use SIGNAL/SLOT strings because receiver is a template instance */
        QObject::connect(m_watcher, SIGNAL(fileChanged(QString)),
                         receiver,   SLOT(fileChanged(QString)));
    }
}

void InstalledCheckThread::triggerCheckAppStart(QString id, QString name)
{
    m_appId = std::move(id);
    m_appName = std::move(name);
    m_triggered = true;
}

void InstalledCheckThread::notifyState(bool ok)
{
    if (m_triggered && !m_appId.isEmpty()) {
        const QString txt = ok
            ? tr("<b>%1</b> started successfully.").arg(m_appName)
            : tr("<b>%1</b> failed to start.").arg(m_appName);
        emit resultReady(m_appId, ok, txt);
        m_triggered = false;
        m_appId.clear();
        m_appName.clear();
    }
}
