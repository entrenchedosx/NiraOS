#include "WorkspaceController.h"

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusReply>
#include <QTimer>
#include <QDebug>

using namespace Qt::StringLiterals;

WorkspaceController::WorkspaceController(QObject *parent)
    : QObject(parent)
{
    probe();
    // Re-probe every 10s so a compositor that starts after the shell (or
    // restarts) is picked up without a shell restart.
    auto *timer = new QTimer(this);
    timer->setInterval(10000);
    connect(timer, &QTimer::timeout, this, &WorkspaceController::probe);
    timer->start();
}

void WorkspaceController::probe()
{
    // Try the planned NiraOS interface first; if the compositor gains it,
    // everything lights up automatically.
    auto bus = QDBusConnection::sessionBus();
    if (bus.interface()->isServiceRegistered(u"io.niraos.Compositor"_s)) {
        iface_ = new QDBusInterface(u"io.niraos.Compositor"_s,
                                    u"/Workspace"_s,
                                    u"io.niraos.Compositor.Workspace"_s,
                                    bus, this);
        if (!iface_->isValid()) {
            delete iface_;
            iface_ = nullptr;
        }
    }

    if (!iface_) {
        // Compositor doesn't expose workspaces yet.  Report the honest
        // single-workspace state instead of fabricating multiple workspaces.
        if (count_ != 1) { count_ = 1; emit countChanged(); }
        if (current_ != 0) { current_ = 0; emit currentChanged(); }
        if (names_ != QStringList{u"Workspace 1"_s}) {
            names_ = QStringList{u"Workspace 1"_s};
            emit namesChanged();
        }
        return;
    }

    // Read state from the compositor.  Wrap each call in a try/reply so a
    // missing method doesn't crash the shell.
    QDBusReply<int> countReply = iface_->call(u"Count"_s);
    if (countReply.isValid() && countReply.value() != count_) {
        count_ = countReply.value();
        emit countChanged();
    }
    QDBusReply<int> curReply = iface_->call(u"Current"_s);
    if (curReply.isValid() && curReply.value() != current_) {
        current_ = curReply.value();
        emit currentChanged();
    }
    QDBusReply<QStringList> namesReply = iface_->call(u"Names"_s);
    if (namesReply.isValid() && namesReply.value() != names_) {
        names_ = namesReply.value();
        if (names_.isEmpty()) {
            // Rebuild default names if the compositor returns an empty list.
            names_.reserve(count_);
            for (int i = 0; i < count_; ++i)
                names_.append(u"Workspace %1"_s.arg(i + 1));
        }
        emit namesChanged();
    }
}

void WorkspaceController::switchTo(int index)
{
    if (!iface_ || index < 0 || index >= count_) return;
    iface_->asyncCall(u"SwitchTo"_s, index);
    if (index != current_) {
        current_ = index;
        emit currentChanged();
    }
}

void WorkspaceController::next()
{
    if (count_ <= 1) return;
    switchTo((current_ + 1) % count_);
}

void WorkspaceController::previous()
{
    if (count_ <= 1) return;
    switchTo((current_ - 1 + count_) % count_);
}
