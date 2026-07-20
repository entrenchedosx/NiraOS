#include <QGuiApplication>
#include <QIcon>
#include <QImage>
#include <QQuickImageProvider>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include "AiClient.h"
#include "ProcessLauncher.h"
#include "AppModel.h"
#include "FilteredAppModel.h"
#include "TaskbarModel.h"
#include "DesktopIconModel.h"
#include "TrashIconState.h"
#include "NotificationClient.h"
#include "WallpaperModel.h"
#include "VolumeControl.h"
#include "PowerStatus.h"
#include "WorkspaceController.h"
#include "../../common/DesktopMetrics.h"

using namespace Qt::StringLiterals;

class ThemeIconProvider final : public QQuickImageProvider
{
public:
    ThemeIconProvider()
        : QQuickImageProvider(QQuickImageProvider::Image)
    {
    }

    QImage requestImage(const QString &id, QSize *size,
                        const QSize &requestedSize) override
    {
        const QSize target = requestedSize.isValid() ? requestedSize : QSize(48, 48);

        // 1. If the id is a NiraOS-specific icon bundled in the qrc, load it
        //    directly.  The qrc aliases map "trash-empty" -> trash-empty.svg
        //    etc., so the id matches the asset name without extension.
        const QString qrcSvg = u":/nira/icons/%1.svg"_s.arg(id);
        if (QFile::exists(qrcSvg)) {
            QImage img(qrcSvg);
            if (!img.isNull()) {
                if (size) *size = img.size();
                return img.scaled(target, Qt::KeepAspectRatio, Qt::SmoothTransformation);
            }
        }
        const QString qrcPng = u":/nira/icons/%1-48.png"_s.arg(id);
        if (QFile::exists(qrcPng)) {
            QImage img(qrcPng);
            if (!img.isNull()) {
                if (size) *size = img.size();
                return img.scaled(target, Qt::KeepAspectRatio, Qt::SmoothTransformation);
            }
        }

        // 2. Fall back to the system icon theme (breeze-dark / hicolor).
        const QIcon icon = QIcon::fromTheme(id);
        const QImage image = icon.pixmap(target).toImage();
        if (size)
            *size = image.size();
        return image;
    }
};

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName("nira-shell"_L1);
    QGuiApplication::setApplicationDisplayName("NiraOS Shell"_L1);
    QGuiApplication::setOrganizationName("NiraOS"_L1);
    QIcon::setThemeName("breeze-dark"_L1);
    QIcon::setFallbackThemeName("hicolor"_L1);

    AiClient aiClient;
    ProcessLauncher processLauncher;
    AppModel appModel;
    TaskbarModel taskbarModel;
    DesktopIconModel desktopIconModel;
    TrashIconState trashIconState;
    NotificationClient notificationClient;
    WallpaperModel wallpaperModel;
    VolumeControl volumeControl;
    PowerStatus powerStatus;
    WorkspaceController workspaceController;

    QQmlApplicationEngine engine;
    engine.addImageProvider("icon"_L1, new ThemeIconProvider);

    engine.rootContext()->setContextProperty("aiClient", &aiClient);
    engine.rootContext()->setContextProperty("processLauncher", &processLauncher);
    FilteredAppModel filteredAppModel;
    filteredAppModel.setSourceModel(&appModel);
    engine.rootContext()->setContextProperty("appModel", &filteredAppModel);
    engine.rootContext()->setContextProperty("taskbarModel", &taskbarModel);
    engine.rootContext()->setContextProperty("desktopIconModel", &desktopIconModel);
    engine.rootContext()->setContextProperty("trashIconState", &trashIconState);
    engine.rootContext()->setContextProperty("notificationClient", &notificationClient);
    engine.rootContext()->setContextProperty("wallpaperModel", &wallpaperModel);
    engine.rootContext()->setContextProperty("volumeControl", &volumeControl);
    engine.rootContext()->setContextProperty("powerStatus", &powerStatus);
    engine.rootContext()->setContextProperty("workspaceController", &workspaceController);
    static NiraDesktopMetrics metrics;
    engine.rootContext()->setContextProperty("desktopMetrics"_L1, &metrics);

    qInfo() << "NiraShell starting;"
            << "platform =" << QGuiApplication::platformName()
            << "wayland display =" << qgetenv("WAYLAND_DISPLAY")
            << "application =" << QGuiApplication::applicationName()
            << "desktop icons =" << desktopIconModel.iconCount()
            << "wallpapers =" << wallpaperModel.rowCount()
            << "volume available =" << volumeControl.available()
            << "battery present =" << powerStatus.present();

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() {
            qCritical() << "NiraShell: FATAL: failed to instantiate"
                        << "Main.qml from module NiraOS";
            QCoreApplication::exit(1);
        },
        Qt::QueuedConnection);

    engine.loadFromModule("NiraOS"_L1, "Main"_L1);

    return app.exec();
}
