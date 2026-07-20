#pragma once

#include <QSortFilterProxyModel>
#include <QString>

/// A QSortFilterProxyModel that wraps AppModel and filters by a search
/// string.  Individual rows are added/removed via filterAcceptsRow()
/// instead of resetting the entire model, avoiding the performance
/// cost of beginResetModel/endResetModel on every keystroke.
class FilteredAppModel : public QSortFilterProxyModel
{
    Q_OBJECT

    /// The current search filter string.  Setting this updates the
    /// filter incrementally rather than resetting the model.
    Q_PROPERTY(QString filter READ filter WRITE setFilter NOTIFY filterChanged)

public:
    explicit FilteredAppModel(QObject *parent = nullptr);

    QString filter() const { return filter_; }
    void setFilter(const QString &f);

    /// Convenience for QML: return the cleaned Exec command for the
    /// entry at the given proxy model row.
    Q_INVOKABLE QString execAt(int proxyRow) const;

signals:
    void filterChanged();

protected:
    bool filterAcceptsRow(int sourceRow,
                          const QModelIndex &sourceParent) const override;

private:
    QString filter_;
};
