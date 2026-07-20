#include "FilteredAppModel.h"
#include "AppModel.h"

FilteredAppModel::FilteredAppModel(QObject *parent)
    : QSortFilterProxyModel(parent)
{
    setFilterCaseSensitivity(Qt::CaseInsensitive);
}

QString FilteredAppModel::execAt(int proxyRow) const
{
    QModelIndex proxyIdx = index(proxyRow, 0);
    QModelIndex srcIdx   = mapToSource(proxyIdx);
    if (!srcIdx.isValid())
        return {};

    auto *src = qobject_cast<const AppModel *>(sourceModel());
    return src ? src->execAt(srcIdx.row()) : QString{};
}

void FilteredAppModel::setFilter(const QString &f)
{
    if (filter_ == f)
        return;
    filter_ = f;
    invalidateFilter();
    emit filterChanged();
}

bool FilteredAppModel::filterAcceptsRow(int sourceRow,
                                        const QModelIndex &sourceParent) const
{
    Q_UNUSED(sourceParent);

    if (filter_.trimmed().isEmpty())
        return true;

    const auto *src = qobject_cast<const AppModel *>(sourceModel());
    if (!src)
        return false;

    const QModelIndex idx = src->index(sourceRow, 0);
    const QString name        = idx.data(AppModel::NameRole).toString();
    const QString genericName = idx.data(AppModel::GenericNameRole).toString();
    const QString appId       = idx.data(AppModel::AppIdRole).toString();

    const QString lower = filter_.toLower();
    return name.toLower().contains(lower)
        || genericName.toLower().contains(lower)
        || appId.toLower().contains(lower);
}
