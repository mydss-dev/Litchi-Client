cmake_minimum_required(VERSION 3.18)
project(litchi_core)

set(MIHOMO_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}")
set(MIHOMO_INCLUDE "${CMAKE_CURRENT_SOURCE_DIR}/includes/${ANDROID_ABI}")

add_library(litchi_mihomo SHARED IMPORTED)
set_target_properties(
  litchi_mihomo
  PROPERTIES IMPORTED_LOCATION "${MIHOMO_DIR}/liblitchi_mihomo.so"
)

add_library(litchi_core SHARED litchi_core.cpp)
target_include_directories(litchi_core PRIVATE "${MIHOMO_INCLUDE}")
target_link_libraries(litchi_core litchi_mihomo log android)
