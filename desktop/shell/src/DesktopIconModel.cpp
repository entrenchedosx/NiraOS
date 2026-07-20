#include "DesktopIconModel.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QMimeDatabase>
#include <QProcess>
#include <QProcessEnvironment>
#include <QStandardPaths>
#include <QTextStream>
#include <QUrl>
#include <QRegularExpression>
#include <QDebug>

using namespace Qt::StringLiterals;

// ── Construction & directory setup ──────────────────────────────────────

DesktopIconModel::DesktopIconModel(QObject *parent)
    : QAbstractListModel(parent)
{
    // XDG DesktopLocation honors XDG_DESKTOP_DIR (~/.config/user-dirs.dirs);
    // fall back to ~/Desktop.
    QString desktop = QStandardPaths::writableLocation(QStandardPaths::DesktopLocation);
    if (desktop.isEmpty())
        desktop = QDir::homePath() + u"/Desktop"_s;
    desktopPath_ = QDir(desktop).absolutePath();

    // Ensure the directory exists; first boot of a fresh account may not have
    // created it yet, and a missing Desktop would otherwise render an empty
    // desktop forever.
    QDir().mkpath(desktopPath_);

    watcher_ = new QFileSystemWatcher(this);
    connect(watcher_, &QFileSystemWatcher::directoryChanged,
            this, &DesktopIconModel::onDirectoryChanged);
    connect(watcher_, &QFileSystemWatcher::fileChanged,
            this, &DesktopIconModel::onFileChanged);

    scanDirectory();
    qInfo() << "DesktopIconModel: watching" << desktopPath_
            << "with" << entries_.size() << "entries";
}

// ── Model API ───────────────────────────────────────────────────────────

int DesktopIconModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : entries_.size();
}

QVariant DesktopIconModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= entries_.size())
        return {};
    const auto &e = entries_.at(index.row());
    switch (role) {
    case NameRole:           return e.name;
    case FilePathRole:       return e.filePath;
    case TargetPathRole:     return e.targetPath;
    case IconNameRole:       return e.iconName;
    case MimeTypeRole:       return e.mimeType;
    case ExecRole:           return e.exec;
    case IsDirectoryRole:    return e.isDirectory;
    case IsShortcutRole:     return e.isShortcut;
    case IsExecutableRole:   return e.isExecutable;
    case IsHiddenRole:       return e.isHidden;
    case FileSizeRole:       return e.fileSize;
    case LastModifiedRole:   return e.lastModified;
    case EntryRole: {
        QVariantMap m;
        m["name"_L1]         = e.name;
        m["filePath"_L1]     = e.filePath;
        m["targetPath"_L1]   = e.targetPath;
        m["iconName"_L1]     = e.iconName;
        m["mimeType"_L1]     = e.mimeType;
        m["exec"_L1]         = e.exec;
        m["isDirectory"_L1]  = e.isDirectory;
        m["isShortcut"_L1]   = e.isShortcut;
        m["isExecutable"_L1] = e.isExecutable;
        m["isHidden"_L1]     = e.isHidden;
        m["fileSize"_L1]     = e.fileSize;
        m["lastModified"_L1] = e.lastModified;
        return m;
    }
    default: return {};
    }
}

QHash<int, QByteArray> DesktopIconModel::roleNames() const
{
    return {
        { NameRole,           "name" },
        { FilePathRole,       "filePath" },
        { TargetPathRole,     "targetPath" },
        { IconNameRole,       "iconName" },
        { MimeTypeRole,       "mimeType" },
        { ExecRole,           "exec" },
        { IsDirectoryRole,    "isDirectory" },
        { IsShortcutRole,     "isShortcut" },
        { IsExecutableRole,   "isExecutable" },
        { IsHiddenRole,       "isHidden" },
        { FileSizeRole,       "fileSize" },
        { LastModifiedRole,   "lastModified" },
        { EntryRole,          "entry" },
    };
}

void DesktopIconModel::setShowHidden(bool show)
{
    if (show == showHidden_) return;
    showHidden_ = show;
    emit showHiddenChanged();
    scanDirectory();
}

// ── Live updates ────────────────────────────────────────────────────────

void DesktopIconModel::onDirectoryChanged(const QString &path)
{
    Q_UNUSED(path);
    // QFileSystemWatcher drops file watches when a file is replaced atomically
    // (the common case for "save" dialogs that write to a temp file and rename).
    // Re-scan, which re-adds watches for any new files.
    if (reloading_) return;
    scanDirectory();
}

void DesktopIconModel::onFileChanged(const QString &path)
{
    // A .desktop file's contents changed -> reparse.  For plain files a
    // metadata change (size, mtime) is enough to trigger a rescan so the
    // label/size shown in the icon tooltip stays current.
    Q_UNUSED(path);
    if (reloading_) return;
    scanDirectory();
}

void DesktopIconModel::refresh()
{
    scanDirectory();
}

QVariantMap DesktopIconModel::get(int row) const
{
    QVariantMap m;
    if (row < 0 || row >= entries_.size()) return m;
    const auto &e = entries_.at(row);
    m["name"_L1]         = e.name;
    m["filePath"_L1]     = e.filePath;
    m["targetPath"_L1]   = e.targetPath;
    m["iconName"_L1]     = e.iconName;
    m["mimeType"_L1]     = e.mimeType;
    m["exec"_L1]         = e.exec;
    m["isDirectory"_L1]  = e.isDirectory;
    m["isShortcut"_L1]   = e.isShortcut;
    m["isExecutable"_L1] = e.isExecutable;
    m["isHidden"_L1]     = e.isHidden;
    m["fileSize"_L1]     = e.fileSize;
    m["lastModified"_L1] = e.lastModified;
    return m;
}

// ── Scanning ────────────────────────────────────────────────────────────

void DesktopIconModel::scanDirectory()
{
    QDir dir(desktopPath_);
    if (!dir.exists()) {
        if (!entries_.isEmpty()) {
            beginResetModel();
            entries_.clear();
            endResetModel();
            emit iconCountChanged();
        }
        return;
    }

    reloading_ = true;
    // Keep watching the directory itself; refresh file watches on each scan.
    if (!watcher_->directories().contains(desktopPath_))
        watcher_->addPath(desktopPath_);

    // Remove stale per-file watches for files that no longer exist, add new.
    const QStringList watchedFiles = watcher_->files();
    for (const QString &f : watchedFiles) {
        if (!QFileInfo::exists(f))
            watcher_->removePath(f);
    }

    const auto infoList = dir.entryInfoList(
        QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden,
        QDir::DirsFirst | QDir::Name);

    QList<DesktopEntry> next;
    next.reserve(infoList.size());
    for (const QFileInfo &fi : infoList) {
        if (!showHidden_ && fi.isHidden())
            continue;
        DesktopEntry e = entryFromInfo(fi);
        // Track each real file so a content edit (e.g. saving a text file
        // already on the Desktop) triggers a refresh.
        if (fi.isFile())
            watcher_->addPath(fi.absoluteFilePath());
        next.append(std::move(e));
    }

    beginResetModel();
    entries_ = std::move(next);
    endResetModel();
    emit iconCountChanged();
    reloading_ = false;
}

DesktopEntry DesktopIconModel::entryFromInfo(const QFileInfo &info)
{
    DesktopEntry e;
    e.filePath = info.absoluteFilePath();
    e.name = info.fileName();
    e.fileSize = info.size();
    e.lastModified = info.lastModified();
    e.isHidden = info.isHidden();
    e.isDirectory = info.isDir();
    e.isExecutable = info.isExecutable();

    static const QMimeDatabase mimeDb;
    e.mimeType = mimeDb.mimeTypeForFile(info).name();

    // .desktop files are shortcuts — parse Name/Icon/Exec/URL/Path.
    if (info.suffix().compare(u"desktop"_s, Qt::CaseInsensitive) == 0) {
        e.isShortcut = true;
        parseDesktopFile(e);
    } else if (info.isDir()) {
        e.iconName = u"folder"_s;
    } else if (info.isExecutable()) {
        e.iconName = u"application-x-executable"_s;
    } else {
        e.iconName = mimeDb.mimeTypeForFile(info).iconName();
    }
    return e;
}

void DesktopIconModel::parseDesktopFile(DesktopEntry &entry)
{
    QFile f(entry.filePath);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        entry.iconName = u"text-x-generic"_s;
        return;
    }
    QTextStream in(&f);
    in.setEncoding(QStringConverter::Utf8);

    bool inDesktopEntry = false;
    QString name, icon, exec, url, path, type;
    while (!in.atEnd()) {
        const QString line = in.readLine();
        if (line.startsWith(u'[')) {
            if (inDesktopEntry) break;        // left [Desktop Entry]
            if (line.startsWith(u"[Desktop Entry]"_s))
                inDesktopEntry = true;
            continue;
        }
        if (!inDesktopEntry) continue;
        if (line.trimmed().startsWith(u'#')) continue;
        const int eq = line.indexOf(u'=');
        if (eq < 0) continue;
        const QString key = line.left(eq).trimmed();
        const QString val = line.mid(eq + 1).trimmed();
        if (key == u"Name"_s)        name = val;
        else if (key == u"Icon"_s)   icon = val;
        else if (key == u"Exec"_s)   exec = val;
        else if (key == u"URL"_s)    url = val;
        else if (key == u"Path"_s)   path = val;
        else if (key == u"Type"_s)   type = val;
    }

    if (!name.isEmpty()) entry.name = name;
    entry.iconName = icon.isEmpty() ? u"application-x-desktop"_s : icon;
    entry.exec = exec;
    // Link-type shortcuts point at a URL; Application-type at an Exec.
    // For "open target location" we prefer Path=, then URL=, then the Exec
    // argv[0] resolved against $PATH.
    entry.targetPath = path;
    if (entry.targetPath.isEmpty() && !url.isEmpty()) {
        // file:// URIs are common for desktop shortcuts to local folders.
        const QUrl u(url);
        if (u.isLocalFile()) entry.targetPath = u.toLocalFile();
        else entry.targetPath = url;
    }
    if (entry.targetPath.isEmpty() && !exec.isEmpty()) {
        const QStringList parts = QProcess::splitCommand(exec);
        if (!parts.isEmpty())
            entry.targetPath = parts.first();
    }
    Q_UNUSED(type);
}

// ── QML-callable actions ────────────────────────────────────────────────

bool DesktopIconModel::launch(int row)
{
    if (row < 0 || row >= entries_.size()) return false;
    const auto &e = entries_.at(row);

    if (e.isShortcut && !e.exec.isEmpty()) {
        // Honor TryExec semantics implicitly: ProcessLauncher / xdg-open
        // will not start a missing binary.  Strip desktop-entry field codes.
        QString cleaned = e.exec;
        static const QRegularExpression re(uR"((?:%[uUfFdDnNvmick] ?)|(?:%%))"_s);
        cleaned.replace(re, QString()).trimmed();
        return QProcess::startDetached(u"sh"_s, {u"-c"_s, cleaned});
    }
    if (e.isDirectory) {
        // Open the folder in the file manager.
        return QProcess::startDetached(u"xdg-open"_s, {e.filePath});
    }
    // Regular file: let the OS pick the handler.
    return QProcess::startDetached(u"xdg-open"_s, {e.filePath});
}

bool DesktopIconModel::renameEntry(int row, const QString &newName)
{
    if (row < 0 || row >= entries_.size()) return false;
    if (newName.isEmpty()) return false;
    if (newName.contains(u'/') || newName.contains(u'\\')) return false;

    const auto &e = entries_.at(row);
    const QDir dir = QFileInfo(e.filePath).dir();
    const QString target = dir.absoluteFilePath(newName);
    if (QFileInfo::exists(target) && target != e.filePath) {
        qWarning() << "DesktopIconModel::renameEntry: target exists" << target;
        return false;
    }
    if (!QFile::rename(e.filePath, target)) {
        qWarning() << "DesktopIconModel::renameEntry: rename failed" << e.filePath << "->" << target;
        return false;
    }
    // The file watcher will fire and rescan; no manual reset needed.
    return true;
}

bool DesktopIconModel::trashEntry(int row)
{
    if (row < 0 || row >= entries_.size()) return false;
    const QString path = entries_.at(row).filePath;
    return moveToTrash(path);
}

void DesktopIconModel::openDesktopFolder() const
{
    QProcess::startDetached(u"xdg-open"_s, {desktopPath_});
}

QString DesktopIconModel::createFolder()
{
    const QString name = uniqueName(desktopPath_, u"New Folder"_s);
    const QString full = QDir(desktopPath_).absoluteFilePath(name);
    if (!QDir().mkpath(full)) {
        qWarning() << "DesktopIconModel::createFolder: mkpath failed" << full;
        return {};
    }
    return full;
}

QString DesktopIconModel::createFile()
{
    const QString name = uniqueName(desktopPath_, u"New File"_s, u".txt"_s);
    const QString full = QDir(desktopPath_).absoluteFilePath(name);
    QFile f(full);
    if (!f.open(QIODevice::WriteOnly)) {
        qWarning() << "DesktopIconModel::createFile: open failed" << full << f.errorString();
        return {};
    }
    f.close();
    return full;
}

bool DesktopIconModel::createShortcut(const QString &targetPath, const QString &displayName)
{
    if (targetPath.isEmpty()) return false;
    const QString safeName = displayName.isEmpty()
        ? QFileInfo(targetPath).fileName()
        : displayName;
    const QString base = safeName + u".desktop"_s;
    const QString file = QDir(desktopPath_).absoluteFilePath(uniqueName(desktopPath_, base, u""_s));
    QFile f(file);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qWarning() << "DesktopIconModel::createShortcut: open failed" << file;
        return false;
    }
    QTextStream out(&f);
    out.setEncoding(QStringConverter::Utf8);
    out << u"[Desktop Entry]"_s << u'\n'
        << u"Type=Link"_s << u'\n'
        << u"Name="_s << safeName << u'\n'
        << u"URL=file://"_s << targetPath << u'\n'
        << u"Icon=folder"_s << u'\n';
    out.flush();
    f.close();
    // Mark the new .desktop file executable so xdg-open treats it as a trusted
    // shortcut (freedesktop.org trust model).
    QFile::setPermissions(file, QFile::ReadOwner | QFile::WriteOwner | QFile::ReadGroup
                              | QFile::ReadOther | QFile::ExeOwner | QFile::ExeGroup
                              | QFile::ExeOther);
    return true;
}

// ── Helpers ─────────────────────────────────────────────────────────────

QString DesktopIconModel::uniqueName(const QString &dirPath, const QString &baseName,
                                     const QString &suffix)
{
    // Find a non-clashing name: "New Folder", "New Folder (2)", "New Folder (3)"...
    const QDir dir(dirPath);
    QString candidate = baseName + suffix;
    int i = 2;
    while (dir.exists(candidate)) {
        candidate = u"%1 (%2)%3"_s.arg(baseName).arg(i).arg(suffix);
        ++i;
        if (i > 10000) break;   // pathological guard
    }
    return candidate;
}

bool DesktopIconModel::moveToTrash(const QString &path)
{
    // Prefer gio trash (writes .trashinfo so a trash UI can restore).
    QProcess gio;
    gio.start(u"gio"_s, {u"trash"_s, path});
    if (gio.waitForStarted(2000)) {
        if (gio.waitForFinished(10000) && gio.exitCode() == 0)
            return true;
        gio.kill();
        gio.waitForFinished(2000);
    }
    // Fallback: move into the XDG trash directory with a unique name.
    const QString trashFiles = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
                               + u"/Trash/files"_s;
    QDir().mkpath(trashFiles);
    const QFileInfo fi(path);
    QString target;
    for (int i = 0; i < 10000; ++i) {
        const QString candidate = i == 0 ? fi.fileName()
            : u"%1 (%2)%3"_s.arg(fi.completeBaseName()).arg(i)
                 .arg(fi.suffix().isEmpty() ? u""_s : u'.' + fi.suffix());
        target = trashFiles + u'/' + candidate;
        if (!QFileInfo::exists(target)) break;
    }
    if (QFile::rename(path, target)) return true;
    // Last resort: copy + delete (works across filesystems).
    const bool isDir = QFileInfo(path).isDir();
    if (isDir) {
        // Recursive copy via shell `cp -r` to keep the implementation small.
        if (QProcess::execute(u"cp"_s, {u"-r"_s, path, target}) == 0
            && QProcess::execute(u"rm"_s, {u"-rf"_s, path}) == 0)
            return true;
    } else {
        if (QFile::copy(path, target) && QFile::remove(path))
            return true;
    }
    return false;
}
