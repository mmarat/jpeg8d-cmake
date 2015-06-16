cmake_minimum_required(VERSION 3.0.0)
set(CMAKE_BUILD_TYPE Release CACHE STRING
	"Choose the type of build: None Debug Release RelWithDebInfo MinSizeRel")
set(CMAKE_C_STANDARD 11) # supported: 90, 99, 11

project(jpeg VERSION 8.4 LANGUAGES C)
set(srcdir ${jpeg_SOURCE_DIR})
set(CMAKE_MACOSX_RPATH ON)
set(CMAKE_INSTALL_PREFIX "${CMAKE_BINARY_DIR}/Installation")

foreach(cfg Debug Release RelWithDebInfo MinSizeRel None)
	string(TOUPPER "_${cfg}" cfgo)
	if( "${cfg}" STREQUAL "Release" )
		set(odir "${CMAKE_BINARY_DIR}")
	elseif( "${cfg}" STREQUAL "None")
		set(odir "${CMAKE_BINARY_DIR}")
		set(cfgo "")
	else()
		set(odir "${CMAKE_BINARY_DIR}/${cfg}")
	endif()
	set(CMAKE_RUNTIME_OUTPUT_DIRECTORY${cfgo} "${odir}/bin")
	set(CMAKE_LIBRARY_OUTPUT_DIRECTORY${cfgo} "${odir}/lib")
	set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY${cfgo} "${odir}/lib")
endforeach()

#-----------------------------------------------------------------------------
# Include all the necessary files for macros
#-----------------------------------------------------------------------------
include (CheckFunctionExists)
include (CheckIncludeFile)
include (CheckIncludeFileCXX)
include (CheckIncludeFiles)
include (CheckLibraryExists)
include (CheckSymbolExists)
include (CheckTypeSize)
include (CheckVariableExists)
# include (CheckPrototypeDefinition) # not in 2.8.4
include (CheckCSourceCompiles)
include (CheckCSourceRuns)
include (CheckCCompilerFlag)

function(check_c flag result_var)
	set(CMAKE_REQUIRED_FLAGS ${flag}) # to test linking as well
	check_c_compiler_flag("" ${result_var})
endfunction()

# compiler flags should be set before any HAVE_ checks
if( CMAKE_COMPILER_IS_GNUCC )
	# check_c_compiler_flag(-Wall  gcc_Wall)
	check_c(-Wall  gcc_Wall)
	if( gcc_Wall )
		set(CWARNFLAGS "${CWARNFLAGS} -Wall")
	endif()
	check_c("${CWARNFLAGS} -Wno-obsolete" gcc_Wno_obsolete)
	if( gcc_Wno_obsolete )
		set(CWARNFLAGS "${CWARNFLAGS} -Wno-obsolete")
	endif()
	# linker flags
	check_c("-Wl,--version-script=${CMAKE_CURRENT_SOURCE_DIR}/empty_test.map"
		gcc_Wl_version_script)
	check_c("-Wl,-no-undefined" gcc_no_undefined)
elseif( MSVC )
	message(STATUS "Microsoft C/C++.  OPTIMIZATIONS DISABLED FOR jquant2.c !!!")
	message(STATUS "Workaround for MSVC optimization bug is implemented with pragma")
	message(STATUS "Optimiations disabled for MSVC versions <= 30.0")
	if( ${MSVC_VERSION} GREATER 3000 )
		message(FATAL_ERROR "MSVC version ${MSVC_VERSION} is not supported, some tests might fail, see jquant2.c")
	endif()
	# so at the moment using #pragma optimize in jquant2.c
	add_definitions("-D_CRT_SECURE_NO_WARNINGS") # disable non-secure API warnings
else()
	# per cmake 2.8.8 documentation the following is not portable
	message(STATUS "C Compiler guessed by cmake: ${CMAKE_C_COMPILER_ID}")
	if( CMAKE_C_COMPILER_ID MATCHES "Intel" )
		check_c(-Wall intel_Wall)
		if( intel_Wall )
			set(CWARNFLAGS "${CWARNFLAGS} -Wall")
		endif()
	elseif( CMAKE_C_COMPILER_ID MATCHES "Clang" )
		check_c(-Wall clang_Wall)
		if( clang_Wall )
			set(CWARNFLAGS "${CWARNFLAGS} -Wall")
		endif()
	else()
		message(STATUS "Not supported compiler. No extra flags set.")
	endif()
endif()

set( CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${CWARNFLAGS}" )

link_directories(${jpeg_BINARY_DIR})

check_include_file(stddef.h HAVE_STDDEF_H)
check_include_file(stdlib.h HAVE_STDLIB_H)
check_include_file(locale.h HAVE_LOCALE_H)
check_include_file(string.h HAVE_STRING_H)
check_include_file(strings.h HAVE_STRINGS_H)
if( HAVE_STRINGS_H AND NOT HAVE_STRING_H )
	set(NEED_BSD_STRINGS 1)
endif()
check_type_size(size_t SIZE_T)
if( NOT HAVE_SIZE_T )
	message(WARNING "Type size_t is not defined in any of the usual places.
		Try putting 'typedef unsigned int size_t;' in jconfig.h."
	)
endif()
check_type_size("unsigned char" UNSIGNED_CHAR)
check_type_size("unsigned short" UNSIGNED_SHORT)
check_type_size(char CHAR)
if( NOT HAVE_CHAR )
	message(ERROR "Major BUG: no 'char' in C.")
endif()
if( NOT (CHAR EQUAL 1) )
	message(WARNING  "Hmm, it seems char is not eight bits wide on your machine. "
		"I fear the JPEG software will not work at all.")
endif()

check_symbol_exists(tmpfile stdio.h HAVE_TMPFILE_SYMBOL)
check_function_exists(tmpfile HAVE_TMPFILE_FUNC)
# check_prototype_definition(tmpfile "FILE *tmpfile()" NULL stdio.h HAVE_TMPFILE_DEFINITION)

check_symbol_exists(mktemp stdlib.h HAVE_MKTEMP_SYMBOL)
check_function_exists(mktemp HAVE_MKTEMP_FUNC)
# check_prototype_definition(mktemp "char* mktemp(char* filename)" NULL stdlib.h HAVE_MKTEMP_DEFINITION)

if( NOT ( HAVE_MKTEMP_SYMBOL AND HAVE_MKTEMP_FUNC AND HAVE_MKTEMP_DEFINITION) )
	set(NO_MKTEMP 1)
endif()

set(MEMORYMGR jmemnobs)

# See if compiler supports prototypes.
check_c_source_compiles(
"int testfunction (int arg1, int * arg2); /* check prototypes */
struct methods_struct { /* check method-pointer declarations */
  int (*error_exit) (char *msgtext);
  int (*trace_message) (char *msgtext);
  int (*another_method) (void);
};
int testfunction (int arg1, int * arg2) /* check definitions */
{ return arg2[arg1]; }
int test2function (void) /* check void arg list */
{ return 0; }
int main(int argc, char **argv) {return 0;}
"
HAVE_PROTOTYPES
)
if( NOT HAVE_PROTOTYPES )
	message(WARNING "Your compiler does not seem to know about function prototypes.
		Perhaps it needs a special switch to enable ANSI C mode.")
endif()

# checking if C compiler has void type
check_c_source_compiles(
"/* Caution: a C++ compiler will insist on valid prototypes */
typedef void * void_ptr; /* check void * */
#ifdef HAVE_PROTOTYPES /* check ptr to function returning void */
typedef void (*void_func) (int a, int b);
#else
typedef void (*void_func) ();
#endif

#ifdef HAVE_PROTOTYPES /* check void function result */
void test3function (void_ptr arg1, void_func arg2)
#else
void test3function (arg1, arg2)
	void_ptr arg1;
	void_func arg2;
#endif
{
  char * locptr = (char *) arg1; /* check casting to and from void * */
  arg1 = (void *) locptr;
  (*arg2) (1, 2);  /* check call of fcn returning void */
}
int main() { return 0; }
"
HAVE_VOID
)
if( NOT HAVE_VOID )
	message(WARNING "Defining 'void' as 'char' because the compiler is archaic")
	set(VOID char)
endif()

# Check for non-broken inline under various spellings
check_c_source_compiles(
	"inline int foo() {return 0;} int bar() {return foo();} int main() {return bar();}"
	HAVE_INLINE
)
check_c_source_compiles(
	"__inline__ int foo() {return 0;} int bar() {return foo();} int main() {return bar();}"
	HAVE___INLINE__
)
check_c_source_compiles(
	"__inline int foo() {return 0;} int bar() {return foo();} int main() {return bar();}"
	HAVE___INLINE
)
if( HAVE_INLINE )
	set(INLINE inline)
elseif(HAVE___INLINE__)
	set(INLINE __inline__)
elseif(HAVE___INLINE)
	set(INLINE __inline)
endif()

# checking fo C has const
check_c_source_compiles(
	"const char *ch; const int x=17; int func(const int *i) {return x + (*i);} int main() {return func(&x);}" 
	HAVE_C_CONST
)
if( NOT HAVE_C_CONST )
	message(WARNING "C compiler does not have 'const'. That is an archaic compiler, UPGRADE!")
	set(CONST )
endif()

# We cannot check for bogus warnings, but at least we can check for errors
check_c_source_compiles(
	"typedef struct undefined_structure * undef_struct_ptr; int main(){return 0;}"
	INCOMPLETE_TYPES_NOT_BROKEN
)
if( NOT INCOMPLETE_TYPES_NOT_BROKEN )
	set(INCOMPLETE_TYPES_BROKEN 1)
	message(WARNING "Compiler does not support pointers to unspecified structures.")
endif()

# Test whether global names are unique to at least 15 chars
check_c_source_compiles(
"int possibly_duplicate_function () { return 0; }
int possibly_dupli_function () { return 1; }
int main() {return 0;}
"
HAVE_LONG_EXTERNAL_NAMES
)
if( NOT HAVE_LONG_EXTERNAL_NAMES )
	message(WARNING "C compiler is archaic, it does not undestand long function names")
	set(NEED_SHORT_EXTERNAL_NAMES 1)
endif()

check_include_file(limits.h HAVE_LIMITS_H)
if(NOT HAVE_LIMITS_H)
	message(FATAL_ERROR "limits.h is missing")
endif()
# checking to see if char is signed
check_c_source_compiles(
"#include <limits.h>
#if CHAR_MIN >= 0
#  error \"char is unsigned\"
#endif
int main() {return 0;}
"
CHAR_IS_SIGNED
)
if( CHAR_IS_SIGNED )
	message(STATUS "Assuming that char is signed on target machine. "
	    "If it is unsigned, this will be a little bit inefficient.")
else()
	message(WARNING "Assuming that char is UNsigned on target machine.")
	set(CHAR_IS_UNSIGNED 1)
endif()

# checking to see if right shift is signed
check_c_source_compiles(
"#define NTST1 -0x7F7E80CL
#define NVAL -0x7F7E80B1L
#if  ((NVAL)>>4) != NTST1
#error \"right shift is unsigned\"
#endif
int main() {return 0;}
"
RIGHT_SHIFT_IS_SIGNED
)
if( RIGHT_SHIFT_IS_SIGNED )
	message(STATUS "Assuming that right shift is signed on target machine.")
else()
	set(RIGHT_SHIFT_IS_UNSIGNED 1)
	message(WARNING "Broken compiler shifts signed values as an unsigned shift.")
endif()

# superficial check to see if fopen accepts b spec
# assuming that it does, it is not used by the library anyway
check_c_source_compiles(
"
#include <stdio.h>
int main() {
  if (fopen(\"conftestdata\", \"wb\") != NULL)
    exit(0);
  exit(1);
}
"
HAVE_B_MODE_IN_FOPEN
)
if( NOT HAVE_B_MODE_IN_FOPEN )
	set(DONT_USE_B_MODE 1)
	message(WARNING "Do not have 'b' mode in fopen")
endif()


########### next target ###############
## Sources to build library
set(LIBSOURCES
	src/jaricom.c src/jcapimin.c src/jcapistd.c src/jcarith.c src/jccoefct.c src/jccolor.c
	src/jcdctmgr.c src/jchuff.c src/jcinit.c src/jcmainct.c src/jcmarker.c src/jcmaster.c
	src/jcomapi.c src/jcparam.c src/jcprepct.c src/jcsample.c src/jctrans.c src/jdapimin.c
	src/jdapistd.c src/jdarith.c src/jdatadst.c src/jdatasrc.c src/jdcoefct.c src/jdcolor.c
	src/jddctmgr.c src/jdhuff.c src/jdinput.c src/jdmainct.c src/jdmarker.c src/jdmaster.c
	src/jdmerge.c src/jdpostct.c src/jdsample.c src/jdtrans.c src/jerror.c src/jfdctflt.c
	src/jfdctfst.c src/jfdctint.c src/jidctflt.c src/jidctfst.c src/jidctint.c src/jquant1.c
	src/jutils.c src/jmemmgr.c src/${MEMORYMGR}.c
)

# System dependent sources
set(SYSDEPSOURCES
	src/jmemansi.c src/jmemname.c src/jmemnobs.c src/jmemdos.c src/jmemmac.c
)

set(jconfig_h "${CMAKE_BINARY_DIR}/include/jconfig.h")
configure_file(jconfig-cmake.cfg ${jconfig_h})

# Headers which are installed to support the library
set(INSTINCLUDES  src/jerror.h src/jmorecfg.h src/jpeglib.h ${jconfig_h})
set_source_files_properties(${jconfig_h} PROPERTIES GENERATED TRUE)
source_group(Interface FILES ${INSTINCLUDES})

# Headers which are not installed
set(OTHERINCLUDES tools/cderror.h tools/cdjpeg.h src/jdct.h src/jinclude.h
	src/jmemsys.h src/jpegint.h
	src/jversion.h tools/transupp.h
)

# Manual pages (Automake uses 'MANS' for itself)
set(DISTMANS man/cjpeg.1 man/djpeg.1 man/jpegtran.1 man/rdjpgcom.1 man/wrjpgcom.1)

# Other documentation files
set(DOCS README "install.txt" usage.txt wizard.txt tools/example.c libjpeg.txt
	structure.txt coderules.txt filelist.txt change.log)

# Miscellaneous support files
set(OTHERFILES jconfig.txt libjpeg.map)

# Test support files
set(TESTFILES testorig.jpg testimg.ppm testimg.bmp testimg.jpg testprog.jpg
	testimgp.jpg)

set(jpeg_LIB_SRCS ${LIBSOURCES} src/jquant2.c ${INSTINCLUDES} ${OTHERINCLUDES})
add_library(jpeg SHARED ${jpeg_LIB_SRCS})

set_target_properties(jpeg PROPERTIES VERSION 8.4.0 SOVERSION 8
	PUBLIC_HEADER "${INSTINCLUDES}"
	DEFINE_SYMBOL "JPEG_DLL_EXPORTS"
	FOLDER Libraries
)
target_include_directories(jpeg PUBLIC
	$<BUILD_INTERFACE:${CMAKE_BINARY_DIR}/include>
	$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src>
	"$<INSTALL_INTERFACE:include>"
)

if(gcc_Wl_version_script)
	# TODO: this does not seem necessary as libjpeg.map is basically empty
	set_target_properties(jpeg PROPERTIES LINK_FLAGS
		"-Wl,--version-script=${srcdir}/libjpeg.map")
endif()
if(gcc_no_undefined)
	set_target_properties(jpeg PROPERTIES LINK_FLAGS "-Wl,-no-undefined")
endif()


########### Executables ###############

set(cjpeg_SRCS
    tools/cjpeg.c
    tools/rdppm.c
    tools/rdgif.c
    tools/rdtarga.c
    tools/rdrle.c
    tools/rdbmp.c
    tools/rdswitch.c
    tools/cdjpeg.c)
add_executable(cjpeg ${cjpeg_SRCS})
target_link_libraries(cjpeg jpeg)

set(djpeg_SRCS
    tools/djpeg.c
    tools/wrppm.c
    tools/wrgif.c
    tools/wrtarga.c
    tools/wrrle.c
    tools/wrbmp.c
    tools/rdcolmap.c
    tools/cdjpeg.c)
add_executable(djpeg ${djpeg_SRCS})
target_link_libraries(djpeg jpeg)

set(jpegtran_SRCS
    tools/jpegtran.c
    tools/rdswitch.c
    tools/cdjpeg.c
    tools/transupp.c)
add_executable(jpegtran ${jpegtran_SRCS})
target_link_libraries(jpegtran jpeg)

add_executable(rdjpgcom tools/rdjpgcom.c)
target_include_directories(rdjpgcom PRIVATE src "${CMAKE_BINARY_DIR}/include")


add_executable(wrjpgcom tools/wrjpgcom.c)
target_include_directories(wrjpgcom PRIVATE src "${CMAKE_BINARY_DIR}/include")

set_target_properties(cjpeg djpeg jpegtran rdjpgcom wrjpgcom  PROPERTIES FOLDER
	Executables/jpeg)

########## setup configuration headers ###########

include(CMakePackageConfigHelpers)
write_basic_package_version_file(
	"${CMAKE_BINARY_DIR}/lib/cmake/jpeg-config-version.cmake"
	COMPATIBILITY AnyNewerVersion
)

set(INCLUDE_INSTALL_DIR "include")

configure_package_config_file(jpeg-config.cmake.in
	"${CMAKE_BINARY_DIR}/lib/cmake/jpeg-config.cmake"
	INSTALL_DESTINATION lib/cmake
	PATH_VARS INCLUDE_INSTALL_DIR
)
export(TARGETS jpeg FILE ${CMAKE_BINARY_DIR}/lib/cmake/jpeg-targets.cmake )

########### install files ###############

install(TARGETS jpeg cjpeg djpeg jpegtran rdjpgcom wrjpgcom
	EXPORT jpeg-targets
	LIBRARY DESTINATION lib COMPONENT Runtime
	ARCHIVE DESTINATION lib COMPONENT Development
	RUNTIME DESTINATION bin COMPONENT Runtime
	PUBLIC_HEADER DESTINATION include COMPONENT Development
)
install(EXPORT jpeg-targets FILE jpeg-targets.cmake DESTINATION lib/cmake)
install(FILES "${CMAKE_BINARY_DIR}/lib/cmake/jpeg-config-version.cmake"
	"${CMAKE_BINARY_DIR}/lib/cmake/jpeg-config.cmake"
	DESTINATION lib/cmake)

################### TESTS
enable_testing()

add_test(NAME djpeg-test1 COMMAND
	$<TARGET_FILE:djpeg> -dct int -ppm -outfile testout.ppm  ${srcdir}/tests/testorig.jpg)
add_test(djpeg-diff-test1 ${CMAKE_COMMAND} -E compare_files ${srcdir}/tests/testimg.ppm testout.ppm)
set_tests_properties(djpeg-diff-test1 PROPERTIES DEPENDS djpeg-test1)

add_test(NAME djpeg-test2 COMMAND
	$<TARGET_FILE:djpeg> -dct int -bmp -colors 256 -outfile testout.bmp  ${srcdir}/tests/testorig.jpg)
add_test(djpeg-diff-test2
	${CMAKE_COMMAND} -E compare_files ${srcdir}/tests/testimg.bmp testout.bmp)
set_tests_properties(djpeg-diff-test2 PROPERTIES DEPENDS djpeg-test2)

add_test(NAME cjpeg-test1
	COMMAND $<TARGET_FILE:cjpeg> -dct int -outfile testout.jpg  ${srcdir}/tests/testimg.ppm)
add_test(cjpeg-diff-test1
	${CMAKE_COMMAND} -E compare_files  ${srcdir}/tests/testimg.jpg testout.jpg)
set_tests_properties(cjpeg-diff-test1 PROPERTIES DEPENDS cjpeg-test1)

add_test(NAME djpeg-test3 COMMAND
	$<TARGET_FILE:djpeg> -dct int -ppm -outfile testoutp.ppm ${srcdir}/tests/testprog.jpg)
add_test(djpeg-diff-test3
	${CMAKE_COMMAND} -E compare_files ${srcdir}/tests/testimg.ppm testoutp.ppm)
set_tests_properties(djpeg-diff-test3 PROPERTIES DEPENDS djpeg-test3)

add_test(NAME cjpeg-test2 COMMAND
	$<TARGET_FILE:cjpeg> -dct int -progressive -opt -outfile testoutp.jpg ${srcdir}/tests/testimg.ppm)
add_test(cjpeg-diff-test2
	${CMAKE_COMMAND} -E compare_files ${srcdir}/tests/testimgp.jpg testoutp.jpg)
set_tests_properties(cjpeg-diff-test2 PROPERTIES DEPENDS cjpeg-test2)

add_test(NAME jpegtran-test1 COMMAND
	$<TARGET_FILE:jpegtran> -outfile testoutt.jpg ${srcdir}/tests/testprog.jpg)
add_test(jpegtran-diff-test1
	${CMAKE_COMMAND} -E compare_files ${srcdir}/tests/testorig.jpg testoutt.jpg)
set_tests_properties(jpegtran-diff-test1 PROPERTIES DEPENDS jpegtran-test1)

set_tests_properties(jpegtran-diff-test1 jpegtran-test1 cjpeg-diff-test2
	cjpeg-test2 djpeg-diff-test3  djpeg-test3 cjpeg-diff-test1  cjpeg-test1
	djpeg-diff-test2 djpeg-test2 djpeg-diff-test1  djpeg-test1
	PROPERTIES COST 15 LABELS "15_sec;jpeg"
)

include(InstallRequiredSystemLibraries)
include(CPack)

# vim:noet ts=4 sw=4
