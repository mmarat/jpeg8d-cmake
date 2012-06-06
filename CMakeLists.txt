cmake_minimum_required(VERSION 2.8)
project(jpeg C)
set(srcdir ${jpeg_SOURCE_DIR})

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
include (CheckPrototypeDefinition)
include (CheckCSourceCompiles)
include (CheckCSourceRuns)
include (CheckCCompilerFlag)

include_directories(${CMAKE_CURRENT_BINARY_DIR})

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

check_symbol_exists(tmpfile stdio.h HAVE_TMPFILE_SYMBOL)
check_function_exists(tmpfile HAVE_TMPFILE_FUNC)
check_prototype_definition(tmpfile "FILE *tmpfile()" NULL stdio.h HAVE_TMPFILE_DEFINITION)

check_symbol_exists(mktemp stdlib.h HAVE_MKTEMP_SYMBOL)
check_function_exists(mktemp HAVE_MKTEMP_FUNC)
check_prototype_definition(mktemp "char* mktemp(char* filename)" NULL stdlib.h HAVE_MKTEMP_DEFINITION)

if( NOT ( HAVE_MKTEMP_SYMBOL AND HAVE_MKTEMP_FUNC AND HAVE_MKTEMP_DEFINITION) )
	set(NO_MKTEMP 1)
endif()

set(MEMORYMGR jmemnobs)

# See if compiler supports prototypes.
check_c_source_compiles(
"int testfunction (int arg1, int * arg2); /* check prototypes */
struct methods_struct {		/* check method-pointer declarations */
  int (*error_exit) (char *msgtext);
  int (*trace_message) (char *msgtext);
  int (*another_method) (void);
};
int testfunction (int arg1, int * arg2) /* check definitions */
{ return arg2[arg1]; }
int test2function (void)	/* check void arg list */
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
typedef void * void_ptr;	/* check void * */
#ifdef HAVE_PROTOTYPES		/* check ptr to function returning void */
typedef void (*void_func) (int a, int b);
#else
typedef void (*void_func) ();
#endif

#ifdef HAVE_PROTOTYPES		/* check void function result */
void test3function (void_ptr arg1, void_func arg2)
#else
void test3function (arg1, arg2)
     void_ptr arg1;
     void_func arg2;
#endif
{
  char * locptr = (char *) arg1; /* check casting to and from void * */
  arg1 = (void *) locptr;
  (*arg2) (1, 2);		/* check call of fcn returning void */
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

# checking to see if char is signed
check_c_source_runs(
"
int is_char_signed (int arg)
{
  if (arg == 189) {		/* expected result for unsigned char */
    return 0;			/* type char is unsigned */
  }
  else if (arg != -67) {	/* expected result for signed char */
    ;
    /* Hmm, it seems char is not eight bits wide on your machine */
    /* I fear the JPEG software will not work at all. */
  }
  return 1;			/* assume char is signed otherwise */
}
char signed_char_check = (char) (-67);
int main() {
  exit(is_char_signed((int) signed_char_check));
}
"
CHAR_IS_UNSIGNED
)
if( NOT CHAR_IS_UNSIGNED )
	message(WARNING "Assuming that char is signed on target machine.
	    If it is unsigned, this will be a little bit inefficient.")
endif()

# checking to see if right shift is signed
check_c_source_runs(
"
int is_shifting_signed (long arg)
/* See whether right-shift on a long is signed or not. */
{
  long res = arg >> 4;

  if (res == -0x7F7E80CL) {	/* expected result for signed shift */
    return 1;			/* right shift is signed */
  }
  /* see if unsigned-shift hack will fix it. */
  /* we can't just test exact value since it depends on width of long... */
  res |= (~0L) << (32-4);
  if (res == -0x7F7E80CL) {	/* expected result now? */
    return 0;			/* right shift is unsigned */
  }
  ;
  /* Right shift isn't acting as I expect it to. */
  /* I fear the JPEG software will not work at all. */
  return 0;			/* try it with unsigned anyway */
}
int main() {
  exit(is_shifting_signed(-0x7F7E80B1L));
}
"
RIGHT_SHIFT_IS_UNSIGNED
)
if( RIGHT_SHIFT_IS_UNSIGNED )
	message(WARNING "Broken compiler shifts signed values as an unsigned shift.")
else()
	message(STATUS "Assuming that right shift is signed on target machine.")
endif()

# checking to see if fopen accepts b spec
check_c_source_runs(
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
endif()



configure_file(jconfig-cmake.cfg jconfig.h)
message(STATUS "sizeof( void* ) == ${CMAKE_SIZEOF_VOID_P}")
message(STATUS "BUILD TYPE: ${CMAKE_BUILD_TYPE}")

if( CMAKE_COMPILER_IS_GNUCC )
	check_c_compiler_flag(-Wall  gcc_Wall)
	if( gcc_Wall )
		set(CWARNFLAGS ${CWARNFLAGS} -Wall)
	endif()
	# jcmainct.c fails check_c_compiler_flag("${CWARNFLAGS} -Werror" gcc_Werror)
	# if( gcc_Werror )
	#	set(CWARNFLAGS "${CWARNFLAGS} -Werror")
	#endif()
	check_c_compiler_flag("${CWARNFLAGS} -Wno-obsolete" gcc_Wno_obsolete)
	if( gcc_Wno_obsolete )
		set(CWARNFLAGS "${CWARNFLAGS} -Wno-obsolete")
	endif()
	# TODO: need to create temporary empty conftest.map
	# check_c_compiler_flag("-Wl,--version-script=conftest.map" gcc_Wl_version_script)
	check_c_compiler_flag("-Wl,--version-script" gcc_Wl_version_script)

	# linker flag  for Clang and GCC
	check_c_compiler_flag("-no-undefined" gcc_no_undefined)
else()
	message(STATUS "not GCC")
endif()

set( CMAKE_C_FLAGS ${CMAKE_C_FLAGS} ${CWARNFLAGS} )
message(STATUS "C Flags: ${CMAKE_C_FLAGS}")
message(STATUS "RELEASE C Flags: ${CMAKE_C_FLAGS_RELEASE}")

########### next target ###############
## Sources to build library
set(LIBSOURCES
        jaricom.c jcapimin.c jcapistd.c jcarith.c jccoefct.c jccolor.c
        jcdctmgr.c jchuff.c jcinit.c jcmainct.c jcmarker.c jcmaster.c
        jcomapi.c jcparam.c jcprepct.c jcsample.c jctrans.c jdapimin.c
        jdapistd.c jdarith.c jdatadst.c jdatasrc.c jdcoefct.c jdcolor.c
        jddctmgr.c jdhuff.c jdinput.c jdmainct.c jdmarker.c jdmaster.c
        jdmerge.c jdpostct.c jdsample.c jdtrans.c jerror.c jfdctflt.c
        jfdctfst.c jfdctint.c jidctflt.c jidctfst.c jidctint.c jquant1.c
        jquant2.c jutils.c jmemmgr.c ${MEMORYMGR}.c
)

# System dependent sources
set(SYSDEPSOURCES
        jmemansi.c jmemname.c jmemnobs.c jmemdos.c jmemmac.c
)

# Headers which are installed to support the library
set(INSTINCLUDES  jerror.h jmorecfg.h jpeglib.h)

# Headers which are not installed
set(OTHERINCLUDES cderror.h cdjpeg.h jdct.h jinclude.h jmemsys.h jpegint.h 
        jversion.h transupp.h
)

# Manual pages (Automake uses 'MANS' for itself)
set(DISTMANS cjpeg.1 djpeg.1 jpegtran.1 rdjpgcom.1 wrjpgcom.1)

# Other documentation files
set(DOCS README install.txt usage.txt wizard.txt example.c libjpeg.txt
        structure.txt coderules.txt filelist.txt change.log)

# Makefiles for various systems
set(MKFILES configure Makefile.in makefile.ansi makefile.unix makefile.bcc
        makefile.mc6 makefile.dj makefile.wat makefile.vc makejdsw.vc6
        makeadsw.vc6 makejdep.vc6 makejdsp.vc6 makejmak.vc6 makecdep.vc6
        makecdsp.vc6 makecmak.vc6 makeddep.vc6 makeddsp.vc6 makedmak.vc6
        maketdep.vc6 maketdsp.vc6 maketmak.vc6 makerdep.vc6 makerdsp.vc6
        makermak.vc6 makewdep.vc6 makewdsp.vc6 makewmak.vc6 makejsln.v10
        makeasln.v10 makejvcx.v10 makejfil.v10 makecvcx.v10 makecfil.v10
        makedvcx.v10 makedfil.v10 maketvcx.v10 maketfil.v10 makervcx.v10
        makerfil.v10 makewvcx.v10 makewfil.v10 makeproj.mac makcjpeg.st
        makdjpeg.st makljpeg.st maktjpeg.st makefile.manx makefile.sas
        makefile.mms makefile.vms makvms.opt
)

# Configuration files
set(CONFIGFILES jconfig.cfg jconfig.bcc jconfig.mc6 jconfig.dj jconfig.wat
        jconfig.vc jconfig.mac jconfig.st jconfig.manx jconfig.sas
        jconfig.vms
)

# Support scripts for configure
set(CONFIGUREFILES config.guess config.sub install-sh ltmain.sh depcomp missing)

# Miscellaneous support files
set(OTHERFILES jconfig.txt ckconfig.c ansi2knr.c ansi2knr.1 jmemdosa.asm
        libjpeg.map)

# Test support files
set(TESTFILES testorig.jpg testimg.ppm testimg.bmp testimg.jpg testprog.jpg
        testimgp.jpg)


set(jpeg_LIB_SRCS ${LIBSOURCES})

add_library(jpeg SHARED ${jpeg_LIB_SRCS})
set_target_properties(jpeg PROPERTIES VERSION 8.4.0 SOVERSION 8)
if(gcc_Wl_version_script)
	# TODO: this does not seem necessary as libjpeg.map is basically empty
	set_target_properties(jpeg PROPERTIES LINK_FLAGS "-Wl,--version-script=${srcdir}/libjpeg.map")
endif()
if(gcc_no_undefined)
	set_target_properties(jpeg PROPERTIES LINK_FLAGS "-no-undefined")
endif()


########### next target ###############

set(cjpeg_SRCS
    cjpeg.c
    rdppm.c
    rdgif.c
    rdtarga.c
    rdrle.c
    rdbmp.c
    rdswitch.c
    cdjpeg.c)

add_executable(cjpeg ${cjpeg_SRCS})

target_link_libraries(cjpeg jpeg)



########### next target ###############

set(djpeg_SRCS
    djpeg.c
    wrppm.c
    wrgif.c
    wrtarga.c
    wrrle.c
    wrbmp.c
    rdcolmap.c
    cdjpeg.c)

add_executable(djpeg ${djpeg_SRCS})

target_link_libraries(djpeg jpeg)



########### next target ###############

set(jpegtran_SRCS
    jpegtran.c
    rdswitch.c
    cdjpeg.c
    transupp.c)

add_executable(jpegtran ${jpegtran_SRCS})

target_link_libraries(jpegtran jpeg)



########### next target ###############

set(rdjpgcom_SRCS rdjpgcom.c)

add_executable(rdjpgcom ${rdjpgcom_SRCS})

target_link_libraries(rdjpgcom )



########### next target ###############

set(wrjpgcom_SRCS wrjpgcom.c)

add_executable(wrjpgcom ${wrjpgcom_SRCS})

target_link_libraries(wrjpgcom )



########### install files ###############

install(TARGETS jpeg cjpeg djpeg jpegtran rdjpgcom wrjpgcom 
  LIBRARY DESTINATION lib
  RUNTIME DESTINATION bin)

install(FILES  ${INSTINCLUDES} DESTINATION include)

include(InstallRequiredSystemLibraries)
include(CPack)


################### TESTS
enable_testing()

add_test(djpeg-test1 djpeg -dct int -ppm -outfile testout.ppm  ${srcdir}/testorig.jpg)
add_test(djpeg-diff-test1 ${CMAKE_COMMAND} -E compare_files ${srcdir}/testimg.ppm testout.ppm)
set_tests_properties(djpeg-diff-test1 PROPERTIES DEPENDS djpeg-test1)

add_test(djpeg-test2 djpeg -dct int -bmp -colors 256 -outfile testout.bmp  ${srcdir}/testorig.jpg)
add_test(djpeg-diff-test2 ${CMAKE_COMMAND} -E compare_files ${srcdir}/testimg.bmp testout.bmp)
set_tests_properties(djpeg-diff-test2 PROPERTIES DEPENDS djpeg-test2)

add_test(cjpeg-test1 cjpeg -dct int -outfile testout.jpg  ${srcdir}/testimg.ppm)
add_test(cjpeg-diff-test1 ${CMAKE_COMMAND} -E compare_files  ${srcdir}/testimg.jpg testout.jpg)
set_tests_properties(cjpeg-diff-test1 PROPERTIES DEPENDS cjpeg-test1)

add_test(djpeg-test3 djpeg -dct int -ppm -outfile testoutp.ppm ${srcdir}/testprog.jpg)
add_test(djpeg-diff-test3 ${CMAKE_COMMAND} -E compare_files ${srcdir}/testimg.ppm testoutp.ppm)
set_tests_properties(djpeg-diff-test3 PROPERTIES DEPENDS djpeg-test3)

add_test(cjpeg-test2 cjpeg -dct int -progressive -opt -outfile testoutp.jpg ${srcdir}/testimg.ppm)
add_test(cjpeg-diff-test2 ${CMAKE_COMMAND} -E compare_files ${srcdir}/testimgp.jpg testoutp.jpg)
set_tests_properties(cjpeg-diff-test2 PROPERTIES DEPENDS cjpeg-test2)

add_test(jpegtran-test1 jpegtran -outfile testoutt.jpg ${srcdir}/testprog.jpg)
add_test(jpegtran-diff-test1 ${CMAKE_COMMAND} -E compare_files ${srcdir}/testorig.jpg testoutt.jpg)
set_tests_properties(jpegtran-diff-test1 PROPERTIES DEPENDS jpegtran-test1)

