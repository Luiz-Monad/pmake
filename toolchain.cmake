message(STATUS "PMake Toolchain")

mark_as_advanced(CMAKE_TOOLCHAIN_FILE)

if(PMAKE_TOOLCHAIN)
    return()
endif()

include($ENV{VCPKG_OVERLAY_TRIPLETS}/${VCPKG_TARGET_TRIPLET}.cmake)

if(PMAKE_CHAINLOAD_TOOLCHAIN_FILE)
    include("${PMAKE_CHAINLOAD_TOOLCHAIN_FILE}")
endif()

set(PMAKE_TOOLCHAIN ON)
