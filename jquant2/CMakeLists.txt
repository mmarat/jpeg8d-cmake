cmake_minimum_required(VERSION 2.8.8)

if( MSVC )
	if( MSVC_VERSION EQUAL 1600 )
		message(STATUS "Broken Microsoft Visual Studio 10  C/C++ 16.00 ? Disabling optimization flags for jquant2.c")
		# bug in Visual Studio 10 C/C++ 16.00
		# default by cmake: /MD /O2 /Ob2 /D NDEBUG
		# should try to disable it only for jquant2.c
		set(CMAKE_C_FLAGS_RELEASE "/MD /D NDEBUG")
	endif()
endif()

# cmake 2.8.8 is needed here
add_library(jquant2 OBJECT ../jquant2.c)
