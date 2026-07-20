cmake_minimum_required(VERSION 3.20)
project(NiraOS VERSION 0.1.0 DESCRIPTION "AI-First Linux Distribution")

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

message(STATUS "Configuring NiraOS build environment")

find_package(Qt6 COMPONENTS Core Gui Qml Quick WaylandCompositor REQUIRED)
# Generate qmldir metadata for nested QML source directories. This adopts the
# current Qt behavior explicitly instead of relying on a deprecated policy
# default that changes between Qt releases.
qt_policy(SET QTP0004 NEW)
# Use protobuf's CMake package config (not CMake's legacy FindProtobuf module):
# gRPC's config re-imports the full protobuf export set and the two must agree.
find_package(Protobuf CONFIG REQUIRED)
find_package(gRPC REQUIRED)
find_program(NIRA_PROTOC_EXECUTABLE protoc REQUIRED)
find_program(NIRA_GRPC_CPP_PLUGIN_EXECUTABLE grpc_cpp_plugin REQUIRED)

set(NIRA_PROTO_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/ipc/proto")
set(NIRA_PROTO_GENERATED_DIR "${CMAKE_CURRENT_BINARY_DIR}/generated")
set(NIRA_PROTO_SOURCES
    "${NIRA_PROTO_GENERATED_DIR}/v1/common.pb.cc"
    "${NIRA_PROTO_GENERATED_DIR}/v1/ai.pb.cc"
    "${NIRA_PROTO_GENERATED_DIR}/v1/ai.grpc.pb.cc"
    "${NIRA_PROTO_GENERATED_DIR}/v1/settings.pb.cc"
    "${NIRA_PROTO_GENERATED_DIR}/v1/settings.grpc.pb.cc"
    "${NIRA_PROTO_GENERATED_DIR}/v1/hardware.pb.cc"
    "${NIRA_PROTO_GENERATED_DIR}/v1/hardware.grpc.pb.cc"
)
set(NIRA_PROTO_HEADERS
    "${NIRA_PROTO_GENERATED_DIR}/v1/common.pb.h"
    "${NIRA_PROTO_GENERATED_DIR}/v1/ai.pb.h"
    "${NIRA_PROTO_GENERATED_DIR}/v1/ai.grpc.pb.h"
    "${NIRA_PROTO_GENERATED_DIR}/v1/settings.pb.h"
    "${NIRA_PROTO_GENERATED_DIR}/v1/settings.grpc.pb.h"
    "${NIRA_PROTO_GENERATED_DIR}/v1/hardware.pb.h"
    "${NIRA_PROTO_GENERATED_DIR}/v1/hardware.grpc.pb.h"
)

add_custom_command(
    OUTPUT ${NIRA_PROTO_SOURCES} ${NIRA_PROTO_HEADERS}
    COMMAND ${CMAKE_COMMAND} -E make_directory "${NIRA_PROTO_GENERATED_DIR}/v1"
    COMMAND ${NIRA_PROTOC_EXECUTABLE}
        --proto_path=${NIRA_PROTO_ROOT}
        --cpp_out=${NIRA_PROTO_GENERATED_DIR}
        v1/common.proto v1/ai.proto v1/settings.proto v1/hardware.proto
    COMMAND ${NIRA_PROTOC_EXECUTABLE}
        --proto_path=${NIRA_PROTO_ROOT}
        --grpc_out=${NIRA_PROTO_GENERATED_DIR}
        --plugin=protoc-gen-grpc=${NIRA_GRPC_CPP_PLUGIN_EXECUTABLE}
        v1/ai.proto v1/settings.proto v1/hardware.proto
    DEPENDS
        "${NIRA_PROTO_ROOT}/v1/common.proto"
        "${NIRA_PROTO_ROOT}/v1/ai.proto"
        "${NIRA_PROTO_ROOT}/v1/settings.proto"
        "${NIRA_PROTO_ROOT}/v1/hardware.proto"
    VERBATIM
)

add_library(nira-ai-proto STATIC ${NIRA_PROTO_SOURCES})
target_include_directories(nira-ai-proto PUBLIC "${NIRA_PROTO_GENERATED_DIR}")
target_link_libraries(nira-ai-proto PUBLIC protobuf::libprotobuf gRPC::grpc++)

add_subdirectory(desktop/compositor)
add_subdirectory(desktop/shell)
add_subdirectory(desktop/greeter)
add_subdirectory(desktop/settings)
add_subdirectory(apps/files)
add_subdirectory(apps/notepad)
