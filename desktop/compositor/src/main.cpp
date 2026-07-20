#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QLoggingCategory>
#include <QScreen>
#include "ContextExporter.h"
#include "WallpaperWatcher.h"
#include "WindowManagerDBus.h"
#include "../../common/DesktopMetrics.h"

using namespace Qt::StringLiterals;

static int detectOutputScaleFactor()
{
    // Determine the correct Wayland output scale factor.
    // Returns 0 to let the QML binding auto-detect, or a fixed value (1)
    // when the screen reports invalid physical dimensions.
    QScreen *screen = QGuiApplication::primaryScreen();
    if (!screen)
        return 0;

    QSizeF physMm = screen->physicalSize();
    qreal dpr = screen->devicePixelRatio();
    qreal logDpiX = screen->logicalDotsPerInchX();
    qreal logDpiY = screen->logicalDotsPerInchY();
    QSize pxSize = screen->size();

    qInfo().nospace()
        << "NiraCompositor: screen " << screen->name()
        << "  pixel=" << pxSize.width() << "x" << pxSize.height()
        << "  phys_mm=" << physMm.width() << "x" << physMm.height()
        << "  dpr=" << dpr
        << "  logDPI=" << logDpiX << "x" << logDpiY;

    // When physical dimensions are 0x0 (common with virtio-gpu without EDID),
    // Qt may calculate an incorrect DPR > 1, compressing the logical coordinate
    // space and causing the UI to appear zoomed.  Force scale factor to 1 so
    // Wayland clients receive a full-resolution logical workspace.
    if (physMm.width() <= 0 || physMm.height() <= 0) {
        qWarning() << "NiraCompositor: screen has invalid physical size (0x0 mm)."
                    << "Forcing output scaleFactor=1 to prevent DPI zoom.";
        return 1;
    }
    return 0;
}

int main(int argc, char *argv[]) {
    // Software OpenGL rendering via llvmpipe — compatible with eglfs_kms.
    // Do NOT set QT_QUICK_BACKEND=software (pure rasterizer); that breaks
    // eglfs_kms buffer exchange and cursor rendering.  llvmpipe provides
    // software OpenGL which works correctly with KMS/DRM.
    if (qEnvironmentVariableIsEmpty("LIBGL_ALWAYS_SOFTWARE"))
        qputenv("LIBGL_ALWAYS_SOFTWARE", "1");
    if (qEnvironmentVariableIsEmpty("GALLIUM_DRIVER"))
        qputenv("GALLIUM_DRIVER", "llvmpipe");

    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName("NiraCompositor"_L1);

    qInfo() << "NiraCompositor starting;"
            << "platform =" << QGuiApplication::platformName()
            << "runtime dir =" << qgetenv("XDG_RUNTIME_DIR");

    ContextExporter contextExporter;
    WallpaperWatcher wallpaperWatcher;
    WindowManagerDBus wmDBus;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("contextExporter"_L1, &contextExporter);
    engine.rootContext()->setContextProperty("wallpaperWatcher"_L1, &wallpaperWatcher);
    engine.rootContext()->setContextProperty("wmDBus"_L1, &wmDBus);
    static NiraDesktopMetrics metrics;
    engine.rootContext()->setContextProperty("desktopMetrics"_L1, &metrics);
    engine.rootContext()->setContextProperty("outputScaleFactor"_L1,
                                             detectOutputScaleFactor());

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() {
            qCritical() << "NiraCompositor: FATAL: failed to instantiate"
                        << "Main.qml from module NiraCompositor";
            QCoreApplication::exit(1);
        },
        Qt::QueuedConnection);

    engine.loadFromModule("NiraCompositor"_L1, "Main"_L1);

    return app.exec();
}
