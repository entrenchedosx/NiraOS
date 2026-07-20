#pragma once

#include <QAbstractListModel>
#include <QFileInfo>
#include <QFileSystemWatcher>
#include <QList>
#include <QString>
#include <QDateTime>

/// A single entry on the NiraOS desktop (a file, folder, or .desktop shortcut).
struct DesktopEntry {
    QString name;          // display name (filename or Name= from .desktop)
    QString filePath;      // absolute path on disk
    QString targetPath;    // for .desktop shortcuts: the resolved target path/exec
    QString iconName;      // theme icon name or absolute path
    QString mimeType;
    QString exec;          // for .desktop shortcuts: the Exec= command
    bool isDirectory = false;
    bool isShortcut = false;   // true for .desktop files
    bool isExecutable = false;
    bool isHidden = false;
    qint64 fileSize = 0;
    QDateTime lastModified;
};

/// Scans the user's Desktop directory (XDG DesktopLocation) and exposes every
/// entry as a Qt Quick model.  Live updates are delivered through
/// QFileSystemWatcher so creating / deleting / renaming a file on the Desktop
/// is reflected in the shell immediately, without a manual refresh.
///
/// .desktop files on the Desktop are parsed (Name, Icon, Exec, URL/Path) and
/// exposed as shortcuts: isShortcut=true, with `exec` for launch-on-double-click
/// and `targetPath` for "open target location".
///
/// Roles:  name, filePath, targetPath, iconName, mimeType, exec,
///         isDirectory, isShortcut, isExecutable, isHidden, fileSize,
///         lastModified, entry (QVariantMap of all of the above)
class DesktopIconModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(QString desktopPath READ desktopPath NOTIFY desktopPathChanged)
    Q_PROPERTY(int iconCount READ iconCount NOTIFY iconCountChanged)
    Q_PROPERTY(bool showHidden READ showHidden WRITE setShowHidden NOTIFY showHiddenChanged)

public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        FilePathRole,
        TargetPathRole,
        IconNameRole,
        MimeTypeRole,
        ExecRole,
        IsDirectoryRole,
        IsShortcutRole,
        IsExecutableRole,
        IsHiddenRole,
        FileSizeRole,
        LastModifiedRole,
        EntryRole,
    };

    explicit DesktopIconModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    QString desktopPath() const { return desktopPath_; }
    int iconCount() const { return entries_.size(); }
    bool showHidden() const { return showHidden_; }
    void setShowHidden(bool show);

    /// Launch the entry at `row` (open directory, run .desktop Exec, or
    /// xdg-open the file).  Returns true if a launch was attempted.
    Q_INVOKABLE bool launch(int row);

    /// Move a desktop entry to a new grid-relative position by renaming it on
    /// disk.  Used by drag-and-drop when the user reorders icons.  Returns
    /// true on success.  The new name is unique within the Desktop directory.
    Q_INVOKABLE bool renameEntry(int row, const QString &newName);

    /// Delete (move to Trash) the entry at `row`.
    Q_INVOKABLE bool trashEntry(int row);

    /// Open the Desktop directory in the file manager.
    Q_INVOKABLE void openDesktopFolder() const;

    /// Create a new folder on the Desktop with a unique "New Folder" name.
    /// Returns the new folder's absolute path or an empty string on failure.
    Q_INVOKABLE QString createFolder();

    /// Create a new empty file on the Desktop with a unique "New File" name.
    Q_INVOKABLE QString createFile();

    /// Create a .desktop shortcut to `targetPath` with the given display name.
    Q_INVOKABLE bool createShortcut(const QString &targetPath, const QString &displayName);

    /// Force a rescan now (also triggered automatically by the file watcher).
    Q_INVOKABLE void refresh();

    /// Return a row's entry as a QVariantMap for QML convenience. Returns an
    /// empty map for an out-of-range row.  This is the canonical way to read
    /// a single entry from QML since QAbstractListModel does not expose a
    /// `get()` method by default.
    Q_INVOKABLE QVariantMap get(int row) const;

signals:
    void desktopPathChanged();
    void iconCountChanged();
    void showHiddenChanged();

private slots:
    void onDirectoryChanged(const QString &path);
    void onFileChanged(const QString &path);

private:
    void scanDirectory();
    static DesktopEntry entryFromInfo(const QFileInfo &info);
    static void parseDesktopFile(DesktopEntry &entry);
    static QString uniqueName(const QString &dirPath, const QString &baseName,
                              const QString &suffix = QString());
    static bool moveToTrash(const QString &path);

    QString desktopPath_;
    QList<DesktopEntry> entries_;
    QFileSystemWatcher *watcher_ = nullptr;
    bool showHidden_ = false;
    bool reloading_ = false;  // guards recursive onDirectoryChanged during our own writes
};
