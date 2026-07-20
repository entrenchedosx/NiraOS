#pragma once

#include <QAbstractListModel>
#include <QString>
#include <QList>

struct UserEntry {
    QString username;
    QString displayName;   // GECOS field
    quint32 uid;
    QString homeDir;
    QString shell;
    QString avatarPath;    // file:///usr/share/niraos/avatar-default.jpg
};

/// Reads /etc/passwd and exposes users with UID >= 1000 that have a
/// valid login shell.  Populated synchronously at construction.
class UserModel : public QAbstractListModel
{
    Q_OBJECT

public:
    enum Roles {
        UsernameRole = Qt::UserRole + 1,
        DisplayNameRole,
        UidRole,
        HomeDirRole,
        AvatarPathRole,
    };

    explicit UserModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

private:
    void parsePasswd();
    static bool isValidShell(const QString &shell);

    QList<UserEntry> users_;
};
