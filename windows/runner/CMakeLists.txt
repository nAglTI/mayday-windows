cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

get_filename_component(MAYDAY_RUNTIME_SOURCE_DIR
  "${CMAKE_SOURCE_DIR}/../build-win"
  REALPATH)
set(MAYDAY_RUNTIME_OUTPUT_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>/runtime")

add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

apply_standard_settings(${BINARY_NAME})

target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")
target_link_libraries(${BINARY_NAME} PRIVATE "shell32.lib")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Keep the custom runner manifest authoritative. Otherwise MSVC injects
# a default UAC fragment (`asInvoker`), which conflicts with our
# `requireAdministrator` setting in runner.exe.manifest.
if(MSVC)
  target_link_options(${BINARY_NAME} PRIVATE "/MANIFESTUAC:NO")
endif()

add_dependencies(${BINARY_NAME} flutter_assemble)

if(EXISTS "${MAYDAY_RUNTIME_SOURCE_DIR}")
  file(GLOB MAYDAY_RUNTIME_FILES "${MAYDAY_RUNTIME_SOURCE_DIR}/*")
  add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory "${MAYDAY_RUNTIME_OUTPUT_DIR}"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
      ${MAYDAY_RUNTIME_FILES}
      "${MAYDAY_RUNTIME_OUTPUT_DIR}"
    COMMENT "Copying network runtime files from build-win to output/runtime"
  )

  install(DIRECTORY "${MAYDAY_RUNTIME_SOURCE_DIR}/"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/runtime"
    COMPONENT Runtime)
endif()
