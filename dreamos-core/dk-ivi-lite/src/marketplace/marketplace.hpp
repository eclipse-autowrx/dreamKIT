#ifndef APPASYNCCLASS_H
#define APPASYNCCLASS_H

#include <QObject>
#include <QTextStream>
#include <QFile>
#include <QDebug>
#include <QTimer>
// #include <appstore/appstore.hpp>

// Structure to store marketplace information
struct MarketplaceInfo {
    QString name;
    QString marketplace_url;
    QString login_url;
    QString username;
    QString pwd;
};

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
} AppListStruct;

void appstore_readAppList(const QString searchName, QList<AppListStruct> &AppListInfo);

typedef struct {
    QString foldername;
    QString displayname;
    QString executable;
    QString iconPath;
} InstalledAppListStruct;

class MarketplaceAsync: public QObject
{
    Q_OBJECT
public:
    MarketplaceAsync();

    Q_INVOKABLE void initMarketplaceListFromDB();
    
    Q_INVOKABLE void setCurrentMarketPlaceIdx(int idx);

    Q_INVOKABLE void installApp(const int index);

    Q_INVOKABLE void searchAppFromStore(const QString searchName);

Q_SIGNALS:
//    void initSearchedAppList(const int noOfApps);
    void appendAppInfoToAppList(QString name, QString author, QString rating, QString noofdownload, QString icon, bool isInstalled);
    void clearAppInfoToAppList();
    void appendLastRowToAppList(const int noOfApps);
    void initInstalledAppList(const int noOfApps);
    void appendAppInfoToInstalledAppList(QString name, QString icon);
    void appendLastRowToInstalledAppList();
    void handleFailureAppInstallation(QString type, QString msg);

    void clearMarketplaceNameList();
    void appendMarketplaceUrlList(QString name);
    void setInstallServiceRunningStatus(bool status);

public Q_SLOTS:
    void checkInstallServiceIsRunning();

private:
    QList<InstalledAppListStruct> m_installedAppList;
    QList<AppListStruct> m_searchedAppList;
    QList<MarketplaceInfo> m_marketplaceList;
    int m_current_idx = 0;
    QString m_current_searchname = "";
    QTimer *m_timer_installservice_runningcheck;

    QList<MarketplaceInfo> parseMarketplaceFile(const QString &filePath);
    void appstore_readAppList(const QString searchName, QList<AppListStruct> &AppListInfo);
};

#endif //APPASYNCCLASS_H
