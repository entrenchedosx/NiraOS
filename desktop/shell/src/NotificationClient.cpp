#include "NotificationClient.h"

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusArgument>
#include <QDebug>

using namespace Qt::StringLiterals;

// The NiraOS notification-service exposes the org.freedesktop.Notifications
// interface at the standard object path.  We additionally listen for the
// custom `NotificationAdded` signal (see core/notification-service/src/main.rs)
// because the fdo spec defines Notify as a method, not a broadcast signal.
static const QString kService   = u"org.freedesktop.Notifications"_s;
static const QString kPath      = u"/org/freedesktop/Notifications"_s;
static const QString kInterface = u"org.freedesktop.Notifications"_s;

NotificationClient::NotificationClient(QObject *parent)
    : QAbstractListModel(parent)
{
    auto bus = QDBusConnection::sessionBus();

    // Subscribe to the custom NotificationAdded signal our server emits.  The
    // signature matches the Notify() arguments plus the assigned id.
    // The signal is delivered on the session bus; matching by service+path
    // ensures we only react to our own server.
    const bool ok = bus.connect(kService, kPath, kInterface,
                                u"NotificationAdded"_s,
                                // u=uint id, s=appName, u=replacesId, s=icon,
                                // s=summary, s=body, as=actions, i=timeout
                                this, SLOT(onNotificationAdded(uint,QString,uint,QString,QString,QString,QStringList,int)));
    if (!ok) {
        qWarning() << "NotificationClient: failed to subscribe to NotificationAdded;"
                   << "toasts will not appear until the notification-service is running"
                   << "and emits the signal.";
    } else {
        qInfo() << "NotificationClient: subscribed to" << kService << kInterface;
    }
}

int NotificationClient::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : notifications_.size();
}

QVariant NotificationClient::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= notifications_.size())
        return {};
    const auto &n = notifications_.at(index.row());
    switch (role) {
    case IdRole:         return n.id;
    case AppNameRole:    return n.appName;
    case SummaryRole:    return n.summary;
    case BodyRole:       return n.body;
    case IconRole:       return n.icon;
    case UrgencyRole:    return n.urgency;
    case TimestampRole:  return n.timestamp;
    default:             return {};
    }
}

QHash<int, QByteArray> NotificationClient::roleNames() const
{
    return {
        { IdRole,        "id" },
        { AppNameRole,   "appName" },
        { SummaryRole,   "summary" },
        { BodyRole,      "body" },
        { IconRole,      "icon" },
        { UrgencyRole,   "urgency" },
        { TimestampRole, "timestamp" },
    };
}

bool NotificationClient::dismiss(int row)
{
    if (row < 0 || row >= notifications_.size()) return false;
    beginRemoveRows(QModelIndex(), row, row);
    notifications_.removeAt(row);
    endRemoveRows();
    emit unreadCountChanged();
    return true;
}

void NotificationClient::dismissAll()
{
    if (notifications_.isEmpty()) return;
    beginResetModel();
    notifications_.clear();
    endResetModel();
    emit unreadCountChanged();
}

void NotificationClient::onNotificationAdded(uint id, const QString &appName,
                                             uint replacesId, const QString &appIcon,
                                             const QString &summary, const QString &body,
                                             const QStringList &actions, int expireTimeout)
{
    Q_UNUSED(actions);
    Q_UNUSED(expireTimeout);

    // If the server reports a replacesId, replace the matching existing
    // notification in place instead of stacking a duplicate.
    if (replacesId != 0) {
        for (int i = 0; i < notifications_.size(); ++i) {
            if (notifications_[i].id == replacesId) {
                notifications_[i].appName = appName;
                notifications_[i].summary = summary;
                notifications_[i].body    = body;
                notifications_[i].icon    = appIcon;
                notifications_[i].timestamp = QDateTime::currentDateTime();
                const QModelIndex idx = index(i);
                emit dataChanged(idx, idx);
                emit notificationAdded(summary, body);
                return;
            }
        }
    }

    const uint finalId = id != 0 ? id : nextId_++;
    beginInsertRows(QModelIndex(), 0, 0);
    Notification n;
    n.id = finalId;
    n.appName = appName;
    n.summary = summary;
    n.body = body;
    n.icon = appIcon;
    n.timestamp = QDateTime::currentDateTime();
    // Heuristic urgency: critical if summary/body contains "critical"/"error".
    // The proper way would be parsing the hints map, but the fdo spec lets
    // servers ignore urgency entirely, so a heuristic is robust.
    const QString low = (summary + u' ' + body).toLower();
    n.urgency = low.contains(u"critical"_s) || low.contains(u"error"_s) ? 2 : 1;
    notifications_.prepend(n);
    endInsertRows();
    emit unreadCountChanged();
    emit notificationAdded(summary, body);
}
