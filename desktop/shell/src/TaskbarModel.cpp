#include "TaskbarModel.h"

#include <QDebug>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMetaType>
#include <QDBusPendingCall>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusReply>
#include <memory>

static const QString service   = QStringLiteral("io.niraos.Compositor");
static const QString path      = QStringLiteral("/WindowManager");
static const QString interface = QStringLiteral("io.niraos.Compositor.WindowManager");

TaskbarModel::TaskbarModel(QObject *parent)
    : QAbstractListModel(parent)
{
    // Connect to the compositor's D-Bus signals.
    auto bus = QDBusConnection::sessionBus();

    const bool registeredConnected = bus.connect(service, path, interface,
                QStringLiteral("windowRegistered"),
                this, SLOT(onWindowRegistered(QString,QString,QString)));

    const bool unregisteredConnected = bus.connect(service, path, interface,
                QStringLiteral("windowUnregistered"),
                this, SLOT(onWindowUnregistered(QString)));

    const bool stateConnected = bus.connect(service, path, interface,
                QStringLiteral("windowStateChanged"),
                this, SLOT(onWindowStateChanged(QString,bool,bool)));

    const bool metadataConnected = bus.connect(service, path, interface,
                QStringLiteral("windowMetadataChanged"),
                this, SLOT(onWindowMetadataChanged(QString,QString,QString)));

    if (!registeredConnected || !unregisteredConnected || !stateConnected
        || !metadataConnected)
        qWarning() << "TaskbarModel: failed to subscribe to one or more window signals";

    // Create an interface proxy for calling methods.
    iface_ = new QDBusInterface(service, path, interface, bus, this);
    if (!iface_->isValid()) {
        qWarning() << "TaskbarModel: compositor D-Bus service not available";
    } else {
        qInfo() << "TaskbarModel: connected to compositor D-Bus";

        // Signals are not a state-recovery mechanism: the shell can start
        // after clients already mapped or reconnect after a crash. Seed the
        // model from the compositor's authoritative registry using async
        // D-Bus so the main thread is never blocked during startup.
        QDBusPendingCallWatcher *listWatcher = new QDBusPendingCallWatcher(
            iface_->asyncCall(QStringLiteral("ListWindowIds")), this);
        connect(listWatcher, &QDBusPendingCallWatcher::finished, this,
                [this](QDBusPendingCallWatcher *w) {
            w->deleteLater();
            QDBusPendingReply<QStringList> reply = *w;
            if (reply.isError()) {
                qWarning() << "TaskbarModel: ListWindowIds failed:" << reply.error().message();
                return;
            }
            for (const QString &id : reply.value()) {
                struct PendingData {
                    int remaining = 4;
                    QString title;
                    QString appId;
                    bool minimized = false;
                    bool focused = false;
                };
                auto data = std::make_shared<PendingData>();

                auto tWatch = new QDBusPendingCallWatcher(
                    iface_->asyncCall(QStringLiteral("WindowTitle"), id), this);
                connect(tWatch, &QDBusPendingCallWatcher::finished, this,
                        [this, id, data](QDBusPendingCallWatcher *w) {
                    QDBusPendingReply<QString> r = *w;
                    w->deleteLater();
                    if (!r.isError()) data->title = r.value();
                    if (--data->remaining == 0) {
                        onWindowRegistered(id, data->title, data->appId);
                        onWindowStateChanged(id, data->minimized, data->focused);
                    }
                });

                auto aWatch = new QDBusPendingCallWatcher(
                    iface_->asyncCall(QStringLiteral("WindowAppId"), id), this);
                connect(aWatch, &QDBusPendingCallWatcher::finished, this,
                        [this, id, data](QDBusPendingCallWatcher *w) {
                    QDBusPendingReply<QString> r = *w;
                    w->deleteLater();
                    if (!r.isError()) data->appId = r.value();
                    if (--data->remaining == 0) {
                        onWindowRegistered(id, data->title, data->appId);
                        onWindowStateChanged(id, data->minimized, data->focused);
                    }
                });

                auto mWatch = new QDBusPendingCallWatcher(
                    iface_->asyncCall(QStringLiteral("WindowMinimized"), id), this);
                connect(mWatch, &QDBusPendingCallWatcher::finished, this,
                        [this, id, data](QDBusPendingCallWatcher *w) {
                    QDBusPendingReply<bool> r = *w;
                    w->deleteLater();
                    if (!r.isError()) data->minimized = r.value();
                    if (--data->remaining == 0) {
                        onWindowRegistered(id, data->title, data->appId);
                        onWindowStateChanged(id, data->minimized, data->focused);
                    }
                });

                auto fWatch = new QDBusPendingCallWatcher(
                    iface_->asyncCall(QStringLiteral("WindowFocused"), id), this);
                connect(fWatch, &QDBusPendingCallWatcher::finished, this,
                        [this, id, data](QDBusPendingCallWatcher *w) {
                    QDBusPendingReply<bool> r = *w;
                    w->deleteLater();
                    if (!r.isError()) data->focused = r.value();
                    if (--data->remaining == 0) {
                        onWindowRegistered(id, data->title, data->appId);
                        onWindowStateChanged(id, data->minimized, data->focused);
                    }
                });
            }
        });
    }
}

// ── Model API ──────────────────────────────────────────────────────────

int TaskbarModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : windows_.size();
}

QVariant TaskbarModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= windows_.size())
        return {};

    const auto &w = windows_.at(index.row());
    switch (role) {
    case WindowIdRole:      return w.windowId;
    case TitleRole:         return w.title;
    case AppIdRole:         return w.appId;
    case IsMinimizedRole:   return w.minimized;
    case IsFocusedRole:     return w.focused;
    default:                return {};
    }
}

QHash<int, QByteArray> TaskbarModel::roleNames() const
{
    return {
        { WindowIdRole,    "windowId" },
        { TitleRole,       "title" },
        { AppIdRole,       "appId" },
        { IsMinimizedRole, "isMinimized" },
        { IsFocusedRole,   "isFocused" },
    };
}

// ── D-Bus signal receivers ─────────────────────────────────────────────

void TaskbarModel::onWindowRegistered(const QString &id,
                                       const QString &title,
                                       const QString &appId)
{
    const int existing = indexOf(id);
    if (existing >= 0) {
        onWindowMetadataChanged(id, title, appId);
        return;
    }
    beginInsertRows(QModelIndex(), windows_.size(), windows_.size());
    windows_.append({id, title, appId, false, false});
    endInsertRows();
    qInfo() << "TaskbarModel: window registered" << id << title;
}

void TaskbarModel::onWindowMetadataChanged(const QString &id,
                                            const QString &title,
                                            const QString &appId)
{
    const int i = indexOf(id);
    if (i < 0)
        return;
    auto &window = windows_[i];
    if (window.title == title && window.appId == appId)
        return;
    window.title = title;
    window.appId = appId;
    emit dataChanged(index(i), index(i), {TitleRole, AppIdRole});
}

void TaskbarModel::onWindowUnregistered(const QString &id)
{
    int i = indexOf(id);
    if (i < 0) return;
    beginRemoveRows(QModelIndex(), i, i);
    windows_.removeAt(i);
    endRemoveRows();
}

void TaskbarModel::onWindowStateChanged(const QString &id,
                                         bool minimized, bool focused)
{
    int i = indexOf(id);
    if (i < 0) return;
    auto &w = windows_[i];
    if (w.minimized == minimized && w.focused == focused)
        return;
    w.minimized = minimized;
    w.focused = focused;
    if (focused)
        lastFocusedWindowId_ = id;
    emit dataChanged(index(i), index(i), {IsMinimizedRole, IsFocusedRole});
}

// ── QML-callable actions ───────────────────────────────────────────────

void TaskbarModel::activate(int row)
{
    if (row < 0 || row >= windows_.size()) return;
    if (iface_)
        iface_->asyncCall(QStringLiteral("ActivateWindow"), windows_[row].windowId);
}

void TaskbarModel::minimize(int row)
{
    if (row < 0 || row >= windows_.size()) return;
    if (iface_)
        iface_->asyncCall(QStringLiteral("MinimizeWindow"), windows_[row].windowId);
}

void TaskbarModel::toggle(int row)
{
    if (row < 0 || row >= windows_.size() || !iface_)
        return;

    const auto &window = windows_.at(row);
    if (!window.minimized && window.windowId == lastFocusedWindowId_)
        iface_->asyncCall(QStringLiteral("MinimizeWindow"), window.windowId);
    else
        iface_->asyncCall(QStringLiteral("ActivateWindow"), window.windowId);
}

void TaskbarModel::close(int row)
{
    if (row < 0 || row >= windows_.size()) return;
    if (iface_)
        iface_->asyncCall(QStringLiteral("CloseWindow"), windows_[row].windowId);
}

// ── Helpers ────────────────────────────────────────────────────────────

int TaskbarModel::indexOf(const QString &id) const
{
    for (int i = 0; i < windows_.size(); ++i) {
        if (windows_[i].windowId == id)
            return i;
    }
    return -1;
}
