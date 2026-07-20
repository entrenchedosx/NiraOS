cmake_minimum_required(VERSION 3.16)
project(NiraFiles VERSION 0.1.0 LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 Concurrent)
qt_standard_project_setup(REQUIRES 6.5)
qt_add_executable(nira-files
    src/main.cpp
    src/FileModel.cpp src/FileModel.h
    src/FileOperations.cpp src/FileOperations.h
    src/FileSystemWatcher.cpp src/FileSystemWatcher.h
    src/ThumbnailProvider.cpp src/ThumbnailProvider.h
    src/SearchIndexer.cpp src/SearchIndexer.h
    src/StorageManager.cpp src/StorageManager.h
    ../../desktop/common/DesktopMetrics.cpp
    ../../desktop/common/DesktopMetrics.h
    files-assets.qrc
)
qt_add_qml_module(nira-files
    URI NiraFiles
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/BreadcrumbBar.qml
        qml/FileView.qml
        qml/Sidebar.qml
        qml/SidebarItem.qml
        qml/PropertiesDialog.qml
        qml/PropertyRow.qml
        qml/StatusBar.qml
)
target_link_libraries(nira-files PRIVATE
    Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::QuickControls2 Qt6::Concurrent
)
install(TARGETS nira-files DESTINATION bin)
install(FILES src/io.niraos.Files.desktop
        DESTINATION share/applications)
