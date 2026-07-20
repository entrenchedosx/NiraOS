#include "WallpaperModel.h"

#include <QDir>
#include <QFileInfo>
#include <QSettings>
#include <QUrl>
#include <QDebug>

using namespace Qt::StringLiterals;

static const QStringList kImageSuffixes = { u"jpg"_s, u"jpeg"_s, u"png"_s, u"webp"_s, u"bmp"_s };

WallpaperModel::WallpaperModel(QObject *parent)
    : QAbstractListModel(parent)
{
    watcher_ = new QFileSystemWatcher(this);
    connect(watcher_, &QFileSystemWatcher::directoryChanged,
            this, &WallpaperModel::onDirectoryChanged);

    // Watch both system and user wallpaper dirs so adding a wallpaper
    // through Settings or the file manager appears immediately.
    const QStringList dirs = {
        u"/usr/share/niraos/wallpapers"_s,
        QDir::homePath() + u"/.local/share/niraos/wallpapers"_s,
    };
    for (const auto &d : dirs) {
        if (QDir(d).exists())
            watcher_->addPath(d);
        else
            QDir().mkpath(d);
    }

    scanAll();
    loadCurrent();
    // Fall back to the system default so a fresh install renders a real
    // wallpaper rather than an empty desktop.
    if (current_.isEmpty()) {
        const QString def = u"file:///usr/share/niraos/wallpaper-default.jpg"_s;
        setCurrentWallpaper(QUrl(def));
    }
}

int WallpaperModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : entries_.size();
}

QVariant WallpaperModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= entries_.size())
        return {};
    const auto &e = entries_.at(index.row());
    switch (role) {
    case NameRole:   return e.name;
    case PathRole:   return QUrl(u"file://"_s + e.path);
    case IsUserRole: return e.isUser;
    default:         return {};
    }
}

QHash<int, QByteArray> WallpaperModel::roleNames() const
{
    return {
        { NameRole,   "name" },
        { PathRole,   "path" },
        { IsUserRole, "isUser" },
    };
}

void WallpaperModel::setCurrentWallpaper(const QUrl &u)
{
    if (u == current_) return;
    current_ = u;
    emit currentWallpaperChanged();
}

void WallpaperModel::saveCurrent()
{
    QSettings s;
    s.setValue(u"Shell/wallpaper"_s, current_.toString());
}

void WallpaperModel::loadCurrent()
{
    QSettings s;
    const QString saved = s.value(u"Shell/wallpaper"_s).toString();
    if (!saved.isEmpty())
        setCurrentWallpaper(QUrl(saved));
}

void WallpaperModel::onDirectoryChanged(const QString &path)
{
    Q_UNUSED(path);
    if (reloading_) return;
    scanAll();
}

void WallpaperModel::scanAll()
{
    reloading_ = true;
    QList<WallEntry> next;
    const auto addDir = [&next](const QString &dirPath, bool isUser) {
        QDir dir(dirPath);
        if (!dir.exists()) return;
        const auto files = dir.entryInfoList(QDir::Files | QDir::Readable);
        for (const QFileInfo &fi : files) {
            if (!kImageSuffixes.contains(fi.suffix().toLower()))
                continue;
            WallEntry e;
            e.name = fi.completeBaseName();
            e.path = fi.absoluteFilePath();
            e.isUser = isUser;
            next.append(std::move(e));
        }
    };
    addDir(u"/usr/share/niraos/wallpapers"_s, false);
    addDir(QDir::homePath() + u"/.local/share/niraos/wallpapers"_s, true);

    beginResetModel();
    entries_ = std::move(next);
    endResetModel();
    emit countChanged();
    reloading_ = false;
}
