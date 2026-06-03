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

add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E remove -f
    "$<TARGET_FILE_DIR:${BINARY_NAME}>/mdhelper.exe"
    "$<TARGET_FILE_DIR:${BINARY_NAME}>/mdpipectl.exe"
    "$<TARGET_FILE_DIR:${BINARY_NAME}>/mdschelper.exe"
    "$<TARGET_FILE_DIR:${BINARY_NAME}>/mayday_vpnscan.exe"
    "$<TARGET_FILE_DIR:${BINARY_NAME}>/vpnclient.exe"
    "$<TARGET_FILE_DIR:${BINARY_NAME}>/vpnpipectl.exe"
    "$<TARGET_FILE_DIR:${BINARY_NAME}>/runtime/vpnclient.exe"
    "$<TARGET_FILE_DIR:${BINARY_NAME}>/runtime/vpnpipectl.exe"
    "$<TARGET_FILE_DIR:${BINARY_NAME}>/runtime/mdschelper.exe"
    "$<TARGET_FILE_DIR:${BINARY_NAME}>/runtime/mayday_vpnscan.exe"
  COMMENT "Removing obsolete runtime helpers from bundle"
)

if(EXISTS "${MAYDAY_RUNTIME_SOURCE_DIR}")
  file(GLOB MAYDAY_RUNTIME_FILES "${MAYDAY_RUNTIME_SOURCE_DIR}/*")

  set(MAYDAY_RUNTIME_CLIENT_SOURCE "")
  foreach(MAYDAY_RUNTIME_CLIENT_CANDIDATE mdhelper.exe vpnclient.exe)
    if(EXISTS "${MAYDAY_RUNTIME_SOURCE_DIR}/${MAYDAY_RUNTIME_CLIENT_CANDIDATE}")
      set(MAYDAY_RUNTIME_CLIENT_SOURCE
        "${MAYDAY_RUNTIME_SOURCE_DIR}/${MAYDAY_RUNTIME_CLIENT_CANDIDATE}")
      break()
    endif()
  endforeach()

  set(MAYDAY_RUNTIME_PIPE_HELPER_SOURCE "")
  foreach(MAYDAY_RUNTIME_PIPE_HELPER_CANDIDATE mdpipectl.exe vpnpipectl.exe)
    if(EXISTS "${MAYDAY_RUNTIME_SOURCE_DIR}/${MAYDAY_RUNTIME_PIPE_HELPER_CANDIDATE}")
      set(MAYDAY_RUNTIME_PIPE_HELPER_SOURCE
        "${MAYDAY_RUNTIME_SOURCE_DIR}/${MAYDAY_RUNTIME_PIPE_HELPER_CANDIDATE}")
      break()
    endif()
  endforeach()

  set(MAYDAY_RUNTIME_PASSTHROUGH_FILES "")
  foreach(MAYDAY_RUNTIME_FILE ${MAYDAY_RUNTIME_FILES})
    get_filename_component(MAYDAY_RUNTIME_FILE_NAME "${MAYDAY_RUNTIME_FILE}" NAME)
    string(TOLOWER "${MAYDAY_RUNTIME_FILE_NAME}" MAYDAY_RUNTIME_FILE_NAME_LOWER)
    if(NOT MAYDAY_RUNTIME_FILE_NAME_LOWER STREQUAL "mdhelper.exe"
        AND NOT MAYDAY_RUNTIME_FILE_NAME_LOWER STREQUAL "vpnclient.exe"
        AND NOT MAYDAY_RUNTIME_FILE_NAME_LOWER STREQUAL "mdpipectl.exe"
        AND NOT MAYDAY_RUNTIME_FILE_NAME_LOWER STREQUAL "vpnpipectl.exe"
        AND NOT MAYDAY_RUNTIME_FILE_NAME_LOWER STREQUAL "mdschelper.exe"
        AND NOT MAYDAY_RUNTIME_FILE_NAME_LOWER STREQUAL "mayday_vpnscan.exe")
      list(APPEND MAYDAY_RUNTIME_PASSTHROUGH_FILES "${MAYDAY_RUNTIME_FILE}")
    endif()
  endforeach()

  if(NOT MAYDAY_RUNTIME_CLIENT_SOURCE STREQUAL ""
      AND NOT MAYDAY_RUNTIME_PIPE_HELPER_SOURCE STREQUAL "")
    add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E make_directory "${MAYDAY_RUNTIME_OUTPUT_DIR}"
      COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${MAYDAY_RUNTIME_CLIENT_SOURCE}"
        "${MAYDAY_RUNTIME_OUTPUT_DIR}/mdhelper.exe"
      COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${MAYDAY_RUNTIME_PIPE_HELPER_SOURCE}"
        "${MAYDAY_RUNTIME_OUTPUT_DIR}/mdpipectl.exe"
      COMMENT "Copying Mayday runtime helpers to output/runtime"
    )

    install(FILES "${MAYDAY_RUNTIME_CLIENT_SOURCE}"
      DESTINATION "${CMAKE_INSTALL_PREFIX}/runtime"
      RENAME "mdhelper.exe"
      COMPONENT Runtime)
    install(FILES "${MAYDAY_RUNTIME_PIPE_HELPER_SOURCE}"
      DESTINATION "${CMAKE_INSTALL_PREFIX}/runtime"
      RENAME "mdpipectl.exe"
      COMPONENT Runtime)
  endif()

  if(MAYDAY_RUNTIME_PASSTHROUGH_FILES)
    add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E make_directory "${MAYDAY_RUNTIME_OUTPUT_DIR}"
      COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${MAYDAY_RUNTIME_PASSTHROUGH_FILES}
        "${MAYDAY_RUNTIME_OUTPUT_DIR}"
      COMMENT "Copying Mayday runtime support files to output/runtime"
    )

    install(FILES ${MAYDAY_RUNTIME_PASSTHROUGH_FILES}
      DESTINATION "${CMAKE_INSTALL_PREFIX}/runtime"
      COMPONENT Runtime)
  endif()
endif()
