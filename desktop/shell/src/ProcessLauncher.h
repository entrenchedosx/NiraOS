#pragma once

#include <QObject>
#include <QString>

class ProcessLauncher : public QObject
{
    Q_OBJECT
public:
    explicit ProcessLauncher(QObject *parent = nullptr);

    Q_INVOKABLE void launch(const QString &command);
};
