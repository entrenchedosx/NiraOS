#pragma once

#include <QObject>
#include <QFileSystemWatcher>
#include <QString>
#include <QTimer>
#include <QHash>
#include <QSet>

class FileSystemWatcher : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString watchedPath READ watchedPath WRITE setWatchedPath NOTIFY watchedPathChanged)

public:
    explicit FileSystemWatcher(QObject *parent = nullptr);

    QString watchedPath() const;
    void setWatchedPath(const QString &path);

signals:
    void directoryChanged(const QString &path);
    void fileChanged(const QString &path);
    void watchedPathChanged();

private slots:
    void onDirectoryChanged(const QString &path);
    void onFileChanged(const QString &path);
    void onDebounceTimeout();

private:
    QFileSystemWatcher watcher_;
    QString watchedPath_;
    QTimer debounceTimer_;
    QSet<QString> pendingDirs_;
    QSet<QString> pendingFiles_;
};
