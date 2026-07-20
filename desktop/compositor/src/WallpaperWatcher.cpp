#include "WallpaperWatcher.h"

#include <QDir>
#include <QFileInfo>

WallpaperWatcher::WallpaperWatcher(QObject *parent)
    : QObject(parent)
    , directoryPath_(QStringLiteral("/var/lib/niraos/desktop"))
    , wallpaperPath_(directoryPath_ + QStringLiteral("/wallpaper.png"))
    , fallbackPath_(QStringLiteral("/usr/share/niraos/wallpapers/default.png"))
{
    connect(&watcher_, &QFileSystemWatcher::directoryChanged,
            this, &WallpaperWatcher::onPathChanged);
    connect(&watcher_, &QFileSystemWatcher::fileChanged,
            this, &WallpaperWatcher::onPathChanged);
    armWatches();
    refreshCache();
}

void WallpaperWatcher::refreshCache()
{
    const QString &path = QFileInfo::exists(wallpaperPath_)
        ? wallpaperPath_ : fallbackPath_;
    cachedSource_ = QUrl::fromLocalFile(path);
}

void WallpaperWatcher::onPathChanged()
{
    armWatches();
    refreshCache();
    emit wallpaperChanged();
}

void WallpaperWatcher::armWatches()
{
    if (QFileInfo::exists(directoryPath_)
        && !watcher_.directories().contains(directoryPath_)) {
        watcher_.addPath(directoryPath_);
    }
    if (QFileInfo::exists(wallpaperPath_)
        && !watcher_.files().contains(wallpaperPath_)) {
        watcher_.addPath(wallpaperPath_);
    }
}
