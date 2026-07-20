#include "FileOperations.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QProcess>
#include <QDateTime>
#include <QStorageInfo>
#include <QStandardPaths>
#include <QDebug>
#include <QtConcurrent>
#include <QMetaObject>

using namespace Qt::StringLiterals;

FileOperations::FileOperations(QObject *parent)
    : QObject(parent)
{
}

// ── Helpers ────────────────────────────────────────────────────────────

// Resolve a copy/move destination the way a user expects: if `dest` is an
// existing directory, the operation targets `dest/<source-filename>`. The
// previous logic compared isDir() of source and dest, which incorrectly sent
// a file-into-directory copy to a bare directory path (QFile::copy then
// failed), so "copy file into a folder" was broken.
static QString resolveDestination(const QString &source, const QString &dest)
{
    const QFileInfo dst(dest);
    if (dst.isDir())
        return QDir(dest).absoluteFilePath(QFileInfo(source).fileName());
    return dest;
}

// FreeDesktop.org Trash: prefer `gio trash` (writes the .trashinfo file so a
// trash UI can restore), and fall back to a direct move into
// $XDG_DATA_HOME/Trash/files so a missing gio does not leave the user with
// only permanent deletion.
bool FileOperations::moveToTrash(const QString &path)
{
    // Try gio first (writes the .trashinfo file so a trash UI can restore).
    QProcess gio;
    gio.start(u"gio"_s, {u"trash"_s, path});
    if (gio.waitForStarted(2000)) {
        if (gio.waitForFinished(10000) && gio.exitCode() == 0)
            return true;
        // Timed out or non-zero exit: stop the process before falling back so
        // we do not leave a gio instance racing the manual move.
        gio.kill();
        gio.waitForFinished(2000);
    }

    // Fallback: move into the XDG trash directory with a unique name.
    const QString trashDir = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
                             + u"/Trash/files"_s;
    QDir().mkpath(trashDir);
    const QFileInfo fi(path);
    QString base = fi.completeBaseName();
    QString ext = fi.suffix();
    QString target;
    for (int i = 0; i < 10000; ++i) {
        const QString candidate = i == 0
            ? fi.fileName()
            : u"%1 (%2)%3"_s.arg(base).arg(i).arg(ext.isEmpty() ? u""_s : u'.' + ext);
        target = trashDir + u'/' + candidate;
        if (!QFileInfo::exists(target))
            break;
    }
    // QFile::rename works across the same filesystem; trash is usually on the
    // home filesystem. If rename fails, fall back to a copy + delete.
    if (QFile::rename(path, target))
        return true;
    const QFileInfo srcInfo(path);
    bool ok = srcInfo.isDir() ? performRecursiveCopy(path, target) : QFile::copy(path, target);
    if (ok)
        ok = performRecursiveDelete(path);
    return ok;
}

// Reject names that would escape the parent directory (path traversal). A
// rename to "../../etc/passwd" must not move the file out of its folder.
static bool isSafeName(const QString &name)
{
    if (name.isEmpty() || name == u"."_s || name == u".."_s)
        return false;
    if (name.contains(u'/') || name.contains(u'\\'))
        return false;
    return true;
}

// ── Public operations ──────────────────────────────────────────────────

void FileOperations::copy(const QString &source, const QString &dest)
{
    // Run off the UI thread so a multi-gigabyte copy does not freeze the shell.
    auto future = QtConcurrent::run([this, source, dest]() {
        const QFileInfo srcInfo(source);
        bool success = false;
        QString error;
        if (!srcInfo.exists()) {
            error = QStringLiteral("Source does not exist: ") + source;
        } else {
            const QString target = resolveDestination(source, dest);
            success = srcInfo.isDir() ? performRecursiveCopy(source, target)
                                      : performCopy(source, target);
            if (!success)
                error = QStringLiteral("Failed to copy ") + srcInfo.fileName();
        }
        QMetaObject::invokeMethod(this, [this, success, error]() {
            emit copyFinished(success, error);
        }, Qt::QueuedConnection);
    });
    Q_UNUSED(future);
}

void FileOperations::move(const QString &source, const QString &dest)
{
    auto future = QtConcurrent::run([this, source, dest]() {
        const QString target = resolveDestination(source, dest);
        bool success = performMove(source, target);
        QString error;
        if (!success)
            error = QStringLiteral("Failed to move ") + QFileInfo(source).fileName();
        QMetaObject::invokeMethod(this, [this, success, error]() {
            emit moveFinished(success, error);
        }, Qt::QueuedConnection);
    });
    Q_UNUSED(future);
}

void FileOperations::rename(const QString &path, const QString &newName)
{
    if (!isSafeName(newName)) {
        emit renameFinished(false, QStringLiteral("Invalid name: ") + newName);
        return;
    }
    QFileInfo fi(path);
    QString destPath = fi.dir().absoluteFilePath(newName);
    if (QFileInfo::exists(destPath) && destPath != fi.absoluteFilePath()) {
        emit renameFinished(false, QStringLiteral("A file named ") + newName + QStringLiteral(" already exists."));
        return;
    }
    bool success = QFile::rename(path, destPath);
    QString error;
    if (!success)
        error = QStringLiteral("Failed to rename to ") + newName;
    emit renameFinished(success, error);
}

void FileOperations::delete_(const QString &path, bool permanent)
{
    auto future = QtConcurrent::run([this, path, permanent]() {
        bool success = performDelete(path, permanent);
        QString error;
        if (!success)
            error = QStringLiteral("Failed to delete ") + QFileInfo(path).fileName();
        QMetaObject::invokeMethod(this, [this, success, error]() {
            emit deleteFinished(success, error);
        }, Qt::QueuedConnection);
    });
    Q_UNUSED(future);
}

void FileOperations::createFolder(const QString &parentDir, const QString &name)
{
    if (!isSafeName(name)) {
        emit createFolderFinished(false, QStringLiteral("Invalid folder name: ") + name);
        return;
    }
    QString fullPath = QDir(parentDir).absoluteFilePath(name);
    bool success = QDir().mkpath(fullPath);
    QString error;
    if (!success)
        error = QStringLiteral("Failed to create folder ") + name;
    emit createFolderFinished(success, error);
}

void FileOperations::createFile(const QString &parentDir, const QString &name)
{
    if (!isSafeName(name)) {
        emit createFileFinished(false, QStringLiteral("Invalid file name: ") + name);
        return;
    }
    QString fullPath = QDir(parentDir).absoluteFilePath(name);
    QFile file(fullPath);
    bool success = file.open(QIODevice::WriteOnly);
    QString error;
    if (success) {
        file.close();
    } else {
        error = QStringLiteral("Failed to create file ") + name + u": "_s + file.errorString();
    }
    emit createFileFinished(success, error);
}

void FileOperations::duplicate(const QString &path)
{
    auto future = QtConcurrent::run([this, path]() {
        QFileInfo fi(path);
        QString baseName = fi.completeBaseName();
        QString ext = fi.suffix();
        QString dirPath = fi.dir().absolutePath();

        QString newPath;
        for (int i = 1; i < 1000; ++i) {
            QString copyName = i == 1
                ? QStringLiteral("%1 (copy)%2").arg(baseName, ext.isEmpty() ? u""_s : u'.' + ext)
                : QStringLiteral("%1 (copy %2)%3").arg(baseName).arg(i).arg(ext.isEmpty() ? u""_s : u'.' + ext);
            newPath = dirPath + u'/' + copyName;
            if (!QFileInfo::exists(newPath))
                break;
        }

        bool success = fi.isDir() ? performRecursiveCopy(path, newPath)
                                  : QFile::copy(path, newPath);
        QString error;
        if (!success)
            error = QStringLiteral("Failed to duplicate ") + fi.fileName();
        QMetaObject::invokeMethod(this, [this, success, error]() {
            emit duplicateFinished(success, error);
        }, Qt::QueuedConnection);
    });
    Q_UNUSED(future);
}

QVariantMap FileOperations::getFileInfo(const QString &path)
{
    QVariantMap info;
    QFileInfo fi(path);
    if (!fi.exists())
        return info;

    info["name"_L1]           = fi.fileName();
    info["path"_L1]           = fi.absoluteFilePath();
    info["size"_L1]           = fi.size();
    info["sizeHuman"_L1]      = humanSize(fi.size());
    info["isDir"_L1]          = fi.isDir();
    info["isFile"_L1]         = fi.isFile();
    info["isSymlink"_L1]      = fi.isSymLink();
    info["isHidden"_L1]       = fi.isHidden();
    info["isReadable"_L1]     = fi.isReadable();
    info["isWritable"_L1]     = fi.isWritable();
    info["isExecutable"_L1]   = fi.isExecutable();
    info["lastModified"_L1]   = fi.lastModified();
    info["lastAccessed"_L1]   = fi.lastRead();
    info["created"_L1]        = fi.birthTime();
    info["owner"_L1]          = fi.owner();
    info["group"_L1]          = fi.group();

    QStorageInfo storage(fi.absolutePath());
    info["filesystem"_L1]     = storage.fileSystemType();
    info["fsTotal"_L1]        = storage.bytesTotal();
    info["fsUsed"_L1]         = storage.bytesTotal() - storage.bytesAvailable();
    info["fsFree"_L1]         = storage.bytesAvailable();

    return info;
}

void FileOperations::openFile(const QString &path)
{
    QFileInfo fi(path);
    if (!fi.exists()) {
        emit operationProgress(QStringLiteral("File does not exist: ") + path);
        return;
    }

    QString cmd;
#ifdef Q_OS_LINUX
    cmd = QStringLiteral("xdg-open");
#elif defined(Q_OS_WIN)
    cmd = QStringLiteral("explorer");
#else
    cmd = QStringLiteral("open");
#endif

    if (!QProcess::startDetached(cmd, {path}))
        emit operationProgress(QStringLiteral("Could not open ") + path);
}

void FileOperations::openInTerminal(const QString &path)
{
    QString dir = QFileInfo(path).isDir() ? path : QFileInfo(path).absolutePath();
#ifdef Q_OS_LINUX
    if (!QProcess::startDetached(QStringLiteral("qterminal"), {QStringLiteral("--workdir"), dir}))
        emit operationProgress(QStringLiteral("Could not open terminal at ") + dir);
#else
    if (!QProcess::startDetached(QStringLiteral("qterminal"), {dir}))
        emit operationProgress(QStringLiteral("Could not open terminal at ") + dir);
#endif
}

void FileOperations::showProperties(const QString &path)
{
    // This is handled in QML via the PropertiesDialog
    Q_UNUSED(path)
}

bool FileOperations::performCopy(const QString &source, const QString &dest)
{
    return QFile::copy(source, dest);
}

bool FileOperations::performMove(const QString &source, const QString &dest)
{
    // Try rename first (fast if same filesystem)
    if (QFile::rename(source, dest))
        return true;

    // Fall back to copy + delete
    QFileInfo fi(source);
    bool ok = false;
    if (fi.isDir())
        ok = performRecursiveCopy(source, dest);
    else
        ok = QFile::copy(source, dest);
    if (ok)
        ok = performDelete(source, false);
    return ok;
}

bool FileOperations::performDelete(const QString &path, bool permanent)
{
    QFileInfo fi(path);
    if (!fi.exists())
        return true;

    // Route to the Trash unless the caller explicitly requested a permanent
    // delete. The previous implementation ignored `permanent` and always
    // removed the file, so Delete was always destructive and the Trash
    // requirement was unmet.
    if (!permanent)
        return moveToTrash(path);

    if (fi.isDir())
        return performRecursiveDelete(path);
    else
        return QFile::remove(path);
}

bool FileOperations::performRecursiveCopy(const QString &sourceDir, const QString &destDir)
{
    QDir srcDir(sourceDir);
    if (!srcDir.exists())
        return false;

    QDir dstDir(destDir);
    if (!dstDir.exists()) {
        if (!dstDir.mkpath(destDir))
            return false;
    }

    const auto entries = srcDir.entryInfoList(QDir::AllEntries | QDir::NoDotAndDotDot);
    for (const QFileInfo &entry : entries) {
        QString srcPath = entry.absoluteFilePath();
        QString dstPath = dstDir.absoluteFilePath(entry.fileName());
        if (entry.isDir()) {
            if (!performRecursiveCopy(srcPath, dstPath))
                return false;
        } else {
            if (!QFile::copy(srcPath, dstPath))
                return false;
        }
    }

    return true;
}

bool FileOperations::performRecursiveDelete(const QString &path)
{
    QDir dir(path);
    if (!dir.exists())
        return true;

    const auto entries = dir.entryInfoList(QDir::AllEntries | QDir::NoDotAndDotDot);
    for (const QFileInfo &entry : entries) {
        if (entry.isDir()) {
            if (!performRecursiveDelete(entry.absoluteFilePath()))
                return false;
        } else {
            if (!QFile::remove(entry.absoluteFilePath()))
                return false;
        }
    }

    return dir.rmdir(path);
}

QString FileOperations::humanSize(qint64 bytes)
{
    if (bytes < 1024)
        return QString::number(bytes) + " B"_L1;
    double kb = bytes / 1024.0;
    if (kb < 1024)
        return QString::number(kb, 'f', 1) + " KB"_L1;
    double mb = kb / 1024.0;
    if (mb < 1024)
        return QString::number(mb, 'f', 1) + " MB"_L1;
    double gb = mb / 1024.0;
    if (gb < 1024)
        return QString::number(gb, 'f', 2) + " GB"_L1;
    double tb = gb / 1024.0;
    return QString::number(tb, 'f', 2) + " TB"_L1;
}
