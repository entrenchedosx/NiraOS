#include <QGuiApplication>
#include <QIcon>
#include <QImage>
#include <QQuickImageProvider>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QFile>
#include "SettingsClient.h"

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

        const QIcon icon = QIcon::fromTheme(id);
        const QImage image = icon.pixmap(target).toImage();
        if (size) *size = image.size();
        return image;
    }
};

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName("nira-settings"_L1);
    QGuiApplication::setApplicationDisplayName("NiraOS Settings"_L1);

    SettingsClient settingsClient;

    QQmlApplicationEngine engine;
    engine.addImageProvider("icon"_L1, new ThemeIconProvider);
    engine.rootContext()->setContextProperty("settingsClient"_L1, &settingsClient);

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() {
            qCritical() << "NiraSettings: FATAL: failed to instantiate Main.qml";
            QCoreApplication::exit(1);
        },
        Qt::QueuedConnection);

    engine.loadFromModule("NiraSettings"_L1, "Main"_L1);

    return app.exec();
}
