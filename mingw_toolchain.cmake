#  -DCMAKE_TOOLCHAIN_FILE=path/to/this/file
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR i386)

# set(CMAKE_SYSROOT /usr/local/gcc-4.8.1-for-linux64)

set(CMAKE_STAGING_PREFIX /tmp/stage_mingw32)

# set(tools "/opt/local/gcc-4.8.0-qt-4.8.4-for-mingw32/win32-gcc/i586-mingw32/bin/")
set(tools "/opt/local/gcc-4.8.0-qt-4.8.4-for-mingw32/win32-gcc/bin/i586-mingw32-")
set(CMAKE_C_COMPILER ${tools}gcc)
set(CMAKE_CXX_COMPILER ${tools}g++)

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
