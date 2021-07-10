cmake_minimum_required(VERSION 3.10 FATAL_ERROR) # because of c++17
project(py-nod VERSION 0.1)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if (MSVC)
  add_compile_definitions(UNICODE=1 _UNICODE=1 __SSE__=1
    _CRT_SECURE_NO_WARNINGS=1 D_SCL_SECURE_NO_WARNINGS=1
    _SCL_SECURE_NO_DEPRECATE=1 _CRT_NONSTDC_NO_WARNINGS=1
    _ENABLE_EXTENDED_ALIGNED_STORAGE=1 NOMINMAX=1)
endif()

add_subdirectory(external/nod)
find_package(Python COMPONENTS Development)

add_library(py-nod SHARED
            _nod.cpp
            py-nod/nod_wrap_util.cxx
            py-nod/nod_wrap_util.hpp
            )
target_link_libraries(py-nod PUBLIC nod Python::Module)