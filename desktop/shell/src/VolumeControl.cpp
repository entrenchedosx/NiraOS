#include "VolumeControl.h"

#include <QStandardPaths>
#include <QProcess>
#include <QRegularExpression>
#include <QTimer>
#include <QDebug>

using namespace Qt::StringLiterals;

VolumeControl::VolumeControl(QObject *parent)
    : QObject(parent)
{
    probeAvailability();
    if (available_) {
        readState();
        // Poll every 3s so external volume changes (e.g. hardware keys or
        // another app) are reflected.  PipeWire-Pulse doesn't always emit a
        // signal we can subscribe to without a C API.
        auto *timer = new QTimer(this);
        timer->setInterval(3000);
        connect(timer, &QTimer::timeout, this, &VolumeControl::readState);
        timer->start();
    }
}

QString VolumeControl::pactlPath()
{
    return QStandardPaths::findExecutable(u"pactl"_s);
}

void VolumeControl::probeAvailability()
{
    available_ = !pactlPath().isEmpty();
    if (!available_)
        qWarning() << "VolumeControl: pactl not found; volume controls disabled";
    emit availableChanged();
}

void VolumeControl::readState()
{
    if (!available_) return;
    // `pactl get-sink-mute @DEFAULT_SINK@` and `get-sink-volume` are the
    // stable, version-independent ways to query the default output.  We
    // parse the human-readable output rather than depending on JSON.
    QProcess *p = new QProcess(this);
    p->start(pactlPath(), {u"get-sink-mute"_s, u"@DEFAULT_SINK@"_s});
    connect(p, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this, p](int, QProcess::ExitStatus) {
        const QString out = p->readAllStandardOutput();
        p->deleteLater();
        const bool m = out.contains(u"Mute: yes"_s, Qt::CaseInsensitive);
        if (m != muted_) { muted_ = m; emit mutedChanged(); }
    });

    QProcess *vp = new QProcess(this);
    vp->start(pactlPath(), {u"get-sink-volume"_s, u"@DEFAULT_SINK@"_s});
    connect(vp, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this, vp](int, QProcess::ExitStatus) {
        const QString out = vp->readAllStandardOutput();
        vp->deleteLater();
        // Sample output: "Volume: front-left: 65536 / 100% / 0.00 dB, front-right: ..."
        // Take the first percentage as the representative value.
        QRegularExpression re(u"(\\d+)%"_s);
        const auto m = re.match(out);
        if (m.hasMatch()) {
            const int v = m.captured(1).toInt();
            if (v != volume_) { volume_ = v; emit volumeChanged(); }
        }
    });
}

void VolumeControl::setVolume(int percent)
{
    if (!available_) return;
    percent = qBound(0, percent, 100);
    if (percent == volume_) return;
    // pactl expects a linear volume in the 0..65535 range; the "100%" form
    // is portable across PipeWire and PulseAudio.
    QProcess::startDetached(pactlPath(),
        {u"set-sink-volume"_s, u"@DEFAULT_SINK@"_s, QString::number(percent) + u"%"_s});
    volume_ = percent;
    emit volumeChanged();
}

void VolumeControl::toggleMuted()
{
    if (!available_) return;
    const QString next = muted_ ? u"0"_s : u"1"_s;
    QProcess::startDetached(pactlPath(),
        {u"set-sink-mute"_s, u"@DEFAULT_SINK@"_s, next});
    muted_ = !muted_;
    emit mutedChanged();
}

void VolumeControl::refresh()
{
    readState();
}
