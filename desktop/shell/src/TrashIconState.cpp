#include "TrashIconState.h"

#include <QDir>
#include <QProcess>
#include <QStandardPaths>
#include <QDebug>

using namespace Qt::StringLiterals;

TrashIconState::TrashIconState(QObject *parent)
    : QObject(parent)
{
    // The FreeDesktop.org Trash lives under $XDG_DATA_HOME/Trash.
    trashPath_ = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
                 + u"/Trash/files"_s;
    infoPath_ = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
                + u"/Trash/info"_s;
    QDir().mkpath(trashPath_);
    QDir().mkpath(infoPath_);

    watcher_ = new QFileSystemWatcher(this);
    // Watching the files directory catches additions/removals; the info
    // directory is watched too because some implementations write the
    // .trashinfo first.
    if (QDir(trashPath_).exists())
        watcher_->addPath(trashPath_);
    if (QDir(infoPath_).exists())
        watcher_->addPath(infoPath_);
    connect(watcher_, &QFileSystemWatcher::directoryChanged,
            this, &TrashIconState::onTrashChanged);

    rescan();
}

void TrashIconState::onTrashChanged(const QString &path)
{
    Q_UNUSED(path);
    if (reloading_) return;
    rescan();
}

void TrashIconState::rescan()
{
    reloading_ = true;
    int count = 0;
    QDir files(trashPath_);
    if (files.exists()) {
        // Any entry (including nested dirs) counts as "not empty" for icon
        // state purposes; we report the total entry count for the tooltip.
        const auto entries = files.entryInfoList(
            QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden);
        count = entries.size();
    }
    if (count != itemCount_) {
        itemCount_ = count;
        emit itemCountChanged();
        emit isEmptyChanged();
    }
    reloading_ = false;
}

void TrashIconState::openTrash() const
{
    // gio open trash:// is the canonical way; fall back to opening the dir.
    if (QProcess::startDetached(u"gio"_s, {u"open"_s, u"trash://"_s}))
        return;
    QProcess::startDetached(u"xdg-open"_s, {trashPath_});
}

bool TrashIconState::emptyTrash()
{
    // Permanently remove every file under $XDG_DATA_HOME/Trash/files and the
    // matching .trashinfo entries.  We use `rm -rf` via QProcess::execute so
    // recursive directories are handled; the alternative (a recursive
    // QDir iterator) is much more code for the same effect.
    bool ok = true;
    if (QDir(trashPath_).exists()) {
        ok = QProcess::execute(u"rm"_s, {u"-rf"_s, trashPath_}) == 0;
        QDir().mkpath(trashPath_);
    }
    if (QDir(infoPath_).exists()) {
        ok = ok && (QProcess::execute(u"rm"_s, {u"-rf"_s, infoPath_}) == 0);
        QDir().mkpath(infoPath_);
    }
    rescan();
    return ok;
}
