#include "ProcessLauncher.h"
#include <QProcess>
#include <QDebug>
#include <QFileInfo>
#include <QStandardPaths>

ProcessLauncher::ProcessLauncher(QObject *parent) : QObject(parent)
{
}

void ProcessLauncher::launch(const QString &command)
{
    qInfo() << "ProcessLauncher executing:" << command;
    QStringList args = QProcess::splitCommand(command);
    if (args.isEmpty()) {
        qWarning() << "ProcessLauncher rejected an empty command";
        return;
    }

    QString prog = args.takeFirst();
    const QString executable = QFileInfo(prog).isAbsolute()
        ? prog
        : QStandardPaths::findExecutable(prog);
    if (executable.isEmpty() || !QFileInfo(executable).isExecutable()) {
        qWarning() << "ProcessLauncher executable was not found:" << prog;
        return;
    }

    if (!QProcess::startDetached(executable, args))
        qWarning() << "ProcessLauncher failed to start:" << executable << args;
}
