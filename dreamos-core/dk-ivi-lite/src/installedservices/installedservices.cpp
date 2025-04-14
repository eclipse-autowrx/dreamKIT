#include "installedservices.hpp"
#include "unsafeparamcheck.hpp"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QThread>
#include <QDebug>
#include <QMutex>

QMutex installedServicesMutex;

extern QString DK_VCU_USERNAME;
extern QString DK_ARCH;
extern QString DK_DOCKER_HUB_NAMESPACE;
extern QString DK_CONTAINER_ROOT;

QString DK_INSTALLED_SERVICE_FOLDER = "";

InstalledServicesCheckThread::InstalledServicesCheckThread(ServicesAsync *parent)
{
    QString mpDataPath = DK_INSTALLED_SERVICE_FOLDER + "installedservices.json";
    // qDebug() << __func__ << "@" << __LINE__ <<  " : mpDataPath: " << mpDataPath;

    m_serviceAsync = parent;
    m_filewatcher = new QFileSystemWatcher(this);

    if (m_filewatcher) {
        QString path = mpDataPath;
        qDebug() << __func__ << __LINE__ << " m_filewatcher : " << path;

        if (QFile::exists(path)) {
            m_filewatcher->addPath(path);
            connect(m_filewatcher, SIGNAL(fileChanged(QString)), m_serviceAsync, SLOT(fileChanged(QString)));
        }
    }
}

void InstalledServicesCheckThread::triggerCheckAppStart(QString id, QString name)
{
    m_appId = id;
    m_appName = name;
    m_istriggeredAppStart = true;
}

void InstalledServicesCheckThread::run()
{
    QString dockerps = DK_INSTALLED_SERVICE_FOLDER + "listservicescmd.log";
    QString cmd = "";     

    while(1) {
        if (m_istriggeredAppStart && !m_appId.isEmpty() && !m_appName.isEmpty()) {
            QThread::msleep(5000); // workaround: wait 2s for the app to start. TODO: consider to check if the start time is more than 2s
            cmd = "docker ps > " + dockerps;
            system(cmd.toUtf8()); 
            QThread::msleep(10);
            QFile MyFile(dockerps);
            MyFile.open(QIODevice::ReadWrite);
            QTextStream in (&MyFile);
            QString raw = in.readAll();
            qDebug() << "reprint docker ps: \n" << raw;
            if (raw.contains(m_appId, Qt::CaseSensitivity::CaseSensitive)) {
                emit resultReady(m_appId, true, "<b>"+m_appName+"</b>" + " is started successfully.");
            }
            else {
                emit resultReady(m_appId, false, "<b>"+m_appName+"</b>" + " is NOT started successfully.<br><br>Please contact the car OEM for more information !!!");
            }
            cmd = "> " + dockerps;
            system(cmd.toUtf8()); 

            m_istriggeredAppStart = false;
            m_appId.clear();
            m_appName.clear();
        }

        QThread::msleep(100);
    }
}

ServicesAsync::ServicesAsync()
{
    if(DK_CONTAINER_ROOT.isEmpty()) {
        DK_CONTAINER_ROOT = qgetenv("DK_CONTAINER_ROOT");
    }
    DK_INSTALLED_SERVICE_FOLDER = DK_CONTAINER_ROOT + "dk_installedservices/";
    qDebug() << __func__ << "@" << __LINE__ <<  " : DK_INSTALLED_SERVICE_FOLDER: " << DK_INSTALLED_SERVICE_FOLDER;

    m_workerThread = new InstalledServicesCheckThread(this);
    connect(m_workerThread, &InstalledServicesCheckThread::resultReady, this, &ServicesAsync::handleResults);
    connect(m_workerThread, &InstalledServicesCheckThread::finished, m_workerThread, &QObject::deleteLater);
    m_workerThread->start();

    m_timer_apprunningcheck = new QTimer(this);
    connect(m_timer_apprunningcheck, SIGNAL(timeout()), this, SLOT(checkRunningAppSts()));
    m_timer_apprunningcheck->start(3000);
}

Q_INVOKABLE void ServicesAsync::openAppEditor(int idx)
{
    qDebug() << __func__ << __LINE__ << " index = " << idx;

    if (idx >= installedServicesList.size()) {
        qDebug() << "index out of range";
        return;
    }

    QString thisServiceFolder = DK_INSTALLED_SERVICE_FOLDER + installedServicesList[idx].id;
    QString vsCodeUserDataFolder = DK_INSTALLED_SERVICE_FOLDER + "/vscode_user_data";
    QString cmd;
    cmd = "mkdir -p " + vsCodeUserDataFolder + ";";
    cmd += "code " + thisServiceFolder + " --no-sandbox --user-data-dir=" + vsCodeUserDataFolder + ";";
    qDebug() << cmd;
    system(cmd.toUtf8());
}

Q_INVOKABLE void ServicesAsync::initInstalledServicesFromDB()
{
    installedServicesMutex.lock();

    clearServicesListView();
    installedServicesList.clear();

    QString mpDataPath = DK_INSTALLED_SERVICE_FOLDER + "installedservices.json";
    qDebug() << __func__ << "@" << __LINE__ <<  " : mpDataPath: " << mpDataPath;

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
        qDebug() << __func__ << "@" << __LINE__ << ": Invalid JSON format.\n" << jsonData;
        return;
    }

    QJsonArray jsonArray = document.array();

    // Loop through each item in the array
    for (const QJsonValue &value : jsonArray) {
        if (!value.isObject()) {
            continue;
        }

        QJsonObject jsonObject = value.toObject();
        ServicesListStruct appInfo;

        // Extract relevant fields for ServicesListStruct
        appInfo.id = jsonObject["_id"].toString();
        appInfo.category = jsonObject["category"].toString();        

        // Extract relevant fields for ServicesListStruct
        appInfo.name = jsonObject["name"].toString();

        // Extract author from 'createdBy' object
        QJsonObject createdBy = jsonObject["createdBy"].toObject();
        if (createdBy.contains("descriptor")) {
            QJsonDocument descriptorDoc = QJsonDocument::fromJson(createdBy["descriptor"].toString().toUtf8());
            QJsonObject descriptorObj = descriptorDoc.object();
            appInfo.author = descriptorObj["name"].toString();
        } else if (createdBy.contains("fullName")) {
            appInfo.author = createdBy["fullName"].toString();
        } else {
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
        // appInfo.packagelink = jsonObject["dashboardConfig"].toString().isEmpty() ? "N/A" : jsonObject["dashboardConfig"].toString();
        // Extract and parse dashboardConfig
        QString dashboardConfigStr = jsonObject["dashboardConfig"].toString();
        if (!dashboardConfigStr.isEmpty()) {
            QJsonDocument dashboardDoc = QJsonDocument::fromJson(dashboardConfigStr.toUtf8());
            QJsonObject dashboardObj = dashboardDoc.object();
    
            if (dashboardObj.contains("DockerImageURL")) {
                appInfo.packagelink = dashboardObj["DockerImageURL"].toString();
            } else {
                appInfo.packagelink = "N/A";
            }
        } else {
            appInfo.packagelink = "N/A";
        }

        // For this example, assume all apps are not installed
        appInfo.isInstalled = false;
        appInfo.isSubscribed = false;

        installedServicesList.append(appInfo);
    }
    qDebug() << "Services list loaded, total apps found:" << installedServicesList.size();

    if (installedServicesList.size()) {
        for(int i = 0; i < installedServicesList.size(); i++) {
            appendServicesInfoToServicesList(installedServicesList[i].name, installedServicesList[i].author,
                                   installedServicesList[i].rating, installedServicesList[i].noofdownload,
                                   installedServicesList[i].iconPath,
                                   installedServicesList[i].isInstalled,
                                   installedServicesList[i].id,
                                   installedServicesList[i].isSubscribed);
        }
    }

    installedServicesMutex.unlock();
}

Q_INVOKABLE void ServicesAsync::executeServices(int appIdx, const QString name, const QString appId, bool isSubscribed)
{
    QString dockerps = DK_INSTALLED_SERVICE_FOLDER + "listservicescmd.log";
    QString cmd = "";
    if (isSubscribed) {
        {
            cmd = "docker ps > " + dockerps;
            system(cmd.toUtf8());            
            QThread::msleep(100);
            QFile MyFile(dockerps);
            MyFile.open(QIODevice::ReadWrite);
            QTextStream in (&MyFile);
            if (in.readAll().contains(appId, Qt::CaseSensitivity::CaseSensitive)) {
                qDebug() << appId << " is already open";
                cmd = "> " + dockerps;
                system(cmd.toUtf8()); 
                return;
            }
            cmd = "> " + dockerps;
            system(cmd.toUtf8()); 
        }

        // QString cmd;
        cmd = "";

        QString dbc_default_path_mount = " -v /home/" + DK_VCU_USERNAME + "/.dk/dk_manager/vssmapping/dbc_default_values.json:/app/vss/dbc_default_values.json:ro ";
        QString dbc_vss_mount = " -v /home/" + DK_VCU_USERNAME + "/.dk/dk_vssgeneration/vss.json:/app/vss/vss.json:ro ";
        
        QString runtimecfgfile = DK_INSTALLED_SERVICE_FOLDER + appId + "/runtimecfg.json";
        QString safeParams = getSafeDockerParam(runtimecfgfile);
        QString audioParams = getAudioParam(runtimecfgfile);

        // start service
        cmd += "docker kill " + appId + ";docker rm " + appId + ";docker run -d -it --name " + appId + " --log-opt max-size=10m --log-opt max-file=3 -v /home/" + DK_VCU_USERNAME + "/.dk/dk_installedservices/" + appId + ":/app/runtime --network host " + dbc_default_path_mount + dbc_vss_mount + safeParams + audioParams + installedServicesList[appIdx].packagelink;
        qDebug() << cmd;
        system(cmd.toUtf8());

        if (m_workerThread) {
            m_workerThread->triggerCheckAppStart(appId, name);
        }
    }
    else {
        QString cmd;
        cmd += "docker kill " + appId + " &";
        // cmd += "docker kill " + appId;
        qDebug() << cmd;
        system(cmd.toUtf8());
    }
}

void readServicesList(const QString searchName, QList<ServicesListStruct> &ServicesListInfo) {
    QString mpDataPath = DK_INSTALLED_SERVICE_FOLDER + "installedservices.json";

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
        ServicesListStruct appInfo;

        // Extract relevant fields for ServicesListStruct
        appInfo.id = jsonObject["_id"].toString();
        appInfo.category = jsonObject["category"].toString();        

        // Extract relevant fields for ServicesListStruct
        appInfo.name = jsonObject["name"].toString();

        // Extract author from 'createdBy' object
        QJsonObject createdBy = jsonObject["createdBy"].toObject();
        if (createdBy.contains("descriptor")) {
            QJsonDocument descriptorDoc = QJsonDocument::fromJson(createdBy["descriptor"].toString().toUtf8());
            QJsonObject descriptorObj = descriptorDoc.object();
            appInfo.author = descriptorObj["name"].toString();
        } else if (createdBy.contains("fullName")) {
            appInfo.author = createdBy["fullName"].toString();
        } else {
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
            ServicesListInfo.append(appInfo);
        }
    }

    qDebug() << "Services list loaded, total apps found:" << ServicesListInfo.size();
}

void ServicesAsync::removeObjectById(const QString &filePath, const QString &idToRemove) {
    // Open the JSON file
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning() << "Failed to open file for reading:" << filePath;
        return;
    }

    // Read the file content and close the file
    QByteArray jsonData = file.readAll();
    file.close();

    // Parse the JSON document
    QJsonDocument jsonDoc = QJsonDocument::fromJson(jsonData);
    if (jsonDoc.isNull() || !jsonDoc.isArray()) {
        qWarning() << "Invalid JSON format.";
        return;
    }

    // Convert the JSON document to an array
    QJsonArray jsonArray = jsonDoc.array();

    // Iterate through the array and find the object with the given _id
    for (int i = 0; i < jsonArray.size(); ++i) {
        QJsonObject obj = jsonArray[i].toObject();
        if (obj.contains("_id") && obj["_id"].toString() == idToRemove) {
            // Remove the object from the array
            jsonArray.removeAt(i);
            qDebug() << "Object with _id:" << idToRemove << "removed.";
            break;
        }
    }

    // Create a new JSON document with the modified array
    QJsonDocument updatedJsonDoc(jsonArray);

    // Open the file again for writing
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        qWarning() << "Failed to open file for writing:" << filePath;
        return;
    }

    // Write the updated JSON data to the file
    file.write(updatedJsonDoc.toJson(QJsonDocument::Indented));
    file.close();
    qDebug() << "Updated JSON file saved.";
}

Q_INVOKABLE void ServicesAsync::removeServices(const int index)
{
    qDebug() << __func__ << "@" << __LINE__ <<  " : index: " << index;
    // refresh install app view
    //initInstalledServicesFromDB();
    QString mpDataPath = DK_INSTALLED_SERVICE_FOLDER + "installedservices.json";
    removeObjectById(mpDataPath, installedServicesList[index].id);
}

void ServicesAsync::handleResults(QString appId, bool isStarted, QString msg)
{
    updateStartAppMsg(appId, isStarted, msg);
    if (isStarted) {
        int len = installedServicesList.size();
        for (int i = 0; i < len; i++) {
            if (installedServicesList[i].id == appId) {
                installedServicesList[i].isSubscribed = true;
                return;
            }
        }
    }
}

void ServicesAsync::fileChanged(const QString &path)
{
    qDebug() << __func__ << "@" << __LINE__ <<  " : path: " << path;
    QThread::msleep(1000);
    initInstalledServicesFromDB();
}

void ServicesAsync::checkRunningAppSts()
{    
    QString appStsLog = DK_INSTALLED_SERVICE_FOLDER + "checkRunningServicesSts.log";
    QString cmd = "> " + appStsLog + "; docker ps > " + appStsLog;
    system(cmd.toUtf8());
    
    QFile logFile(appStsLog);
    if (!logFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qCritical() << "Failed to open log file: checkRunningServicesSts.log";
        return;
    }

    QTextStream in(&logFile);
    QString content = in.readAll();

    if (content.isEmpty()) {
        qCritical() << "Log file is empty or could not be read.";
        return;
    }

    int len = installedServicesList.size();
    // qDebug() << __func__ << "@" << __LINE__ <<  " : installedServicesList len: " << len;
    for (int i = 0; i < len; i++) {
        if (!installedServicesList[i].id.isEmpty()) {
            if (content.contains(installedServicesList[i].id)) {
                // qDebug() << "App ID" << installedServicesList[i].appId << "is running.";
                updateServicesRunningSts(installedServicesList[i].id, true, i);
            } else {
                // qDebug() << "App ID" << installedServicesList[i].appId << "is not running.";
                updateServicesRunningSts(installedServicesList[i].id, false, i);
            }
        }        
    }
}