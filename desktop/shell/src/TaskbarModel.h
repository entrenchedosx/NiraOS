#pragma once

#include <QAbstractListModel>
#include <QList>
#include <QString>
#include <QDBusInterface>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCall>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>

/// Live list of open windows provided by the compositor's D-Bus service.
///
/// Roles:  windowId, title, appId, isMinimized, isFocused
class TaskbarModel : public QAbstractListModel
{
    Q_OBJECT

public:
    enum Roles {
        WindowIdRole = Qt::UserRole + 1,
        TitleRole,
        AppIdRole,
        IsMinimizedRole,
        IsFocusedRole,
    };

    explicit TaskbarModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    /// Call these from QML to request window operations via D-Bus.
    Q_INVOKABLE void activate(int row);
    Q_INVOKABLE void minimize(int row);
    Q_INVOKABLE void toggle(int row);
    Q_INVOKABLE void close(int row);

private slots:
    void onWindowRegistered(const QString &id, const QString &title, const QString &appId);
    void onWindowUnregistered(const QString &id);
    void onWindowStateChanged(const QString &id, bool minimized, bool focused);
    void onWindowMetadataChanged(const QString &id, const QString &title,
                                 const QString &appId);

private:
    struct WindowEntry {
        QString windowId;
        QString title;
        QString appId;
        bool minimized = false;
        bool focused  = false;
    };

    int indexOf(const QString &id) const;
    QDBusInterface *iface_ = nullptr;
    QList<WindowEntry> windows_;
    // Preserve the last focused application while the desktop shell briefly
    // owns keyboard focus during a panel click. This makes a click on the
    // active task button reliably minimize instead of immediately restoring.
    QString lastFocusedWindowId_;
};
