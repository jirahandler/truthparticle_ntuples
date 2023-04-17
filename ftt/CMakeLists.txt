#
# Basic setup for dumping Tagging information
#

# Set the minimum required CMake version:
cmake_minimum_required( VERSION 3.11 FATAL_ERROR )

# Setup this project
project( Dumper VERSION 1.0 LANGUAGES CXX C )

# Bail out if no release is setup
if ( NOT DEFINED ENV{AtlasProject} )
  message(FATAL_ERROR "AtlasProject environment variable not set, can't figure out release")
endif()

# Figure out what release we're in (e.g. x.y.z)
set ( AtlasVersion $ENV{$ENV{AtlasProject}_VERSION} )

# Set up that release
find_package( $ENV{AtlasProject} ${AtlasVersion} REQUIRED )

# Set up CTest:
atlas_ctest_setup()

# Set up a work directory project:
atlas_project( Dumper 1.0 USE $ENV{AtlasProject} ${AtlasVersion} )

# Set up the runtime environment setup script(s):
lcg_generate_env( SH_FILE ${CMAKE_BINARY_DIR}/${ATLAS_PLATFORM}/env_setup.sh )
install( FILES ${CMAKE_BINARY_DIR}/${ATLAS_PLATFORM}/env_setup.sh
   DESTINATION . )

# Set up CPack:
atlas_cpack_setup() 
