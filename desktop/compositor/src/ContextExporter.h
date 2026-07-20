#pragma once

#include <QObject>
#include <QString>
#include <QTimer>
#include <QAtomicInt>

/// Debounced writer of the active Wayland surface identity.
///
/// Setter calls only update in-memory state and restart a short timer.
/// When the timer fires, file I/O is dispatched to a background thread
/// via QtConcurrent::run so the compositor's GUI thread is never
/// blocked by disk writes.
class ContextExporter : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString activeAppId READ activeAppId WRITE setActiveAppId NOTIFY activeWindowChanged)
    Q_PROPERTY(QString activeTitle READ activeTitle WRITE setActiveTitle NOTIFY activeWindowChanged)
    Q_PROPERTY(QString seatName READ seatName CONSTANT)

public:
    explicit ContextExporter(QObject *parent = nullptr);

    QString activeAppId() const { return activeAppId_; }
    QString activeTitle() const { return activeTitle_; }
    QString seatName() const { return seatName_; }

public slots:
    void setActiveAppId(const QString &appId);
    void setActiveTitle(const QString &title);
    void flush();

signals:
    void activeWindowChanged();

private slots:
    void onFlushTimer();

private:
    static void writeToDisk(const QString &path, const QString &appId,
                            const QString &title, const QString &seat);

    QString activeAppId_;
    QString activeTitle_;
    QString filePath_;
    QString seatName_;
    QTimer flushTimer_;
    QAtomicInt pendingFlush_;
};
