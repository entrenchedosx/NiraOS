#pragma once

#include <QObject>
#include <QString>

class NiraDesktopMetrics : public QObject {
    Q_OBJECT
    Q_PROPERTY(int mediumPadding READ mediumPadding CONSTANT)
    Q_PROPERTY(int panelContentHeight READ panelContentHeight CONSTANT)
    Q_PROPERTY(int panelReservedHeight READ panelReservedHeight CONSTANT)

public:
    explicit NiraDesktopMetrics(QObject *parent = nullptr);

    int mediumPadding() const { return 16; }
    int panelContentHeight() const { return 48; }
    int panelReservedHeight() const { return panelContentHeight() + (2 * mediumPadding()); }

    static NiraDesktopMetrics *instance();
};
