# Install script for directory: C:/Users/KAVINESH/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/rdkafka-sys-4.10.0+2.12.1/librdkafka

# Set the install prefix
if(NOT DEFINED CMAKE_INSTALL_PREFIX)
  set(CMAKE_INSTALL_PREFIX "D:/Continuum/services/claims_scoring/target/debug/build/rdkafka-sys-a0b3c5d0c382891e/out")
endif()
string(REGEX REPLACE "/$" "" CMAKE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}")

# Set the install configuration name.
if(NOT DEFINED CMAKE_INSTALL_CONFIG_NAME)
  if(BUILD_TYPE)
    string(REGEX REPLACE "^[^A-Za-z0-9_]+" ""
           CMAKE_INSTALL_CONFIG_NAME "${BUILD_TYPE}")
  else()
    set(CMAKE_INSTALL_CONFIG_NAME "Release")
  endif()
  message(STATUS "Install configuration: \"${CMAKE_INSTALL_CONFIG_NAME}\"")
endif()

# Set the component getting installed.
if(NOT CMAKE_INSTALL_COMPONENT)
  if(COMPONENT)
    message(STATUS "Install component: \"${COMPONENT}\"")
    set(CMAKE_INSTALL_COMPONENT "${COMPONENT}")
  else()
    set(CMAKE_INSTALL_COMPONENT)
  endif()
endif()

# Is this installation the result of a crosscompile?
if(NOT DEFINED CMAKE_CROSSCOMPILING)
  set(CMAKE_CROSSCOMPILING "FALSE")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib/cmake/RdKafka" TYPE FILE FILES
    "D:/Continuum/services/claims_scoring/target/debug/build/rdkafka-sys-a0b3c5d0c382891e/out/build/generated/RdKafkaConfig.cmake"
    "D:/Continuum/services/claims_scoring/target/debug/build/rdkafka-sys-a0b3c5d0c382891e/out/build/generated/RdKafkaConfigVersion.cmake"
    "C:/Users/KAVINESH/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/rdkafka-sys-4.10.0+2.12.1/librdkafka/packaging/cmake/Modules/FindLZ4.cmake"
    )
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake/RdKafka/RdKafkaTargets.cmake")
    file(DIFFERENT _cmake_export_file_changed FILES
         "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake/RdKafka/RdKafkaTargets.cmake"
         "D:/Continuum/services/claims_scoring/target/debug/build/rdkafka-sys-a0b3c5d0c382891e/out/build/CMakeFiles/Export/a1c6bd80150ccef2e736c8ff7566f1db/RdKafkaTargets.cmake")
    if(_cmake_export_file_changed)
      file(GLOB _cmake_old_config_files "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake/RdKafka/RdKafkaTargets-*.cmake")
      if(_cmake_old_config_files)
        string(REPLACE ";" ", " _cmake_old_config_files_text "${_cmake_old_config_files}")
        message(STATUS "Old export file \"$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake/RdKafka/RdKafkaTargets.cmake\" will be replaced.  Removing files [${_cmake_old_config_files_text}].")
        unset(_cmake_old_config_files_text)
        file(REMOVE ${_cmake_old_config_files})
      endif()
      unset(_cmake_old_config_files)
    endif()
    unset(_cmake_export_file_changed)
  endif()
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib/cmake/RdKafka" TYPE FILE FILES "D:/Continuum/services/claims_scoring/target/debug/build/rdkafka-sys-a0b3c5d0c382891e/out/build/CMakeFiles/Export/a1c6bd80150ccef2e736c8ff7566f1db/RdKafkaTargets.cmake")
  if(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Dd][Ee][Bb][Uu][Gg])$")
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib/cmake/RdKafka" TYPE FILE FILES "D:/Continuum/services/claims_scoring/target/debug/build/rdkafka-sys-a0b3c5d0c382891e/out/build/CMakeFiles/Export/a1c6bd80150ccef2e736c8ff7566f1db/RdKafkaTargets-debug.cmake")
  endif()
  if(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Mm][Ii][Nn][Ss][Ii][Zz][Ee][Rr][Ee][Ll])$")
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib/cmake/RdKafka" TYPE FILE FILES "D:/Continuum/services/claims_scoring/target/debug/build/rdkafka-sys-a0b3c5d0c382891e/out/build/CMakeFiles/Export/a1c6bd80150ccef2e736c8ff7566f1db/RdKafkaTargets-minsizerel.cmake")
  endif()
  if(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Rr][Ee][Ll][Ww][Ii][Tt][Hh][Dd][Ee][Bb][Ii][Nn][Ff][Oo])$")
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib/cmake/RdKafka" TYPE FILE FILES "D:/Continuum/services/claims_scoring/target/debug/build/rdkafka-sys-a0b3c5d0c382891e/out/build/CMakeFiles/Export/a1c6bd80150ccef2e736c8ff7566f1db/RdKafkaTargets-relwithdebinfo.cmake")
  endif()
  if(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Rr][Ee][Ll][Ee][Aa][Ss][Ee])$")
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib/cmake/RdKafka" TYPE FILE FILES "D:/Continuum/services/claims_scoring/target/debug/build/rdkafka-sys-a0b3c5d0c382891e/out/build/CMakeFiles/Export/a1c6bd80150ccef2e736c8ff7566f1db/RdKafkaTargets-release.cmake")
  endif()
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/share/licenses/librdkafka" TYPE FILE FILES "C:/Users/KAVINESH/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/rdkafka-sys-4.10.0+2.12.1/librdkafka/LICENSES.txt")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for each subdirectory.
  include("D:/Continuum/services/claims_scoring/target/debug/build/rdkafka-sys-a0b3c5d0c382891e/out/build/src/cmake_install.cmake")
  include("D:/Continuum/services/claims_scoring/target/debug/build/rdkafka-sys-a0b3c5d0c382891e/out/build/src-cpp/cmake_install.cmake")

endif()

string(REPLACE ";" "\n" CMAKE_INSTALL_MANIFEST_CONTENT
       "${CMAKE_INSTALL_MANIFEST_FILES}")
if(CMAKE_INSTALL_LOCAL_ONLY)
  file(WRITE "D:/Continuum/services/claims_scoring/target/debug/build/rdkafka-sys-a0b3c5d0c382891e/out/build/install_local_manifest.txt"
     "${CMAKE_INSTALL_MANIFEST_CONTENT}")
endif()
if(CMAKE_INSTALL_COMPONENT)
  if(CMAKE_INSTALL_COMPONENT MATCHES "^[a-zA-Z0-9_.+-]+$")
    set(CMAKE_INSTALL_MANIFEST "install_manifest_${CMAKE_INSTALL_COMPONENT}.txt")
  else()
    string(MD5 CMAKE_INST_COMP_HASH "${CMAKE_INSTALL_COMPONENT}")
    set(CMAKE_INSTALL_MANIFEST "install_manifest_${CMAKE_INST_COMP_HASH}.txt")
    unset(CMAKE_INST_COMP_HASH)
  endif()
else()
  set(CMAKE_INSTALL_MANIFEST "install_manifest.txt")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  file(WRITE "D:/Continuum/services/claims_scoring/target/debug/build/rdkafka-sys-a0b3c5d0c382891e/out/build/${CMAKE_INSTALL_MANIFEST}"
     "${CMAKE_INSTALL_MANIFEST_CONTENT}")
endif()
