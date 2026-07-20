cmake_minimum_required(VERSION 3.16)
project(NiraShell VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 DBus)

# REQUIRES 6.5 opts in to QTP0001: QML module resources are placed under
# the :/qt/qml/ prefix, which is part of the engine's default import path.
# Without it, loadFromModule() cannot find the module inside the binary.
qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(nira-shell
    src/main.cpp
    src/AiClient.cpp
    src/AiClient.h
    src/ProcessLauncher.cpp
    src/ProcessLauncher.h
    src/AppModel.cpp
    src/AppModel.h
    src/FilteredAppModel.cpp
    src/FilteredAppModel.h
    src/TaskbarModel.cpp
    src/TaskbarModel.h
    src/DesktopIconModel.cpp
    src/DesktopIconModel.h
    src/TrashIconState.cpp
    src/TrashIconState.h
    src/NotificationClient.cpp
    src/NotificationClient.h
    src/WallpaperModel.cpp
    src/WallpaperModel.h
    src/VolumeControl.cpp
    src/VolumeControl.h
    src/PowerStatus.cpp
    src/PowerStatus.h
    src/WorkspaceController.cpp
    src/WorkspaceController.h
    ../common/DesktopMetrics.cpp
    ../common/DesktopMetrics.h
    shell-assets.qrc
)

# The .qrc file above bundles the NiraOS production icon library (SVG + PNG
# fallbacks) into the shell binary via the Qt Resource System.  This makes
# the shell render correctly regardless of whether the system icon theme
# is installed, and eliminates file-path dependencies for NiraOS-specific
# icons.  QML references these via "qrc:/nira/icons/<name>.svg".

# The singleton property MUST be set before qt_add_qml_module processes the
# file. Setting it afterwards (as it was before) is a silent no-op: the QML
# module is generated without the singleton flag, and every `NiraTheme.*`
# binding at runtime resolves to `undefined` (see boot.log: ~57
# "Unable to assign [undefined] to QColor/double" warnings). This single line
# was the root cause of the entire shell rendering invisibly.
set_source_files_properties(qml/NiraTheme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(nira-shell
    URI NiraOS
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/TopPanel.qml
        qml/AppLauncher.qml
        qml/AiAssistant.qml
        qml/DesktopView.qml
        qml/DesktopContextMenu.qml
        qml/NotificationsPopup.qml
        qml/WallpaperPicker.qml
        qml/ActionPreviewCard.qml
        qml/PermissionDialog.qml
        qml/NiraTheme.qml
)

target_link_libraries(nira-shell PRIVATE
    nira-ai-proto
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::DBus
)

install(TARGETS nira-shell DESTINATION bin)

# Install the .desktop entry so the shell advertises a stable app_id and
# shows up correctly in any desktop-file-aware component (launchers, etc.).
# The compositor matches the shell by appId === "nira-shell", which Qt's
# Wayland plugin derives from QGuiApplication::applicationName().
install(FILES src/io.niraos.Shell.desktop
        DESTINATION share/applications)
