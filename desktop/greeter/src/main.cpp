#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include "GreeterIPC.h"
#include "UserModel.h"

using namespace Qt::StringLiterals;

int main(int argc, char *argv[])
{
    // The greeter runs before any Wayland compositor or X server.
    // Render directly to DRM/KMS via eglfs, same as the compositor.
    if (qEnvironmentVariableIsEmpty("QT_QPA_PLATFORM"))
        qputenv("QT_QPA_PLATFORM", "eglfs");
    if (qEnvironmentVariableIsEmpty("QT_QPA_EGLFS_INTEGRATION"))
        qputenv("QT_QPA_EGLFS_INTEGRATION", "eglfs_kms");
    if (qEnvironmentVariableIsEmpty("QSG_INFO"))
        qputenv("QSG_INFO", "1");
    if (qEnvironmentVariableIsEmpty("LANG"))
        qputenv("LANG", "C.UTF-8");
    // Software OpenGL via llvmpipe — compatible with eglfs_kms.
    // Do NOT set QT_QUICK_BACKEND=software (pure rasterizer); that breaks
    // eglfs_kms buffer exchange and cursor rendering.
    if (qEnvironmentVariableIsEmpty("LIBGL_ALWAYS_SOFTWARE"))
        qputenv("LIBGL_ALWAYS_SOFTWARE", "1");
    if (qEnvironmentVariableIsEmpty("GALLIUM_DRIVER"))
        qputenv("GALLIUM_DRIVER", "llvmpipe");

    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName("nira-greeter"_L1);
    QGuiApplication::setApplicationDisplayName("NiraOS Greeter"_L1);

    GreeterIPC greeterIPC;
    UserModel userModel;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("greeterIPC"_L1, &greeterIPC);
    engine.rootContext()->setContextProperty("userModel"_L1, &userModel);

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() {
            qCritical() << "NiraGreeter: FATAL: failed to instantiate Main.qml";
            QCoreApplication::exit(1);
        },
        Qt::QueuedConnection);

    engine.loadFromModule("NiraGreeter"_L1, "Main"_L1);

    return app.exec();
}
