cmake_minimum_required(VERSION 3.10 FATAL_ERROR) # because of c++17
project(py-nod VERSION 0.1)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if (MSVC)
  add_definitions(-DUNICODE=1)
endif()

add_subdirectory(external/nod)
find_package(Python COMPONENTS Development)

add_library(py-nod SHARED
            _nod.cpp
            py-nod/nod_wrap_util.cxx
            py-nod/nod_wrap_util.hpp
            )
target_link_libraries(py-nod PUBLIC nod Python::Module)