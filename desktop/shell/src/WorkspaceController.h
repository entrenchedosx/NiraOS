#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QDBusInterface>

/// Multi-workspace controller.
///
/// The NiraOS compositor does not yet expose a workspace D-Bus interface
/// (only window-list methods on io.niraos.Compositor.WindowManager).  This
/// controller probes for two well-known workspace interfaces:
///
///   1. org.gnome.Shell.Switcheroo / KDE KWin (if a future compositor upgrade
///      adds either, the shell gets real workspaces for free)
///   2. A future io.niraos.Compositor.Workspace interface
///
/// When neither is present it reports `count=1`, `current=0`, and a single
/// "Workspace 1" — the honest state for a single-workspace compositor.  It
/// does NOT fake more workspaces than exist.
class WorkspaceController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(int current READ current NOTIFY currentChanged)
    Q_PROPERTY(QStringList names READ names NOTIFY namesChanged)

public:
    explicit WorkspaceController(QObject *parent = nullptr);

    int count() const { return count_; }
    int current() const { return current_; }
    QStringList names() const { return names_; }

    Q_INVOKABLE void switchTo(int index);
    Q_INVOKABLE void next();
    Q_INVOKABLE void previous();

signals:
    void countChanged();
    void currentChanged();
    void namesChanged();

private:
    void probe();

    QDBusInterface *iface_ = nullptr;
    int count_ = 1;
    int current_ = 0;
    QStringList names_ = { QStringLiteral("Workspace 1") };
};
