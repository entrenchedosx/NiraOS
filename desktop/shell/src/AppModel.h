#pragma once

#include <QAbstractListModel>
#include <QString>
#include <QList>
#include <QVector>

/// A single parsed desktop entry.
struct AppEntry {
    QString appId;       // filename without .desktop, e.g. "org.gnome.Nautilus"
    QString name;        // Name= field
    QString genericName; // GenericName= field (optional)
    QString iconName;    // Icon= field (may be a theme icon name or path)
    QString exec;        // Exec= field with field codes stripped
    QStringList categories;
};

/// Parses .desktop files from the standard XDG data directories and
/// exposes them as a Qt Quick model for the search-first App Launcher.
///
/// Roles: name, iconName, exec, genericName, appId
///
/// This model holds the unfiltered data.  Filtering is performed
/// by FilteredAppModel (a QSortFilterProxyModel wrapper) to avoid
/// expensive beginResetModel/endResetModel on every keystroke.
class AppModel : public QAbstractListModel
{
    Q_OBJECT

public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        IconNameRole,
        ExecRole,
        GenericNameRole,
        AppIdRole,
    };

    explicit AppModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    /// Convenience for C++ callers: return the cleaned Exec command for the
    /// entry at the given row (index into allApps_).
    QString execAt(int row) const;

private:
    void scanDirectories();
    void parseDesktopFile(const QString &path);
    static QString stripExecFieldCodes(const QString &raw);
    static QString resolveIcon(const QString &iconName);

    QList<AppEntry> allApps_; // every parsed entry (unfiltered)
};
