#pragma once

#include <QAbstractListModel>
#include <QFileInfo>
#include <QIcon>
#include <QList>
#include <QString>
#include <QTimer>
#include <QVector>
#include <QMutex>
#include <QtConcurrent>

struct FileEntry {
    QString fileName;
    QString filePath;
    qint64 fileSize = 0;
    QString fileType;       // "directory", "file", "symlink", "socket", etc.
    QString mimeType;
    QDateTime lastModified;
    QDateTime lastAccessed;
    QDateTime created;
    QFile::Permissions permissions;
    bool isExecutable = false;
    bool isHidden = false;
    bool isReadable = false;
    bool isWritable = false;
    QString iconName;
    QString thumbnail;      // image URL if available
    QString owner;
    QString group;
};

class FileModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(QString currentPath READ currentPath WRITE setCurrentPath NOTIFY currentPathChanged)
    Q_PROPERTY(int sortColumn READ sortColumn WRITE setSortColumn NOTIFY sortChanged)
    Q_PROPERTY(Qt::SortOrder sortOrder READ sortOrder WRITE setSortOrder NOTIFY sortChanged)
    Q_PROPERTY(QString nameFilter READ nameFilter WRITE setNameFilter NOTIFY filterChanged)
    Q_PROPERTY(bool showHidden READ showHidden WRITE setShowHidden NOTIFY showHiddenChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)

public:
    enum Roles {
        FileNameRole = Qt::UserRole + 1,
        FilePathRole,
        FileSizeRole,
        FileTypeRole,
        MimeTypeRole,
        LastModifiedRole,
        LastAccessedRole,
        CreatedRole,
        PermissionsRole,
        IsExecutableRole,
        IsHiddenRole,
        IsReadableRole,
        IsWritableRole,
        IconNameRole,
        ThumbnailRole,
        OwnerRole,
        GroupRole,
        FileEntryRole,
    };

    enum SortColumn {
        SortByName = 0,
        SortBySize,
        SortByType,
        SortByDate,
    };

    explicit FileModel(QObject *parent = nullptr);
    ~FileModel() override;

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    QString currentPath() const;
    void setCurrentPath(const QString &path);

    int sortColumn() const;
    void setSortColumn(int column);

    Qt::SortOrder sortOrder() const;
    void setSortOrder(Qt::SortOrder order);

    QString nameFilter() const;
    void setNameFilter(const QString &filter);

    bool showHidden() const;
    void setShowHidden(bool show);

    bool loading() const;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void navigateUp();
    Q_INVOKABLE void navigateTo(const QString &path);
    Q_INVOKABLE QString parentPath(const QString &path) const;
    Q_INVOKABLE QVariantMap fileInfoAt(int row) const;

signals:
    void currentPathChanged();
    void sortChanged();
    void filterChanged();
    void showHiddenChanged();
    void loadingChanged();
    void navigateRequested(const QString &path);
    void openFileRequested(const QString &path);

private slots:
    void onDirectoryLoaded();

private:
    void startDirectoryLoad(const QString &path);
    QVariantMap entryToMap(const FileEntry &entry) const;
    static QList<FileEntry> loadDirectory(const QString &path);
    void applySort();
    void sortEntries();

    QString currentPath_;
    QList<FileEntry> entries_;
    int sortColumn_ = SortByName;
    Qt::SortOrder sortOrder_ = Qt::AscendingOrder;
    QString nameFilter_;
    bool showHidden_ = false;
    bool loading_ = false;
    QMutex mutex_;
    QFutureWatcher<QList<FileEntry>> *watcher_ = nullptr;
};
