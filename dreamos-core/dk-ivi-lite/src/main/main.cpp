#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "../digitalauto/digitalauto.hpp"
#include "../marketplace/marketplace.hpp"
#include "../installedservices/installedservices.hpp"
#include "../installedvapps/installedvapps.hpp"
#include "../controls/controls.hpp"
#include "../library/vapiclient/vapiclient.hpp"

int main(int argc, char *argv[])
{
    // qputenv("QT_IM_MODULE", QByteArray("qtvirtualkeyboard"));

    QGuiApplication app(argc, argv);

    // VAPI Client Initilization
    VAPI_CLIENT.connectToServer(DK_VAPI_DATABROKER);
    // Pages
    qmlRegisterType<DigitalAutoAppAsync>("DigitalAutoAppAsync", 1, 0, "DigitalAutoAppAsync");
    qmlRegisterType<MarketplaceAsync>("MarketplaceAsync", 1, 0, "MarketplaceAsync");
    qmlRegisterType<ServicesAsync>("ServicesAsync", 1, 0, "ServicesAsync");
    qmlRegisterType<VappsAsync>("VappsAsync", 1, 0, "VappsAsync");
    qmlRegisterType<ControlsAsync>("ControlsAsync", 1, 0, "ControlsAsync");

    QQmlApplicationEngine engine;
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
