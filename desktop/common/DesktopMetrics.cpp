#include "DesktopMetrics.h"

NiraDesktopMetrics::NiraDesktopMetrics(QObject *parent)
    : QObject(parent)
{
}

NiraDesktopMetrics *NiraDesktopMetrics::instance()
{
    static NiraDesktopMetrics inst;
    return &inst;
}
