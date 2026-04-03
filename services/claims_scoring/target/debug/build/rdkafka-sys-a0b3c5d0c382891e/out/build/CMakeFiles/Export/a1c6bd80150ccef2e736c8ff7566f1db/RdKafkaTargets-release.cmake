#----------------------------------------------------------------
# Generated CMake target import file for configuration "Release".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "RdKafka::rdkafka" for configuration "Release"
set_property(TARGET RdKafka::rdkafka APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
set_target_properties(RdKafka::rdkafka PROPERTIES
  IMPORTED_LINK_INTERFACE_LANGUAGES_RELEASE "C"
  IMPORTED_LOCATION_RELEASE "${_IMPORT_PREFIX}/lib/rdkafka.lib"
  )

list(APPEND _cmake_import_check_targets RdKafka::rdkafka )
list(APPEND _cmake_import_check_files_for_RdKafka::rdkafka "${_IMPORT_PREFIX}/lib/rdkafka.lib" )

# Import target "RdKafka::rdkafka++" for configuration "Release"
set_property(TARGET RdKafka::rdkafka++ APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
set_target_properties(RdKafka::rdkafka++ PROPERTIES
  IMPORTED_LINK_INTERFACE_LANGUAGES_RELEASE "CXX"
  IMPORTED_LOCATION_RELEASE "${_IMPORT_PREFIX}/lib/rdkafka++.lib"
  )

list(APPEND _cmake_import_check_targets RdKafka::rdkafka++ )
list(APPEND _cmake_import_check_files_for_RdKafka::rdkafka++ "${_IMPORT_PREFIX}/lib/rdkafka++.lib" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
