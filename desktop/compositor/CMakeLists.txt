cmake_minimum_required(VERSION 3.16)
project(NiraCompositor VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Quick Qml WaylandCompositor Concurrent DBus)

# REQUIRES 6.5 opts in to QTP0001: QML module resources are placed under
# the :/qt/qml/ prefix, which is part of the engine's default import path.
# Without it, loadFromModule() cannot find the module inside the binary.
qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(nira-compositor
    src/main.cpp
    src/ContextExporter.cpp
    src/ContextExporter.h
    src/WallpaperWatcher.cpp
    src/WallpaperWatcher.h
    src/WindowManagerDBus.cpp
    src/WindowManagerDBus.h
    ../common/DesktopMetrics.cpp
    ../common/DesktopMetrics.h
)

qt_add_qml_module(nira-compositor
    URI NiraCompositor
    VERSION 1.0
    QML_FILES
        qml/Main.qml
)

target_link_libraries(nira-compositor PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Quick
    Qt6::Qml
    Qt6::WaylandCompositor
    Qt6::Concurrent
    Qt6::DBus
)

install(TARGETS nira-compositor DESTINATION bin)
