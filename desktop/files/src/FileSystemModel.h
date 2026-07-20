#pragma once

#include <QAbstractItemModel>
#include <QDateTime>
#include <QFileIconProvider>
#include <QHash>
#include <QIcon>
#include <QMimeDatabase>
#include <QSortFilterProxyModel>

// Column indices for the model.
enum FileSystemColumn {
    NameColumn = 0,
    SizeColumn,
    TypeColumn,
    DateColumn,
    ColumnCount
};

// Metadata for a single filesystem entry.
struct FileSystemEntry {
    QString name;
    QString absolutePath;
    bool isDir;
    bool isHidden;
    qint64 size;
    QString type;        // MIME type or "Folder"
    QDateTime modified;
    bool isSymLink;
    QString symLinkTarget;
};

// Flat list model for the entries in a single directory.
// Does NOT attempt a tree model — the view drives navigation by
// calling setPath() when the user enters a folder or clicks a
// sidebar entry.  This avoids the complexity of recursive
// population and matches how most file managers work.
class FileSystemModel : public QAbstractItemModel
{
    Q_OBJECT

    // Exposed QML properties
    Q_PROPERTY(QString currentPath READ currentPath NOTIFY currentPathChanged)
    Q_PROPERTY(QString currentDirName READ currentDirName NOTIFY currentPathChanged)

public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        AbsolutePathRole,
        IsDirRole,
        IsHiddenRole,
        SizeRole,
        TypeRole,
        DateRole,
        IsSymLinkRole,
        SymLinkTargetRole,
        IconNameRole
    };
    Q_ENUM(Roles)

    explicit FileSystemModel(QObject *parent = nullptr);
    ~FileSystemModel() override = default;

    // QAbstractItemModel interface (flat list — parent is always invalid)
    QModelIndex index(int row, int column, const QModelIndex &parent) const override;
    QModelIndex parent(const QModelIndex &child) const override;
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    int columnCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    // Navigation
    Q_INVOKABLE QString currentPath() const { return m_currentPath; }
    Q_INVOKABLE QString currentDirName() const;
    Q_INVOKABLE void setPath(const QString &path);
    Q_INVOKABLE void goUp();
    Q_INVOKABLE void goToHome();
    Q_INVOKABLE void createFolder(const QString &name);
    Q_INVOKABLE void createFile(const QString &name);

    // File operations
    Q_INVOKABLE bool copy(const QStringList &sourcePaths, const QString &destDir);
    Q_INVOKABLE bool move(const QStringList &sourcePaths, const QString &destDir);
    Q_INVOKABLE bool rename(const QString &path, const QString &newName);
    Q_INVOKABLE bool remove(const QStringList &paths); // moveToTrash preferred
    Q_INVOKABLE bool moveToTrash(const QStringList &paths);

    // File info
    Q_INVOKABLE QVariantMap fileProperties(const QString &path) const;

    // Path helpers
    Q_INVOKABLE QString homePath() const { return QDir::homePath(); }
    Q_INVOKABLE QString rootPath() const { return QDir::rootPath(); }
    Q_INVOKABLE QStringList sidebarPlaces() const;

signals:
    void currentPathChanged();
    void errorOccurred(const QString &message);
    void operationCompleted(const QString &message);

private:
    void refresh();
    void sortEntries();
    bool confirmDelete(const QString &path); // future: emit signal for QML dialog

    QString m_currentPath;
    QList<FileSystemEntry> m_entries;
    QMimeDatabase m_mimeDb;
};
