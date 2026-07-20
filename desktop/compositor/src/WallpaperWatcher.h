#pragma once

#include <QFileSystemWatcher>
#include <QObject>
#include <QString>
#include <QUrl>

/// Watches the desktop wallpaper installed by the action manager.
///
/// Caches the resolved wallpaper URL to avoid QFileInfo::exists() on every
/// QML binding evaluation. Only re-resolves when the filesystem watcher fires.
class WallpaperWatcher : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QUrl wallpaperSource READ wallpaperSource NOTIFY wallpaperChanged)

public:
    explicit WallpaperWatcher(QObject *parent = nullptr);
    QUrl wallpaperSource() const { return cachedSource_; }

signals:
    void wallpaperChanged();

private slots:
    void onPathChanged();

private:
    void armWatches();
    void refreshCache();

    QFileSystemWatcher watcher_;
    QString directoryPath_;
    QString wallpaperPath_;
    QString fallbackPath_;
    QUrl cachedSource_;
};
