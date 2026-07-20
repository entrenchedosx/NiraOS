cmake_minimum_required(VERSION 3.16)
project(NiraSettings VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2)
find_package(Protobuf CONFIG REQUIRED)
find_package(gRPC REQUIRED)

qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(nira-settings
    src/main.cpp
    src/SettingsClient.cpp
    src/SettingsClient.h
    settings-assets.qrc
)

qt_add_qml_module(nira-settings
    URI NiraSettings
    VERSION 1.0
    QML_FILES
        qml/Main.qml
)

target_link_libraries(nira-settings PRIVATE
    nira-ai-proto
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    protobuf::libprotobuf
    gRPC::grpc++
)

install(TARGETS nira-settings DESTINATION bin)
