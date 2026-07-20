pragma Singleton
import QtQuick

QtObject {
    id: niraTheme
    
    property bool isDarkMode: true
    
    // --- Colors ---
    property color background: isDarkMode ? "#0A0A0E" : "#F2F2F5"
    property color surface: isDarkMode ? "#141418" : "#FFFFFF"
    property color glassBackground: isDarkMode ? "#B00E0E14" : "#CCFFFFFF"
    property color glassBorder: isDarkMode ? "#28FFFFFF" : "#28000000"
    property color glassHighlight: isDarkMode ? "#44FFFFFF" : "#44000000"
    
    property color textPrimary: isDarkMode ? "#F0F0F5" : "#1C1C1E"
    property color textSecondary: isDarkMode ? "#8E8E98" : "#8A8A8E"
    property color textMuted: isDarkMode ? "#5A5A64" : "#C0C0C4"
    
    // Accents
    property color accentPrimary: "#00E5FF"
    property color accentSecondary: "#7000FF"
    property color accentAi: "#AA00FFFF"
    property color accentSuccess: "#34C759"
    property color accentWarning: "#FF9F0A"
    property color accentDanger: "#FF453A"
    property color accentInfo: "#5AC8FA"
    
    // --- Metrics ---
    property int radiusSmall: 6
    property int radiusMedium: 10
    property int radiusLarge: 18
    
    property int paddingSmall: 6
    property int paddingMedium: desktopMetrics.mediumPadding
    property int paddingLarge: 20
    
    property int panelHeight: desktopMetrics.panelContentHeight
    
    // --- Animations ---
    property int animMicro: 80
    property int animQuick: 120
    property int animFast: 150
    property int animNormal: 250
    property int animSlow: 400
}
