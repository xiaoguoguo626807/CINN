# Copyright (c) 2017 PaddlePaddle Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

IF(NOT ${WITH_MKLDNN})
  return()
ENDIF(NOT ${WITH_MKLDNN})

INCLUDE(ExternalProject)

SET(MKLDNN_PROJECT        "extern_mkldnn")
SET(MKLDNN_SOURCES_DIR    ${THIRD_PARTY_PATH}/mkldnn)
SET(MKLDNN_INSTALL_DIR    ${THIRD_PARTY_PATH}/install/mkldnn)
SET(MKLDNN_INC_DIR        "${MKLDNN_INSTALL_DIR}/include" CACHE PATH "mkldnn include directory." FORCE)

IF(APPLE)
    MESSAGE(WARNING
        "Mac is not supported with MKLDNN in CINN yet."
        "Force WITH_MKLDNN=OFF")
    SET(WITH_MKLDNN OFF CACHE STRING "Disable MKLDNN in MacOS" FORCE)
    return()
ENDIF()

# Introduce variables:
# * CMAKE_INSTALL_LIBDIR
INCLUDE(GNUInstallDirs)
SET(LIBDIR "lib")
if(CMAKE_INSTALL_LIBDIR MATCHES ".*lib64$")
  SET(LIBDIR "lib64")
endif()

MESSAGE(STATUS "Set ${MKLDNN_INSTALL_DIR}/l${LIBDIR} to runtime path")
SET(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)
SET(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_RPATH}" "${MKLDNN_INSTALL_DIR}/${LIBDIR}")

INCLUDE_DIRECTORIES(${MKLDNN_INC_DIR}) # For MKLDNN code to include internal headers.

IF(${WITH_MKL_CBLAS} STREQUAL "ON")
    SET(MKLDNN_DEPENDS   ${MKLML_PROJECT})
    MESSAGE(STATUS "Build MKLDNN with MKLML ${MKLML_ROOT}")
ELSE()
    MESSAGE(FATAL_ERROR "Should enable MKLML when build MKLDNN")
ENDIF()

IF(NOT WIN32)
    SET(MKLDNN_FLAG "-Wno-error=strict-overflow -Wno-error=unused-result -Wno-error=array-bounds")
    SET(MKLDNN_FLAG "${MKLDNN_FLAG} -Wno-unused-result -Wno-unused-value")
    SET(MKLDNN_CFLAG "${CMAKE_C_FLAGS} ${MKLDNN_FLAG}")
    SET(MKLDNN_CXXFLAG "${CMAKE_CXX_FLAGS} ${MKLDNN_FLAG}")
ELSE()
    SET(MKLDNN_CXXFLAG "${CMAKE_CXX_FLAGS} /EHsc")
ENDIF(NOT WIN32)
if(WIN32)
    SET(MKLDNN_LIB "${MKLDNN_INSTALL_DIR}/${LIBDIR}/mkldnn.lib" CACHE FILEPATH "mkldnn library." FORCE)
else(WIN32)
    SET(MKLDNN_LIB "${MKLDNN_INSTALL_DIR}/${LIBDIR}/libmkldnn.a" CACHE FILEPATH "mkldnn library." FORCE)
endif(WIN32)
ExternalProject_Add(
    ${MKLDNN_PROJECT}
    ${EXTERNAL_PROJECT_LOG_ARGS}
    DEPENDS             ${MKLDNN_DEPENDS}
    GIT_REPOSITORY      "https://github.com/intel/mkl-dnn.git"
    GIT_TAG             "a18f78f1f058437e9efee403655d671633360f98"
    PREFIX              ${MKLDNN_SOURCES_DIR}
    UPDATE_COMMAND      ""
    CMAKE_ARGS          -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
    CMAKE_ARGS          -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    CMAKE_ARGS          -DCMAKE_CXX_FLAGS_RELEASE=${CMAKE_CXX_FLAGS_RELEASE}
    CMAKE_ARGS          -DCMAKE_CXX_FLAGS_DEBUG=${CMAKE_CXX_FLAGS_DEBUG}
    CMAKE_ARGS          -DCMAKE_C_FLAGS=${CMAKE_C_FLAGS}
    CMAKE_ARGS          -DCMAKE_C_FLAGS_DEBUG=${CMAKE_C_FLAGS_DEBUG}
    CMAKE_ARGS          -DCMAKE_C_FLAGS_RELEASE=${CMAKE_C_FLAGS_RELEASE}
    CMAKE_ARGS          -DCMAKE_INSTALL_PREFIX=${MKLDNN_INSTALL_DIR}
    CMAKE_ARGS          -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
    CMAKE_ARGS          -DCMAKE_POSITION_INDEPENDENT_CODE=ON
    CMAKE_ARGS          -DMKLROOT=${MKLML_ROOT}
    CMAKE_ARGS          -DCMAKE_C_FLAGS=${MKLDNN_CFLAG}
    CMAKE_ARGS          -DCMAKE_CXX_FLAGS=${MKLDNN_CXXFLAG}
    CMAKE_ARGS          -DMKLDNN_BUILD_TESTS=OFF
    CMAKE_ARGS          -DMKLDNN_BUILD_EXAMPLES=OFF
    CMAKE_ARGS          -DDNNL_LIBRARY_TYPE=STATIC
    CMAKE_CACHE_ARGS    -DCMAKE_INSTALL_PREFIX:PATH=${MKLDNN_INSTALL_DIR}
                        -DMKLROOT:PATH=${MKLML_ROOT}
    BUILD_BYPRODUCTS ${MKLDNN_LIB}
)


ADD_LIBRARY(static_mkldnn STATIC IMPORTED GLOBAL)
SET_PROPERTY(TARGET static_mkldnn PROPERTY IMPORTED_LOCATION ${MKLDNN_LIB})
ADD_DEPENDENCIES(static_mkldnn ${MKLDNN_PROJECT})
MESSAGE(STATUS "MKLDNN library: ${MKLDNN_LIB}")
add_definitions(-DCINN_WITH_MKLDNN)

# generate a static dummy target to track mkldnn dependencies
# for cc_library(xxx SRCS xxx.c DEPS mkldnn)
SET(dummyfile ${CMAKE_CURRENT_BINARY_DIR}/mkldnn_dummy.c)
FILE(WRITE ${dummyfile} "const char * dummy = \"${dummyfile}\";")
ADD_LIBRARY(mkldnn STATIC ${dummyfile})
TARGET_LINK_LIBRARIES(mkldnn ${MKLDNN_LIB} ${MKLML_LIB} ${MKLML_IOMP_LIB})
ADD_DEPENDENCIES(mkldnn ${MKLDNN_PROJECT})

