#include "FileModel.h"

#include <QDir>
#include <QFileInfo>
#include <QMimeDatabase>
#include <QMutexLocker>
#include <QStorageInfo>
#include <QDebug>

using namespace Qt::StringLiterals;

FileModel::FileModel(QObject *parent)
    : QAbstractListModel(parent)
{
    watcher_ = new QFutureWatcher<QList<FileEntry>>(this);
    connect(watcher_, &QFutureWatcher<QList<FileEntry>>::finished,
            this, &FileModel::onDirectoryLoaded);
}

FileModel::~FileModel() = default;

int FileModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : entries_.size();
}

QVariant FileModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= entries_.size())
        return {};

    const auto &e = entries_.at(index.row());

    switch (role) {
    case FileNameRole:       return e.fileName;
    case FilePathRole:       return e.filePath;
    case FileSizeRole:       return e.fileSize;
    case FileTypeRole:       return e.fileType;
    case MimeTypeRole:       return e.mimeType;
    case LastModifiedRole:   return e.lastModified;
    case LastAccessedRole:   return e.lastAccessed;
    case CreatedRole:        return e.created;
    case PermissionsRole:    return static_cast<int>(e.permissions);
    case IsExecutableRole:   return e.isExecutable;
    case IsHiddenRole:       return e.isHidden;
    case IsReadableRole:     return e.isReadable;
    case IsWritableRole:     return e.isWritable;
    case IconNameRole:       return e.iconName;
    case ThumbnailRole:      return e.thumbnail;
    case OwnerRole:          return e.owner;
    case GroupRole:          return e.group;
    case FileEntryRole:      return QVariant::fromValue(entryToMap(e));
    case Qt::DisplayRole:    return e.fileName;
    case Qt::DecorationRole: return QIcon::fromTheme(e.iconName);
    default:                 return {};
    }
}

QHash<int, QByteArray> FileModel::roleNames() const
{
    return {
        { FileNameRole,       "fileName" },
        { FilePathRole,       "filePath" },
        { FileSizeRole,       "fileSize" },
        { FileTypeRole,       "fileType" },
        { MimeTypeRole,       "mimeType" },
        { LastModifiedRole,   "lastModified" },
        { LastAccessedRole,   "lastAccessed" },
        { CreatedRole,        "created" },
        { PermissionsRole,    "permissions" },
        { IsExecutableRole,   "isExecutable" },
        { IsHiddenRole,       "isHidden" },
        { IsReadableRole,     "isReadable" },
        { IsWritableRole,     "isWritable" },
        { IconNameRole,       "iconName" },
        { ThumbnailRole,      "thumbnail" },
        { OwnerRole,          "owner" },
        { GroupRole,          "group" },
    };
}

QString FileModel::currentPath() const { return currentPath_; }

void FileModel::setCurrentPath(const QString &path)
{
    if (path == currentPath_)
        return;
    currentPath_ = path;
    emit currentPathChanged();
    refresh();
}

int FileModel::sortColumn() const { return sortColumn_; }

void FileModel::setSortColumn(int column)
{
    if (column == sortColumn_)
        return;
    sortColumn_ = column;
    applySort();
    emit sortChanged();
}

Qt::SortOrder FileModel::sortOrder() const { return sortOrder_; }

void FileModel::setSortOrder(Qt::SortOrder order)
{
    if (order == sortOrder_)
        return;
    sortOrder_ = order;
    applySort();
    emit sortChanged();
}

QString FileModel::nameFilter() const { return nameFilter_; }

void FileModel::setNameFilter(const QString &filter)
{
    if (filter == nameFilter_)
        return;
    nameFilter_ = filter;
    emit filterChanged();
    refresh();
}

bool FileModel::loading() const { return loading_; }

bool FileModel::showHidden() const { return showHidden_; }

void FileModel::setShowHidden(bool show)
{
    if (show == showHidden_)
        return;
    showHidden_ = show;
    emit showHiddenChanged();
    refresh();
}

void FileModel::refresh()
{
    if (currentPath_.isEmpty())
        return;
    startDirectoryLoad(currentPath_);
}

void FileModel::navigateUp()
{
    QFileInfo fi(currentPath_);
    QDir dir = fi.isDir() ? QDir(currentPath_) : fi.dir();
    if (dir.exists()) {
        dir.cdUp();
        setCurrentPath(dir.absolutePath());
    }
}

void FileModel::navigateTo(const QString &path)
{
    QFileInfo fi(path);
    if (fi.exists() && fi.isDir())
        setCurrentPath(fi.absoluteFilePath());
}

QString FileModel::parentPath(const QString &path) const
{
    QFileInfo fi(path);
    if (fi.isRoot())
        return path;
    return fi.dir().absolutePath();
}

QVariantMap FileModel::fileInfoAt(int row) const
{
    if (row < 0 || row >= entries_.size())
        return {};
    return entryToMap(entries_.at(row));
}

void FileModel::onDirectoryLoaded()
{
    QList<FileEntry> result = watcher_->result();

    // Filter hidden files if needed.
    if (!showHidden_) {
        result.erase(
            std::remove_if(result.begin(), result.end(),
                           [](const FileEntry &e) { return e.isHidden; }),
            result.end());
    }

    // Apply the name filter (substring match, case-insensitive). The previous
    // implementation stored nameFilter_ and reloaded the directory on every
    // keystroke but never actually filtered on it, so search was a no-op.
    if (!nameFilter_.isEmpty()) {
        const QString needle = nameFilter_.toLower();
        result.erase(
            std::remove_if(result.begin(), result.end(),
                           [&needle](const FileEntry &e) {
                               return !e.fileName.toLower().contains(needle);
                           }),
            result.end());
    }

    {
        QMutexLocker lock(&mutex_);
        // Emit the model reset around the replacement + sort so views requery
        // instead of reading a half-mutated list. sortEntries() does NOT emit
        // reset signals itself (applySort() does, and is used for live
        // sort-column changes from QML).
        beginResetModel();
        entries_ = result;
        sortEntries();
        endResetModel();
    }

    if (loading_) {
        loading_ = false;
        emit loadingChanged();
    }
}

void FileModel::startDirectoryLoad(const QString &path)
{
    // Do NOT call watcher_->waitForFinished() here: that blocks the UI thread
    // until a possibly-slow background directory scan completes, freezing the
    // shell during rapid navigation. setFuture() swaps the watched future, and
    // because QFutureWatcher::finished is a queued signal delivered on this
    // (main) thread, no stale `finished` can fire between two synchronous
    // setFuture calls. The abandoned future simply completes in the background
    // and its result is discarded.
    if (!loading_) {
        loading_ = true;
        emit loadingChanged();
    }

    QFuture<QList<FileEntry>> future = QtConcurrent::run(loadDirectory, path);
    watcher_->setFuture(future);
}

QVariantMap FileModel::entryToMap(const FileEntry &e) const
{
    QVariantMap m;
    m["fileName"_L1]       = e.fileName;
    m["filePath"_L1]       = e.filePath;
    m["fileSize"_L1]       = e.fileSize;
    m["fileType"_L1]       = e.fileType;
    m["mimeType"_L1]       = e.mimeType;
    m["lastModified"_L1]   = e.lastModified;
    m["lastAccessed"_L1]   = e.lastAccessed;
    m["created"_L1]        = e.created;
    m["permissions"_L1]    = static_cast<int>(e.permissions);
    m["isExecutable"_L1]   = e.isExecutable;
    m["isHidden"_L1]       = e.isHidden;
    m["isReadable"_L1]     = e.isReadable;
    m["isWritable"_L1]     = e.isWritable;
    m["iconName"_L1]       = e.iconName;
    m["thumbnail"_L1]      = e.thumbnail;
    m["owner"_L1]          = e.owner;
    m["group"_L1]          = e.group;
    return m;
}

void FileModel::applySort()
{
    if (entries_.isEmpty())
        return;

    beginResetModel();
    sortEntries();
    endResetModel();
}

void FileModel::sortEntries()
{
    if (entries_.isEmpty())
        return;

    std::sort(entries_.begin(), entries_.end(),
              [this](const FileEntry &a, const FileEntry &b) {
                  // Directories always come first
                  if (a.fileType == "directory"_L1 && b.fileType != "directory"_L1)
                      return true;
                  if (a.fileType != "directory"_L1 && b.fileType == "directory"_L1)
                      return false;

                  int cmp = 0;
                  switch (sortColumn_) {
                  case SortByName:
                      cmp = QString::compare(a.fileName, b.fileName, Qt::CaseInsensitive);
                      break;
                  case SortBySize:
                      cmp = (a.fileSize < b.fileSize) ? -1 : (a.fileSize > b.fileSize) ? 1 : 0;
                      break;
                  case SortByType:
                      cmp = QString::compare(a.mimeType, b.mimeType, Qt::CaseInsensitive);
                      if (cmp == 0)
                          cmp = QString::compare(a.fileName, b.fileName, Qt::CaseInsensitive);
                      break;
                  case SortByDate:
                      if (a.lastModified < b.lastModified) cmp = -1;
                      else if (a.lastModified > b.lastModified) cmp = 1;
                      else cmp = 0;
                      break;
                  }

                  return sortOrder_ == Qt::AscendingOrder ? cmp < 0 : cmp > 0;
              });
}

QList<FileEntry> FileModel::loadDirectory(const QString &path)
{
    QList<FileEntry> entries;
    QDir dir(path);

    if (!dir.exists())
        return entries;

    QMimeDatabase mimeDb;
    const QFileInfoList infoList = dir.entryInfoList(
        QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System,
        QDir::DirsFirst | QDir::Name);

    for (const QFileInfo &fi : infoList) {
        FileEntry e;
        e.fileName       = fi.fileName();
        e.filePath       = fi.absoluteFilePath();
        e.fileSize       = fi.isDir() ? 0 : fi.size();
        e.lastModified   = fi.lastModified();
        e.lastAccessed   = fi.lastRead();
        e.created        = fi.birthTime();
        e.permissions    = fi.permissions();
        e.isExecutable   = fi.isExecutable();
        e.isHidden       = fi.isHidden();
        e.isReadable     = fi.isReadable();
        e.isWritable     = fi.isWritable();
        e.owner          = fi.owner();
        e.group          = fi.group();

        if (fi.isSymLink())
            e.fileType = "symlink"_L1;
        else if (fi.isDir())
            e.fileType = "directory"_L1;
        else if (fi.isFile())
            e.fileType = "file"_L1;
        else
            e.fileType = "other"_L1;

        e.mimeType = mimeDb.mimeTypeForFile(fi).name();

        // Choose icon
        if (fi.isDir())
            e.iconName = fi.isReadable() ? "folder"_L1 : "folder-locked"_L1;
        else if (fi.isSymLink())
            e.iconName = "emblem-symbolic-link"_L1;
        else
            e.iconName = mimeDb.mimeTypeForFile(fi).iconName();

        // Thumbnail for images
        if (e.mimeType.startsWith("image/"_L1))
            e.thumbnail = QStringLiteral("file:///") + e.filePath;

        entries.append(e);
    }

    return entries;
}
