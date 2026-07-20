#pragma once

#include <QAbstractListModel>
#include <QList>
#include <QString>
#include <QDateTime>
#include <QDBusConnection>

/// Subscribes to the FreeDesktop.org `org.freedesktop.Notifications.Notify`
/// D-Bus signal emitted by the NiraOS notification-service (Rust) and exposes
/// each notification as a row in a Qt Quick model.  The shell renders a toast
/// stack from this model.
///
/// Roles: id, appName, summary, body, icon, urgency, timestamp
///
/// Note: the fdo Notifications spec does NOT emit a `Notify` signal by
/// default — `Notify` is a *method call* an app makes to the server.  We
/// therefore cannot passively observe other apps' notifications through the
/// standard interface.  Instead, the NiraOS notification-service is wired to
/// re-emit each Notify invocation as a custom `NotificationAdded` signal on
/// its own interface (see core/notification-service/src/main.rs), which this
/// client subscribes to.  This is the same pattern GNOME Shell and KDE
/// Plasma use (their respective shell bus names).
class NotificationClient : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int unreadCount READ unreadCount NOTIFY unreadCountChanged)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        AppNameRole,
        SummaryRole,
        BodyRole,
        IconRole,
        UrgencyRole,
        TimestampRole,
    };

    explicit NotificationClient(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    int unreadCount() const { return notifications_.size(); }

    /// Dismiss the notification at `row` (removes it from the model and the
    /// toast stack).  Returns true on success.
    Q_INVOKABLE bool dismiss(int row);
    /// Dismiss all notifications.
    Q_INVOKABLE void dismissAll();

signals:
    void unreadCountChanged();
    void notificationAdded(const QString &summary, const QString &body);

private slots:
    void onNotificationAdded(uint id, const QString &appName, uint replacesId,
                             const QString &appIcon, const QString &summary,
                             const QString &body, const QStringList &actions,
                             int expireTimeout);

private:
    struct Notification {
        uint id = 0;
        QString appName;
        QString summary;
        QString body;
        QString icon;
        int urgency = 1;        // 0=low, 1=normal, 2=critical
        QDateTime timestamp;
    };

    QList<Notification> notifications_;
    uint nextId_ = 1;
};
