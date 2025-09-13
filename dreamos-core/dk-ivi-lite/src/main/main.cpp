#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "../digitalauto/digitalauto.hpp"
#include "../marketplace/marketplace.hpp"
#include "../installedservices/installedservices.hpp"
#include "../installedvapps/installedvapps.hpp"
#include "../controls/controls.hpp"
#include "../platform/integrations/vehicle-api/vapiclient.hpp"
#include "../platform/notifications/notificationmanager.hpp"

#include <QCoreApplication>
#include <QDateTime>
#include <QDebug>

static void myMessageHandler(QtMsgType type,
                             const QMessageLogContext &ctx,
                             const QString &msg)
{
    QByteArray localMsg = msg.toLocal8Bit();
    QString time = QDateTime::currentDateTime()
                       .toString("yyyy-MM-dd hh:mm:ss.zzz");

    const char* typeStr = "";
    switch (type) {
    case QtDebugMsg:    typeStr = "DEBUG";    break;
    case QtWarningMsg:  typeStr = "WARNING";  break;
    case QtCriticalMsg: typeStr = "CRITICAL"; break;
    case QtFatalMsg:    typeStr = "FATAL";    break;
    default:                                break;
    }

    fprintf(stderr, "[%s] [%s] %s\n",
            qPrintable(time), typeStr, localMsg.constData());

    if (type == QtFatalMsg)
        abort();
}

int main(int argc, char *argv[])
{
    // qputenv("QT_IM_MODULE", QByteArray("qtvirtualkeyboard"));

    QGuiApplication app(argc, argv);

    qInstallMessageHandler(myMessageHandler);

    // VAPI Client Initialization
    VAPI_CLIENT.connectToServer(DK_VAPI_DATABROKER);
    
    // Register the notification manager BEFORE creating the engine
    qmlRegisterSingletonType<NotificationManager>("NotificationManager", 1, 0, "NotificationManager",
        [](QQmlEngine *engine, QJSEngine *scriptEngine) -> QObject* {
            Q_UNUSED(engine)
            Q_UNUSED(scriptEngine)
            return &NotificationManager::instance();
        });

    // Pages
    qmlRegisterType<DigitalAutoAppAsync>("DigitalAutoAppAsync", 1, 0, "DigitalAutoAppAsync");
    qmlRegisterType<CategoryListModel>("MyApp",1,0,"CategoryListModel");
    qmlRegisterType<AppListModel>("MyApp",1,0,"AppListModel");
    qmlRegisterType<MarketplaceViewModel>("MyApp",1,0,"MarketplaceViewModel");

    qmlRegisterType<VsersAsync>("VsersAsync", 1, 0, "VsersAsync");
    qmlRegisterType<VappsAsync>("VappsAsync", 1, 0, "VappsAsync");
    qmlRegisterType<ControlsAsync>("ControlsAsync", 1, 0, "ControlsAsync");

    QQmlApplicationEngine engine;
    
    // Expose global notification manager instance to QML context
    engine.rootContext()->setContextProperty("globalNotificationManager", &NotificationManager::instance());
    
    const QUrl url1(QStringLiteral("qrc:/untitled2/main/main.qml"));
    const QUrl url2(QStringLiteral("qrc:/main/main.qml"));

    // Track which url is being tried
    static bool triedFallback = false;

    // Use a lambda that can capture and modify triedFallback
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                 &app, [&engine, &app, url1, url2](QObject *obj, const QUrl &objUrl) mutable {
                     static bool triedFallback = false;
                     if (!obj) {
                         if (!triedFallback && objUrl == url1) {
                             // First URL failed, try second
                             triedFallback = true;
                             engine.load(url2);
                         } else {
                             // Second URL also failed, exit with error
                             QCoreApplication::exit(-1);
                         }
                     }
                 }, Qt::QueuedConnection);

    engine.load(url1);

    return app.exec();
}