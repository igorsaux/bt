set(SOURCE_FILES
        src/main.cpp
        src/socket_buffer.cpp
)

if (WIN32)
    list(APPEND SOURCE_FILES src/socket_win32.cpp)
elseif (UNIX)
    list(APPEND SOURCE_FILES src/socket_unix.cpp)
else ()
    message(FATAL_ERROR The OS is not supported)
endif ()

add_executable(bt
        ${SOURCE_FILES}
)
target_include_directories(bt PRIVATE src/)
target_link_libraries(bt
        PRIVATE bt::lib
)

if (WIN32)
    target_compile_definitions(bt PRIVATE BTCMD_WIN32)
endif ()

if (WIN32)
    find_library(ws2 NAMES Ws2_32 REQUIRED)

    target_link_libraries(bt
            PRIVATE Ws2_32
    )
endif ()
