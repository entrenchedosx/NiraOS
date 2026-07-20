#include <QDir>
#include <QGuiApplication>
#include <QIcon>
#include <QImage>
#include <QQuickImageProvider>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QStandardPaths>
#include <QVariantMap>
#include <QFile>
#include "FileModel.h"
#include "FileOperations.h"
#include "FileSystemWatcher.h"
#include "ThumbnailProvider.h"
#include "SearchIndexer.h"
#include "StorageManager.h"
#include "../../desktop/common/DesktopMetrics.h"

using namespace Qt::StringLiterals;

// ThemeIconProvider: resolves `image://icon/<name>` references in QML.
// Checks the NiraOS qrc bundle first (files-assets.qrc), then falls back
// to the system icon theme.  This mirrors the shell's ThemeIconProvider
// so file-manager icons render identically.
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

        // Try NiraOS qrc bundle first.
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
        // Same for filemanager-prefixed icons.
        const QString fmSvg = u":/nira/filemanager/%1.svg"_s.arg(id);
        if (QFile::exists(fmSvg)) {
            QImage img(fmSvg);
            if (!img.isNull()) {
                if (size) *size = img.size();
                return img.scaled(target, Qt::KeepAspectRatio, Qt::SmoothTransformation);
            }
        }

        // Fall back to the system icon theme (breeze-dark / hicolor).
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
    QGuiApplication::setApplicationName("nira-files"_L1);
    QGuiApplication::setApplicationDisplayName("NiraOS Files"_L1);
    QGuiApplication::setOrganizationName("NiraOS"_L1);
    QIcon::setThemeName("breeze-dark"_L1);
    QIcon::setFallbackThemeName("hicolor"_L1);
    QQuickStyle::setStyle("Fusion"_L1);

    FileModel fileModel;
    FileOperations fileOperations;
    FileSystemWatcher fileSystemWatcher;
    SearchIndexer searchIndexer;
    StorageManager storageManager;

    QQmlApplicationEngine engine;
    engine.addImageProvider("thumbnail"_L1, new ThumbnailProvider);
    engine.addImageProvider("icon"_L1, new ThemeIconProvider);

    engine.rootContext()->setContextProperty("fileModel", &fileModel);
    engine.rootContext()->setContextProperty("fileOperations", &fileOperations);
    engine.rootContext()->setContextProperty("fileSystemWatcher", &fileSystemWatcher);
    engine.rootContext()->setContextProperty("searchIndexer", &searchIndexer);
    engine.rootContext()->setContextProperty("storageManager", &storageManager);
    static NiraDesktopMetrics metrics;
    engine.rootContext()->setContextProperty("desktopMetrics"_L1, &metrics);

    // Expose standard paths to QML
    QVariantMap stdPaths;
    stdPaths["home"_L1]      = QStandardPaths::writableLocation(QStandardPaths::HomeLocation);
    stdPaths["documents"_L1] = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    stdPaths["downloads"_L1] = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
    stdPaths["pictures"_L1]  = QStandardPaths::writableLocation(QStandardPaths::PicturesLocation);
    stdPaths["videos"_L1]    = QStandardPaths::writableLocation(QStandardPaths::MoviesLocation);
    stdPaths["music"_L1]     = QStandardPaths::writableLocation(QStandardPaths::MusicLocation);
    stdPaths["desktop"_L1]   = QStandardPaths::writableLocation(QStandardPaths::DesktopLocation);
    stdPaths["trash"_L1]     = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + "/Trash/files"_L1;
    engine.rootContext()->setContextProperty("standardPaths"_L1, stdPaths);

    // Auto-navigate to home on startup
    fileModel.setCurrentPath(stdPaths["home"_L1].toString());

    // Connect watcher to model refresh
    QObject::connect(&fileSystemWatcher, &FileSystemWatcher::directoryChanged,
                     &fileModel, &FileModel::refresh);
    QObject::connect(&fileModel, &FileModel::currentPathChanged,
                     [&]() { fileSystemWatcher.setWatchedPath(fileModel.currentPath()); });

    qInfo() << "NiraFiles starting; home =" << QDir::homePath();

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() {
            qCritical() << "NiraFiles: FATAL: failed to instantiate Main.qml";
            QCoreApplication::exit(1);
        },
        Qt::QueuedConnection);

    engine.loadFromModule("NiraFiles"_L1, "Main"_L1);

    return app.exec();
}
