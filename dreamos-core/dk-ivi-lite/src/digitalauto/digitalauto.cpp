#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include "digitalauto.hpp"
#include <QFile>
#include <QStringList>
#include <QDebug>
#include <QThread>
#include <QMutex>
#include <QFileInfo>

#include <QJsonDocument>
#include <QJsonValue>
#include <QJsonArray>
#include <QJsonObject>

//#include <notification/notification.hpp>
//extern NotificationAsync *carNotifAsync;

QString DK_VCU_USERNAME = "sdv";
QString DK_ARCH = "arm64";
QString DK_DOCKER_HUB_NAMESPACE = "";
QString DK_CONTAINER_ROOT       = "";

QString DK_MGR_DIR              = DK_CONTAINER_ROOT + "dk_manager/";
QString digitalautoDeployFolder = DK_MGR_DIR + "prototypes/";
QString digitalautoDeployFile   = digitalautoDeployFolder + "prototypes.json";
QString DK_DREAMKIT_UNIQUE_SERIAL_NUMBER_FILE = DK_MGR_DIR + "serial-number";
// QString DK_BOARD_UNIQUE_SERIAL_NUMBER_FILE    = "/proc/device-tree/serial-number";


QMutex digitalAutoPrototypeMutex;

DigitalAutoAppCheckThread::DigitalAutoAppCheckThread(DigitalAutoAppAsync *parent)
{
    m_digitalAutoAppAsync = parent;
    m_filewatcher = new QFileSystemWatcher(this);

    if (m_filewatcher) {
        QString path = digitalautoDeployFile;
        qDebug() << __func__ << __LINE__ << " m_filewatcher : " << digitalautoDeployFile;

        if (QFile::exists(path)) {
            m_filewatcher->addPath(path);
            connect(m_filewatcher, SIGNAL(fileChanged(QString)), m_digitalAutoAppAsync, SLOT(fileChanged(QString)));
        }
    }
}

void DigitalAutoAppCheckThread::triggerCheckAppStart(QString id, QString name)
{
    m_appId = id;
    m_appName = name;
    m_istriggeredAppStart = true;
}

void DigitalAutoAppCheckThread::run()
{
    QString dockerps = digitalautoDeployFolder + "listcmd.log";
    QString cmd = "";     

    while(1) {
        if (m_istriggeredAppStart && !m_appId.isEmpty() && !m_appName.isEmpty()) {
            QThread::msleep(3000); // workaround: wait 2s for the app to start. TODO: consider to check if the start time is more than 2s
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

bool digitalAutoFileExists(std::string path) {
    QFileInfo check_file(QString::fromStdString(path));
    // check if path exists and if yes: Is it really a file and no directory?
    return check_file.exists() && check_file.isFile();
}

DigitalAutoAppAsync::DigitalAutoAppAsync()
{
    m_appListInfo.clear();

    // QString serialNo = "dreamKIT-";

    QString prefix = "";
    prefix = qgetenv("DKCODE");
    if(prefix.isEmpty()) {
        prefix = "Target-Runtime";
    }

    // get DK_VCU_USERNAME env var
    DK_VCU_USERNAME = qgetenv("DK_USER");
    DK_ARCH = qgetenv("DK_ARCH");
    DK_DOCKER_HUB_NAMESPACE = qgetenv("DK_DOCKER_HUB_NAMESPACE");

    QString rootDirEnv = "";
    rootDirEnv = qgetenv("DK_CONTAINER_ROOT");
    if(!rootDirEnv.isEmpty()) {
        DK_CONTAINER_ROOT = rootDirEnv;
        DK_MGR_DIR              = DK_CONTAINER_ROOT + "dk_manager/";
        digitalautoDeployFolder = DK_MGR_DIR + "prototypes/";
        digitalautoDeployFile   = digitalautoDeployFolder + "prototypes.json";
        DK_DREAMKIT_UNIQUE_SERIAL_NUMBER_FILE = DK_MGR_DIR + "serial-number";
    } 

    QString serialNo = "";
    if(digitalAutoFileExists(DK_DREAMKIT_UNIQUE_SERIAL_NUMBER_FILE.toStdString())) {
    	QFile serialNoFile(DK_DREAMKIT_UNIQUE_SERIAL_NUMBER_FILE);
    	if (!serialNoFile.open(QIODevice::ReadOnly)) {
    		qDebug() << __func__ << __LINE__ << serialNoFile.errorString();
    	}
    	else {
    		QTextStream outputStream (&serialNoFile);
    		serialNo += outputStream.readAll();
    		serialNoFile.close();
    	}
    }
    else {
        serialNo += "xxxxxxxxxxxxxxx";
    }


    serialNo.remove(QChar::Null);
    serialNo.replace("\n", "");
    if((serialNo.length()>8)) {
        serialNo = serialNo.right(8);
    }
    m_serialNo = prefix + "-" + serialNo;

    qDebug() << __func__ << __LINE__ << "serialNo: " << m_serialNo;
    qDebug() << __func__ << __LINE__ << " DK_VCU_USERNAME : " << DK_VCU_USERNAME;
    qDebug() << __func__ << __LINE__ << " DK_CONTAINER_ROOT : " << DK_CONTAINER_ROOT;

    workerThread = new DigitalAutoAppCheckThread(this);
    connect(workerThread, &DigitalAutoAppCheckThread::resultReady, this, &DigitalAutoAppAsync::handleResults);
    connect(workerThread, &DigitalAutoAppCheckThread::finished, workerThread, &QObject::deleteLater);
    workerThread->start();

    m_timer = new QTimer(this);
    connect(m_timer, SIGNAL(timeout()), this, SLOT(updateDeploymentProgress()));
    m_timer->stop();
    m_deploymentProgressPercent = 0;

    m_timer_apprunningcheck = new QTimer(this);
    connect(m_timer_apprunningcheck, SIGNAL(timeout()), this, SLOT(checkRunningAppSts()));
    m_timer_apprunningcheck->start(3000);
}

void DigitalAutoAppAsync::checkRunningAppSts()
{    
    QString appStsLog = digitalautoDeployFolder + "checkRunningAppSts.log";
    QString cmd = "> " + appStsLog + "; docker ps > " + appStsLog;
    system(cmd.toUtf8());
    
    QFile logFile(appStsLog);
    if (!logFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qCritical() << "Failed to open log file: checkRunningAppSts.log";
        return;
    }

    QTextStream in(&logFile);
    QString content = in.readAll();

    if (content.isEmpty()) {
        qCritical() << "Log file is empty or could not be read.";
        return;
    }

    int len = m_appListInfo.size();
    for (int i = 0; i < len; i++) {
        if (!m_appListInfo[i].appId.isEmpty()) {
            if (content.contains(m_appListInfo[i].appId)) {
                // qDebug() << "App ID" << m_appListInfo[i].appId << "is running.";
                updateAppRunningSts(m_appListInfo[i].appId, true, i);
            } else {
                // qDebug() << "App ID" << m_appListInfo[i].appId << "is not running.";
                updateAppRunningSts(m_appListInfo[i].appId, false, i);
            }
        }        
    }
}

void DigitalAutoAppAsync::updateDeploymentProgress()
{
//    qDebug() << "updateDeploymentProgress = " << m_deploymentProgressPercent;

    m_deploymentProgressPercent += 10;

    updateProgressValue(m_deploymentProgressPercent);
    if(m_deploymentProgressPercent == 100) {
        initSubscribeAppFromDB();
    }
    else if(m_deploymentProgressPercent == 200) {
        m_timer->stop();
        setProgressVisibility(false);
    }
}

Q_INVOKABLE void DigitalAutoAppAsync::initSubscribeAppFromDB()
{
    // using mutex to project run-time data struct. e.g., if removing app and deploying app occurs quite the same time,
    // then this function shall be called at the same time. it would corrupt the m_appListInfo
    digitalAutoPrototypeMutex.lock();

    clearAppListView();
    updateBoardSerialNumber(m_serialNo);

    QString filename = digitalautoDeployFile;

    QFile file(filename);
    file.open(QIODevice::ReadOnly|QIODevice::Text);
    if (file.isOpen()) {
        QString data = QString(file.readAll());
        file.close();
//        qDebug() << "raw file: " << data;
        QJsonArray jsonAppList = QJsonDocument::fromJson(data.toUtf8()).array();

        QList<DigitalAutoAppListStruct> appListInfo;

        for (const auto obj : jsonAppList) {
            DigitalAutoAppListStruct appInfo;

            if (QJsonValue::Undefined != obj.toObject().value("deployFrom").type())
            {
                appInfo.deployFrom = obj.toObject().value("deployFrom").toString();
            }

            if (QJsonValue::Undefined != obj.toObject().value("execType").type())
            {
                appInfo.execType = obj.toObject().value("execType").toString();
            }

//            qDebug() << obj.toObject().value("name").toString();
            appInfo.name = obj.toObject().value("name").toString();

//            qDebug() << obj.toObject().value("id").toString();
            appInfo.appId = obj.toObject().value("id").toString();

//            qDebug() << QString().setNum(obj.toObject().value("lastDeploy").toDouble(), 'g', 13);
            appInfo.lastDeploy = QString().setNum(obj.toObject().value("lastDeploy").toDouble(), 'g', 13);

            appInfo.isSubscribed = false;

            int len = m_appListInfo.size();
            for (int i = 0; i < len; i++) {
                if (m_appListInfo[i].appId == appInfo.appId) {
                    appInfo.isSubscribed = m_appListInfo[i].isSubscribed;
                    break;
                }
            }

            appListInfo.append(appInfo);

//            qDebug() << appInfo.name << " - " << appInfo.appId << " - " << appInfo.isSubscribed << " -------------------------- ";
            appendAppInfoToAppList(appInfo.name, appInfo.appId, appInfo.isSubscribed);
        }

        m_appListInfo.clear();
        m_appListInfo = appListInfo;
    }
    else {
        qDebug() << filename << " is not existing";
    }

    digitalAutoPrototypeMutex.unlock();
}


Q_INVOKABLE void DigitalAutoAppAsync::openAppEditor(int idx)
{
    qDebug() << __func__ << __LINE__ << " index = " << idx;

    if (idx >= m_appListInfo.size()) {
        qDebug() << "index out of range";
        return;
    }

    m_appListInfo[idx].appId;

    QString thisServiceFolder = digitalautoDeployFolder + m_appListInfo[idx].appId;
    QString vsCodeUserDataFolder = digitalautoDeployFolder + "/vscode_user_data";
    QString cmd;
    cmd = "mkdir -p " + vsCodeUserDataFolder + ";";
    cmd += "code " + thisServiceFolder + " --no-sandbox --user-data-dir=" + vsCodeUserDataFolder + ";";
    qDebug() << cmd;
    system(cmd.toUtf8());
}

Q_INVOKABLE void DigitalAutoAppAsync::removeApp(int idx)
{
    qDebug() << __func__ << __LINE__ << " index = " << idx;

    if (idx >= m_appListInfo.size()) {
        qDebug() << "index out of range";
        return;
    }

    // if the app is open, then stop it
    if (m_appListInfo[idx].isSubscribed) {
        // popup a window saying "The app is still open. Please stop it first."
        executeApp(m_appListInfo[idx].name, m_appListInfo[idx].appId, false);
    }

    // delete in Json file
    QString filename = digitalautoDeployFile;
    QFile file(filename);
    file.open(QIODevice::ReadWrite|QIODevice::Text);
    if (file.isOpen()) {
        QString data = QString(file.readAll());
        QJsonDocument doc = QJsonDocument::fromJson(data.toUtf8());
        QJsonArray jsonAppList = doc.array();
//        qDebug() << "raw file: " << data;
//        qDebug() << "before: \n" << doc;
        jsonAppList.removeAt(idx);
        QJsonDocument newDoc(jsonAppList);
//        qDebug() << "after: \n" << newDoc;
        file.resize(0);
        file.write(newDoc.toJson());
        file.close();
    }

    // delete in the list
    m_appListInfo.remove(idx);

    QThread::msleep(100);
    system("sync");
}

Q_INVOKABLE void DigitalAutoAppAsync::executeApp(const QString name, const QString appId, bool isSubsribed)
{
    QString dockerps = digitalautoDeployFolder + "listcmd.log";
    QString cmd = "";
    if (isSubsribed) {
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

        QString execType_;
        int len = m_appListInfo.size();
        for (int i = 0; i < len; i++)
        {
            if (m_appListInfo[i].appId == appId)
            {
                execType_ = m_appListInfo[i].execType;
                break;
            }
        }

        // QString cmd;
        cmd = "";

        if (execType_ == "py")
        {
            // start py app
            cmd += "docker kill " + appId + ";docker rm " + appId + ";docker run -d -it --network dk_network --name " + appId + " --log-opt max-size=10m --log-opt max-file=3 -v /home/" + DK_VCU_USERNAME + "/.dk/dk_vssgeneration/vehicle_gen/:/home/vss/vehicle_gen:ro -v /home/" + DK_VCU_USERNAME + "/.dk/dk_app_python_template/target/" + DK_ARCH + "/python-packages:/home/python-packages:ro -v /home/" + DK_VCU_USERNAME + "/.dk/dk_manager/prototypes/" + appId + ":/app/exec " + DK_DOCKER_HUB_NAMESPACE + "/dk_app_python_template:baseimage";
        }
        else if (execType_ == "cpp")
        {
            // start cpp app
            cmd += "docker kill " + appId + ";docker rm " + appId + ";docker run -d -it --network dk_network --name " + appId + " --log-opt max-size=10m --log-opt max-file=3 -v /home/" + DK_VCU_USERNAME + "/.dk/dk_app_cpp_template/target/" + DK_ARCH + "/cpp:/app/lib:ro -v /home/" + DK_VCU_USERNAME + "/.dk/dk_manager/prototypes/" + appId + ":/app/exec " + DK_DOCKER_HUB_NAMESPACE + "/dk_app_cpp_template:latest";
        }
        else {
            qDebug() << "execType " << execType_ << " is not supported !!!";
        }
        
        qDebug() << cmd;
        system(cmd.toUtf8());

        if (workerThread) {
            workerThread->triggerCheckAppStart(appId, name);
        }
    }
    else {
        QString cmd;
        cmd += "docker kill " + appId + " &";
        // cmd += "docker kill " + appId ;
        qDebug() << cmd;
        system(cmd.toUtf8());

        int len = m_appListInfo.size();
        for (int i = 0; i < len; i++) {
            if (m_appListInfo[i].appId == appId) {
                m_appListInfo[i].isSubscribed = false;
                return;
            }
        }
    }
}

void DigitalAutoAppAsync::handleResults(QString appId, bool isStarted, QString msg)
{
    updateStartAppMsg(appId, isStarted, msg);
    if (isStarted) {
        int len = m_appListInfo.size();
        for (int i = 0; i < len; i++) {
            if (m_appListInfo[i].appId == appId) {
                m_appListInfo[i].isSubscribed = true;
                return;
            }
        }
    }
}

void DigitalAutoAppAsync::fileChanged(const QString &path)
{
    m_timer->start(200);
    m_deploymentProgressPercent = 0;
    updateProgressValue(m_deploymentProgressPercent);
    qDebug() << "file changed: " << path;
    setProgressVisibility(true);

//    initSubscribeAppFromDB();
//    carNotifAsync->showNotificationFromBackend("There is an update from digital.auto", 1);
}
