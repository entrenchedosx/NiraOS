#include "PowerStatus.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QTextStream>
#include <QTimer>
#include <QDebug>

using namespace Qt::StringLiterals;

PowerStatus::PowerStatus(QObject *parent)
    : QObject(parent)
{
    scan();
    // Power supply state can change at any time (AC plugged/unplugged,
    // discharge). Poll every 5s — the sysfs reads are cheap and there is no
    // universally-available uevent signal we could subscribe to from Qt
    // without udev.
    auto *timer = new QTimer(this);
    timer->setInterval(5000);
    connect(timer, &QTimer::timeout, this, &PowerStatus::refresh);
    timer->start();
}

void PowerStatus::refresh()
{
    scan();
}

void PowerStatus::scan()
{
    const QDir powerSupply(u"/sys/class/power_supply"_s);
    if (!powerSupply.exists()) {
        if (present_) { present_ = false; emit presentChanged(); }
        return;
    }

    // Find the first entry whose type is "Battery" (skip pure AC adapters
    // like ADP1).  UPSes (type=Mains) are intentionally ignored — desktop
    // users on a UPS don't get a laptop-style battery icon.
    QString found;
    const auto entries = powerSupply.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QFileInfo &fi : entries) {
        QFile typeFile(fi.absoluteFilePath() + u"/type"_s);
        if (typeFile.open(QIODevice::ReadOnly)) {
            const QString t = QTextStream(&typeFile).readAll().trimmed();
            if (t == u"Battery"_s) {
                found = fi.absoluteFilePath();
                break;
            }
        }
    }

    if (found.isEmpty()) {
        if (present_) { present_ = false; emit presentChanged(); }
        return;
    }
    batteryDir_ = found;

    // Read capacity and status.  Missing files degrade gracefully (we keep
    // the previous value rather than reporting 0/Unknown).
    QFile cap(batteryDir_ + u"/capacity"_s);
    if (cap.open(QIODevice::ReadOnly)) {
        bool ok = false;
        const int p = QTextStream(&cap).readAll().trimmed().toInt(&ok);
        if (ok && p != percent_) {
            percent_ = p;
            emit percentChanged();
        }
    }
    QFile st(batteryDir_ + u"/status"_s);
    if (st.open(QIODevice::ReadOnly)) {
        const QString s = QTextStream(&st).readAll().trimmed();
        if (s != status_) {
            status_ = s;
            emit statusChanged();
        }
    }

    if (!present_) {
        present_ = true;
        emit presentChanged();
    }
}
