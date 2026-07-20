#pragma once

#include <QAbstractListModel>
#include <QStringList>
#include <QFileSystemWatcher>
#include <QUrl>

/// Lists all NiraOS wallpapers: system wallpapers under
/// /usr/share/niraos/wallpapers and user wallpapers under
/// ~/.local/share/niraos/wallpapers.  Exposed as a Qt Quick model so the
/// Settings / right-click-desktop wallpaper picker can render a real grid
/// instead of a single hard-coded path.
///
/// Roles: name, path, isUser
class WallpaperModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(QUrl currentWallpaper READ currentWallpaper WRITE setCurrentWallpaper NOTIFY currentWallpaperChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        PathRole,
        IsUserRole,
    };

    explicit WallpaperModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    QUrl currentWallpaper() const { return current_; }
    void setCurrentWallpaper(const QUrl &u);

    int count() const { return rowCount(); }

    /// Persist the current wallpaper choice to QSettings so it survives a
    /// restart.  Called automatically by setCurrentWallpaper.
    Q_INVOKABLE void saveCurrent();
    /// Reload from QSettings on startup.  Called from the constructor.
    Q_INVOKABLE void loadCurrent();

signals:
    void currentWallpaperChanged();
    void countChanged();

private slots:
    void onDirectoryChanged(const QString &path);

private:
    struct WallEntry { QString name; QString path; bool isUser; };
    void scanAll();

    QList<WallEntry> entries_;
    QUrl current_;
    QFileSystemWatcher *watcher_ = nullptr;
    bool reloading_ = false;
};
