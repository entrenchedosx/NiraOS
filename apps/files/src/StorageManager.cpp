#include "StorageManager.h"

#include <QStorageInfo>
#include <QDebug>
#include <QFileInfo>

using namespace Qt::StringLiterals;

StorageManager::StorageManager(QObject *parent)
    : QObject(parent)
{
    scanDrives();

    pollTimer_.setInterval(5000);
    pollTimer_.setSingleShot(false);
    connect(&pollTimer_, &QTimer::timeout, this, &StorageManager::pollDrives);
    pollTimer_.start();
}

QVariantList StorageManager::drives() const
{
    QVariantList list;
    for (const auto &d : drives_) {
        QVariantMap m;
        m["name"_L1]         = d.name;
        m["path"_L1]         = d.path;
        m["mountPoint"_L1]   = d.mountPoint;
        m["fileSystemType"_L1] = d.fileSystemType;
        m["totalBytes"_L1]   = d.totalBytes;
        m["usedBytes"_L1]    = d.usedBytes;
        m["freeBytes"_L1]    = d.freeBytes;
        m["isReadOnly"_L1]   = d.isReadOnly;
        m["isRemovable"_L1]  = d.isRemovable;
        m["isReady"_L1]      = d.isReady;
        m["usedPercent"_L1]  = d.totalBytes > 0 ? (double)d.usedBytes / d.totalBytes * 100.0 : 0.0;
        list.append(m);
    }
    return list;
}

QVariantMap StorageManager::driveInfo(const QString &path) const
{
    for (const auto &d : drives_) {
        if (d.mountPoint == path || d.path == path) {
            QVariantMap m;
            m["name"_L1]         = d.name;
            m["path"_L1]         = d.path;
            m["mountPoint"_L1]   = d.mountPoint;
            m["totalBytes"_L1]   = d.totalBytes;
            m["usedBytes"_L1]    = d.usedBytes;
            m["freeBytes"_L1]    = d.freeBytes;
            m["isRemovable"_L1]  = d.isRemovable;
            return m;
        }
    }
    // Fallback: get info directly
    QStorageInfo si(path);
    if (si.isValid()) {
        QVariantMap m;
        m["name"_L1]         = si.name();
        m["path"_L1]         = si.device().isNull() ? path : si.device();
        m["mountPoint"_L1]   = si.rootPath();
        m["totalBytes"_L1]   = si.bytesTotal();
        m["usedBytes"_L1]    = si.bytesTotal() - si.bytesAvailable();
        m["freeBytes"_L1]    = si.bytesAvailable();
        m["isRemovable"_L1]  = false;
        return m;
    }
    return {};
}

QVariantList StorageManager::mountedDrives() const
{
    return drives();
}

void StorageManager::refresh()
{
    scanDrives();
    emit drivesChanged();
}

void StorageManager::pollDrives()
{
    // Detect new/removed drives
    QStringList currentPaths;
    const auto mounts = QStorageInfo::mountedVolumes();
    for (const auto &si : mounts) {
        if (si.isValid() && si.isReady())
            currentPaths.append(si.rootPath());
    }

    // Check for removed drives
    for (const auto &oldPath : knownPaths_) {
        if (!currentPaths.contains(oldPath)) {
            emit driveRemoved(oldPath);
        }
    }

    // Check for new drives
    for (const auto &newPath : currentPaths) {
        if (!knownPaths_.contains(newPath)) {
            emit driveAdded(newPath);
        }
    }

    knownPaths_ = currentPaths;
    scanDrives();
    emit drivesChanged();
}

void StorageManager::scanDrives()
{
    drives_.clear();
    const auto mounts = QStorageInfo::mountedVolumes();
    for (const QStorageInfo &si : mounts) {
        if (!si.isValid())
            continue;

        DriveInfo d;
        d.name           = si.name().isEmpty() ? si.rootPath() : si.name();
        d.path           = si.device().isNull() ? si.rootPath() : si.device();
        d.mountPoint     = si.rootPath();
        d.fileSystemType = si.fileSystemType();
        d.totalBytes     = si.bytesTotal();
        d.usedBytes      = si.bytesTotal() - si.bytesAvailable();
        d.freeBytes      = si.bytesAvailable();
        d.isReadOnly     = si.isReadOnly();
        d.isReady        = si.isReady();

        // Detect removable drives
        QFileInfo fi(d.path);
        // On Linux, removable drives typically have paths like /dev/sd*
        if (d.path.contains("/dev/sd"_L1) || d.path.contains("/dev/nvme"_L1))
            d.isRemovable = true;
        // USB drives
        if (d.path.contains("usb"_L1, Qt::CaseInsensitive))
            d.isRemovable = true;

        drives_.append(d);
    }
}
