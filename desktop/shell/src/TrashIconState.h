#pragma once

#include <QObject>
#include <QString>
#include <QFileSystemWatcher>

/// Tracks the FreeDesktop.org Trash state so the desktop Trash icon can
/// reflect "empty" vs "full".  Watches $XDG_DATA_HOME/Trash/files (and the
/// legacy ~/.Trash) with QFileSystemWatcher so adding/removing a trashed
/// item updates the icon immediately.
class TrashIconState : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isEmpty READ isEmpty NOTIFY isEmptyChanged)
    Q_PROPERTY(QString trashPath READ trashPath CONSTANT)
    Q_PROPERTY(int itemCount READ itemCount NOTIFY itemCountChanged)

public:
    explicit TrashIconState(QObject *parent = nullptr);

    bool isEmpty() const { return itemCount_ == 0; }
    QString trashPath() const { return trashPath_; }
    int itemCount() const { return itemCount_; }

    /// Open the Trash in the file manager.
    Q_INVOKABLE void openTrash() const;
    /// Empty the Trash permanently (rm -rf on the files dir, removes the
    /// matching .trashinfo entries).  Returns true on success.
    Q_INVOKABLE bool emptyTrash();

signals:
    void isEmptyChanged();
    void itemCountChanged();

private slots:
    void onTrashChanged(const QString &path);

private:
    void rescan();

    QString trashPath_;
    QString infoPath_;
    QFileSystemWatcher *watcher_ = nullptr;
    int itemCount_ = 0;
    bool reloading_ = false;
};
