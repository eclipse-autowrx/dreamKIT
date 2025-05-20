#ifndef INSTALLEDVAPPS_H
#define INSTALLEDVAPPS_H

#include <QObject>
#include <QTextStream>
#include <QFile>
#include "QString"
#include <QThread>
#include <QList>
#include <QFileSystemWatcher>
#include <QTimer>

typedef struct {
    QString id;
    QString category;
    QString name;
    QString author;
    QString rating;
    QString noofdownload;
    QString iconPath;
    QString foldername;
    QString packagelink;
    bool isInstalled;
    bool isSubscribed;
} VappsListStruct;

void readServicesList(const QString searchName, QList<VappsListStruct> &VappsListInfo);


class VappsAsync;

class InstalledVappsCheckThread : public QThread
{
    Q_OBJECT

public:
    InstalledVappsCheckThread(VappsAsync *parent);
    void run();
    void triggerCheckAppStart(QString id, QString name);

Q_SIGNALS:
    void resultReady(QString appId, bool isStarted, QString msg);

private:
    QString m_appId;
    QString m_appName;
    bool m_istriggeredAppStart = false;
    VappsAsync *m_serviceAsync = nullptr;
    QFileSystemWatcher *m_filewatcher = nullptr;
};

class VappsAsync: public QObject
{
    Q_OBJECT
public:
    VappsAsync();

    Q_INVOKABLE void initInstalledVappsFromDB();

    Q_INVOKABLE void executeServices(int appIdx, const QString name, const QString appId, bool isSubscribed);

    Q_INVOKABLE void removeServices(const int index);

    Q_INVOKABLE void openAppEditor(int idx);

Q_SIGNALS:
    void appendServicesInfoToServicesList(QString name, QString author, QString rating, QString noofdownload, QString icon, bool isInstalled, QString appId, bool isSubscribed);
    void appendLastRowToServicesList(const int noOfServicess);
    void clearServicesListView();
    void updateStartAppMsg(QString appId, bool isStarted, QString msg);
    void updateServicesRunningSts(QString appId, bool isStarted, int idx);

public Q_SLOTS:
    void handleResults(QString appId, bool isStarted, QString msg);
    void fileChanged(const QString& path);
    void checkRunningAppSts();

private:
    QList<VappsListStruct> installedVappsList;
    InstalledVappsCheckThread *m_workerThread;
    QTimer *m_timer_apprunningcheck;

    void removeObjectById(const QString &filePath, const QString &idToRemove);
};

#endif //INSTALLEDVAPPS_H
