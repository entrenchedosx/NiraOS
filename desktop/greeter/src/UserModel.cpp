#include "UserModel.h"

#include <QFile>
#include <QTextStream>
#include <QFileInfo>
#include <QDebug>
#include <QDir>

static const QString PASSWD_PATH = QStringLiteral("/etc/passwd");
static const QString DEFAULT_AVATAR = QStringLiteral("file:///usr/share/niraos/avatar-default.jpg");

static const QStringList VALID_SHELLS = {
    QStringLiteral("/bin/bash"),
    QStringLiteral("/bin/zsh"),
    QStringLiteral("/bin/fish"),
    QStringLiteral("/bin/sh"),
    QStringLiteral("/bin/dash"),
    QStringLiteral("/usr/bin/bash"),
    QStringLiteral("/usr/bin/zsh"),
    QStringLiteral("/usr/bin/fish"),
    QStringLiteral("/usr/bin/sh"),
};

UserModel::UserModel(QObject *parent)
    : QAbstractListModel(parent)
{
    parsePasswd();

    // Sort by UID ascending (the order users were created).
    std::sort(users_.begin(), users_.end(),
              [](const UserEntry &a, const UserEntry &b) { return a.uid < b.uid; });

    qInfo() << "UserModel: found" << users_.size() << "local users";
}

int UserModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : users_.size();
}

QVariant UserModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= users_.size())
        return {};

    const auto &u = users_.at(index.row());
    switch (role) {
    case UsernameRole:    return u.username;
    case DisplayNameRole: return u.displayName;
    case UidRole:         return u.uid;
    case HomeDirRole:     return u.homeDir;
    case AvatarPathRole:  return u.avatarPath;
    default:              return {};
    }
}

QHash<int, QByteArray> UserModel::roleNames() const
{
    return {
        { UsernameRole,    "username" },
        { DisplayNameRole, "displayName" },
        { UidRole,         "uid" },
        { HomeDirRole,     "homeDir" },
        { AvatarPathRole,  "avatarPath" },
    };
}

void UserModel::parsePasswd()
{
    QFile file(PASSWD_PATH);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning() << "UserModel: cannot open" << PASSWD_PATH;
        return;
    }

    QTextStream in(&file);
    while (!in.atEnd()) {
        QString line = in.readLine().trimmed();
        if (line.isEmpty() || line.startsWith('#'))
            continue;

        // Format: username:password:uid:gid:gecos:homedir:shell
        QStringList parts = line.split(':');
        if (parts.size() < 7)
            continue;

        bool ok = false;
        quint32 uid = parts[2].toUInt(&ok);
        // Regular local users occupy the systemd login range. Exclude the
        // overflow/nobody account (65534) even if its shell path exists.
        if (!ok || uid < 1000 || uid >= 60000)
            continue;

        QString shell = parts[6].trimmed();
        if (!isValidShell(shell))
            continue;

        UserEntry entry;
        entry.username    = parts[0];
        entry.displayName = parts[4].trimmed().split(',')[0]; // GECOS, strip room/phone
        if (entry.displayName.isEmpty())
            entry.displayName = entry.username;
        entry.uid       = uid;
        entry.homeDir   = parts[5];
        entry.shell     = shell;
        entry.avatarPath = DEFAULT_AVATAR;

        users_.append(entry);
    }
}

bool UserModel::isValidShell(const QString &shell)
{
    if (shell.isEmpty() || shell == QStringLiteral("/sbin/nologin")
        || shell == QStringLiteral("/usr/sbin/nologin")
        || shell == QStringLiteral("/usr/bin/nologin")
        || shell == QStringLiteral("/bin/false")
        || shell == QStringLiteral("/usr/bin/false"))
        return false;

    // If it's in the known list, accept.
    if (VALID_SHELLS.contains(shell))
        return true;

    // Otherwise check that the path exists.
    return QFileInfo::exists(shell);
}
