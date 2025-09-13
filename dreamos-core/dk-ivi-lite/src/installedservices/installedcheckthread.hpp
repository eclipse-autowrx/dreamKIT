#pragma once
#include <QThread>
#include <QFileSystemWatcher>

class InstalledCheckThread : public QThread
{
    Q_OBJECT
public:
    explicit InstalledCheckThread(QObject *qmlReceiver,
                                  const QString &jsonFile,
                                  QObject *parent = nullptr);

    /* called by controller after kubectl apply */
    void triggerCheckAppStart(QString id, QString name);
    /* called by controller when it knows the container state */
    void notifyState(bool ok);

    /* static because one global state is enough */
    static QString  m_appId;
    static QString  m_appName;
    static bool     m_triggered;

signals:
    void resultReady(QString appId, bool started, QString msg);

private:
    QFileSystemWatcher *m_watcher {nullptr};
};
