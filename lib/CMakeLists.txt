add_library(btlib INTERFACE
        include/bt/bt.hpp
)
target_include_directories(btlib INTERFACE include/)

add_library(bt::lib ALIAS btlib)
