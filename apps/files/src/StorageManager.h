#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <QList>
#include <QTimer>

struct DriveInfo {
    QString name;
    QString path;
    QString mountPoint;
    QString fileSystemType;
    qint64 totalBytes = 0;
    qint64 usedBytes = 0;
    qint64 freeBytes = 0;
    bool isReadOnly = false;
    bool isRemovable = false;
    bool isReady = false;
};

class StorageManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList drives READ drives NOTIFY drivesChanged)

public:
    explicit StorageManager(QObject *parent = nullptr);

    QVariantList drives() const;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE QVariantMap driveInfo(const QString &path) const;
    Q_INVOKABLE QVariantList mountedDrives() const;

signals:
    void drivesChanged();
    void driveAdded(const QString &path);
    void driveRemoved(const QString &path);

private slots:
    void pollDrives();

private:
    void scanDrives();

    QList<DriveInfo> drives_;
    QTimer pollTimer_;
    QStringList knownPaths_;
};
