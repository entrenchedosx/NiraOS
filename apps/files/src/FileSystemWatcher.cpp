#include "FileSystemWatcher.h"

FileSystemWatcher::FileSystemWatcher(QObject *parent)
    : QObject(parent)
{
    connect(&watcher_, &QFileSystemWatcher::directoryChanged,
            this, &FileSystemWatcher::onDirectoryChanged);
    connect(&watcher_, &QFileSystemWatcher::fileChanged,
            this, &FileSystemWatcher::onFileChanged);

    debounceTimer_.setSingleShot(true);
    debounceTimer_.setInterval(300);
    connect(&debounceTimer_, &QTimer::timeout,
            this, &FileSystemWatcher::onDebounceTimeout);
}

QString FileSystemWatcher::watchedPath() const
{
    return watchedPath_;
}

void FileSystemWatcher::setWatchedPath(const QString &path)
{
    if (path == watchedPath_)
        return;

    // Remove old watches
    if (!watchedPath_.isEmpty()) {
        watcher_.removePath(watchedPath_);
    }

    watchedPath_ = path;
    emit watchedPathChanged();

    if (!path.isEmpty()) {
        watcher_.addPath(path);
    }
}

void FileSystemWatcher::onDirectoryChanged(const QString &path)
{
    pendingDirs_.insert(path);
    debounceTimer_.start();
}

void FileSystemWatcher::onFileChanged(const QString &path)
{
    pendingFiles_.insert(path);
    debounceTimer_.start();
}

void FileSystemWatcher::onDebounceTimeout()
{
    for (const QString &dir : pendingDirs_)
        emit directoryChanged(dir);
    for (const QString &file : pendingFiles_)
        emit fileChanged(file);
    pendingDirs_.clear();
    pendingFiles_.clear();
}
