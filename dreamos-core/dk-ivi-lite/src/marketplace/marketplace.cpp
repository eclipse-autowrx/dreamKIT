#include "marketplace.hpp"
#include "fetching.hpp"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDebug>

extern QString DK_VCU_USERNAME;
extern QString DK_ARCH;
extern QString DK_DOCKER_HUB_NAMESPACE;
extern QString DK_CONTAINER_ROOT;

// Function to check if the file exists and create it with default content if not
void ensureMarketplaceSelectionExists(const QString &marketplaceFilePath) {
    QFile file(marketplaceFilePath);

    // Check if the file already exists
    if (!file.exists()) {
        qDebug() << "File not found, creating" << marketplaceFilePath;

        // Define default JSON content
        QJsonArray defaultArray;
        QJsonObject defaultMarketplace;
        defaultMarketplace["name"] = "BGSV Marketplace";
        defaultMarketplace["marketplace_url"] = "";
        defaultMarketplace["login_url"] = "";
        defaultMarketplace["username"] = "";
        defaultMarketplace["pwd"] = "";

        defaultArray.append(defaultMarketplace);
        QJsonDocument defaultDoc(defaultArray);
        QByteArray jsonData = defaultDoc.toJson();

        // Attempt to open the file for writing
        if (file.open(QIODevice::WriteOnly)) {
            file.write(jsonData);
            file.close();
            qDebug() << "Default marketplace selection file created at" << marketplaceFilePath;
        } else {
            qDebug() << "Error: Could not create the file" << marketplaceFilePath;
        }
    } else {
        qDebug() << "Marketplace selection file already exists at" << marketplaceFilePath;
    }
}

MarketplaceAsync::MarketplaceAsync()
{
    QString dkRootFolder = qgetenv("DK_CONTAINER_ROOT");
    QString marketplaceFolder = dkRootFolder + "dk_marketplace/";
    QString marketPlaceSelection = marketplaceFolder + "marketplaceselection.json";
    // Ensure marketplace selection file exists
    ensureMarketplaceSelectionExists(marketPlaceSelection);

    m_marketplaceList.clear();
    m_marketplaceList = parseMarketplaceFile(marketPlaceSelection);

    m_timer_installservice_runningcheck = new QTimer(this);
    connect(m_timer_installservice_runningcheck, SIGNAL(timeout()), this, SLOT(checkInstallServiceIsRunning()));
    m_timer_installservice_runningcheck->start(5000);
}

void MarketplaceAsync::checkInstallServiceIsRunning()
{
    QString appStsLog =  "/tmp/checkInstallServiceIsRunning.log";
    QString cmd = "> " + appStsLog + "; docker ps > " + appStsLog;
    system(cmd.toUtf8());
    
    QFile logFile(appStsLog);
    if (!logFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qCritical() << "Failed to open log file: checkInstallServiceIsRunning.log";
        return;
    }

    QTextStream in(&logFile);
    QString content = in.readAll();

    if (content.isEmpty()) {
        qCritical() << "Log file is empty or could not be read.";
        return;
    }

    if (content.contains("dk_appinstallservice", Qt::CaseSensitivity::CaseSensitive)) {
        setInstallServiceRunningStatus(true);
    }
    else {
        setInstallServiceRunningStatus(false);
    }
}

Q_INVOKABLE void MarketplaceAsync::initMarketplaceListFromDB()
{
    clearMarketplaceNameList();
    for (const auto &marketplace : m_marketplaceList) {
        qDebug() << "appendMarketplaceUrlList: " << marketplace.name;
        appendMarketplaceUrlList(marketplace.name);
    }
}

Q_INVOKABLE void MarketplaceAsync::setCurrentMarketPlaceIdx(int idx)
{
    qDebug() << __func__ << __LINE__ << " : current idx = " << idx;
    m_current_idx = idx;
    clearAppInfoToAppList();
    searchAppFromStore(m_current_searchname);
}

// Function to parse marketplaceselection.json and populate a list of MarketplaceInfo
QList<MarketplaceInfo> MarketplaceAsync::parseMarketplaceFile(const QString &filePath) 
{
    QList<MarketplaceInfo> marketplaceList;

    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        qDebug() << "Could not open file:" << filePath;
        return marketplaceList;
    }

    QByteArray jsonData = file.readAll();
    file.close();

    QJsonDocument document = QJsonDocument::fromJson(jsonData);
    if (!document.isArray()) {
        qDebug() << "Invalid JSON format in" << filePath;
        return marketplaceList;
    }

    QJsonArray array = document.array();
    for (const QJsonValue &value : array) {
        if (value.isObject()) {
            QJsonObject obj = value.toObject();
            MarketplaceInfo info;
            info.name = obj["name"].toString();
            info.marketplace_url = obj["marketplace_url"].toString();
            info.login_url = obj["login_url"].toString();
            info.username = obj["username"].toString();
            info.pwd = obj["pwd"].toString();
            marketplaceList.append(info);
        }
    }

    return marketplaceList;
}

void MarketplaceAsync::appstore_readAppList(const QString searchName, QList<AppListStruct> &AppListInfo) 
{
    QString marketplaceFolder = DK_CONTAINER_ROOT + "dk_marketplace/";
    QString mpDataPath = marketplaceFolder + "marketplace_data_installcfg.json";

    // queryMarketplacePackages(1, 10, searchName);
    QString marketplace_url = m_marketplaceList[m_current_idx].marketplace_url;
    QString uname = m_marketplaceList[m_current_idx].username;
    QString pwd = m_marketplaceList[m_current_idx].pwd;
    QString login_url = m_marketplaceList[m_current_idx].login_url;

    qDebug() << "Requesting data marketplace_url : " << marketplace_url;
    qDebug() << "Requesting data uname : " << uname;
    qDebug() << "Requesting data pwd : " << pwd;
    qDebug() << "Requesting data login_url : " << login_url;
    qDebug() << "Requesting data searchName : " << searchName;

    QString token = "";
    if (!uname.isEmpty() && !pwd.isEmpty()) {
        // Perform login and query with token if uname and pwd are provided
        token = marketplace_login(login_url, uname, pwd);
        if (!token.isEmpty()) {
            queryMarketplacePackages(marketplace_url, token, 1, 10, searchName);
            // qDebug() << "Authenticated request returned data of length:";
        } else {
            qDebug() << "Failed to authenticate with provided credentials.";
        }
    } else {
        // Query without token if uname and pwd are empty
        queryMarketplacePackages(marketplace_url, token, 1, 10, searchName);
        qDebug() << "Unauthenticated request returned data of length:";
    }

    // Read the JSON file
    QFile file(mpDataPath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qDebug() << "Failed to open file.";
        return;
    }

    QByteArray jsonData = file.readAll();
    file.close();

    // Parse the JSON data
    QJsonDocument document = QJsonDocument::fromJson(jsonData);
    if (document.isNull() || !document.isArray()) {
        qDebug() << __func__ << "@" << __LINE__ << ": Invalid JSON format.";
        return;
    }

    QJsonArray jsonArray = document.array();

    // Loop through each item in the array
    for (const QJsonValue &value : jsonArray) {
        if (!value.isObject()) {
            continue;
        }

        QJsonObject jsonObject = value.toObject();
        AppListStruct appInfo;

        // Extract relevant fields for AppListStruct
        appInfo.id = jsonObject["_id"].toString();
        appInfo.category = jsonObject["category"].toString();        

        // Extract relevant fields for AppListStruct
        appInfo.name = jsonObject["name"].toString();

        QJsonObject storeId = jsonObject["storeId"].toObject();
        if (storeId.contains("name")) {
            appInfo.author = storeId["name"].toString();
        } 
        else {
            appInfo.author = "Unknown";
        }

        // Extract rating (if it exists)
        appInfo.rating = jsonObject["rating"].isNull() ? "**" : QString::number(jsonObject["rating"].toDouble());

        // Extract number of downloads
        appInfo.noofdownload = QString::number(jsonObject["downloads"].toInt());

        // Extract thumbnail for iconPath
        appInfo.iconPath = jsonObject["thumbnail"].toString();

        // Use the name as the folder name
        appInfo.foldername = appInfo.id;

        // Extract dashboardConfig or default to empty
        appInfo.packagelink = jsonObject["dashboardConfig"].toString().isEmpty() ? "N/A" : jsonObject["dashboardConfig"].toString();

        // For this example, assume all apps are not installed
        appInfo.isInstalled = false;

        // Only add to the list if the name contains the searchName
        if (appInfo.category.contains(searchName, Qt::CaseInsensitive)) {
            AppListInfo.append(appInfo);
        }
    }

    qDebug() << "App list loaded, total apps found:" << AppListInfo.size();
}

Q_INVOKABLE void MarketplaceAsync::searchAppFromStore(const QString searchName)
{
    m_current_searchname = searchName;
    if (m_current_searchname == "") {
        m_current_searchname = "vehicle";
    }
//    qDebug() << __func__ << "m_current_searchname = " << m_current_searchname;
    m_searchedAppList.clear();
    appstore_readAppList(m_current_searchname, m_searchedAppList);

    if (m_searchedAppList.size()) {
        for(int i = 0; i < m_searchedAppList.size(); i++) {
            //        qDebug() << AppListInfo[i].name;
            appendAppInfoToAppList(m_searchedAppList[i].name, m_searchedAppList[i].author,
                                   m_searchedAppList[i].rating, m_searchedAppList[i].noofdownload,
                                   m_searchedAppList[i].iconPath,
                                   m_searchedAppList[i].isInstalled);
        }
    }
    else {
        appendAppInfoToAppList("", "", "", "", "", true);
    }
    appendLastRowToAppList(m_searchedAppList.size());
}

Q_INVOKABLE void MarketplaceAsync::installApp(const int index)
{
    if (index >= m_searchedAppList.size()) {
        qDebug() << "index out of range";
        return;
    }

    QString appId = m_searchedAppList[index].id;
    qDebug() << m_searchedAppList[index].name << " index = " << index << " is installing";
    qDebug() << " appId = " << appId;

    QString dockerHubUrl = "";
    if(DK_DOCKER_HUB_NAMESPACE.isEmpty()) {
        DK_DOCKER_HUB_NAMESPACE = qgetenv("DK_DOCKER_HUB_NAMESPACE");
    }
    dockerHubUrl = DK_DOCKER_HUB_NAMESPACE + "/";
     

    QString installCfg = "/home/" + DK_VCU_USERNAME + "/.dk/dk_marketplace/" + appId + "_installcfg.json";
    QString cmd = "docker kill dk_appinstallservice;docker rm dk_appinstallservice;docker run -d -it --name dk_appinstallservice -v /home/" + DK_VCU_USERNAME + "/.dk:/app/.dk -v /var/run/docker.sock:/var/run/docker.sock --log-opt max-size=10m --log-opt max-file=3 -v " + installCfg + ":/app/installCfg.json " + dockerHubUrl + "dk_appinstallservice:latest";
    qDebug() << " install cmd = " << cmd;
    system(cmd.toUtf8()); // this is the exemple, download from local.
}
