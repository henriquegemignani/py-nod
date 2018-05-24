#include <functional>
#include <string>
#include "Python.h"
#include "nod/Util.hpp"
#include "nod/DiscBase.hpp"

namespace nod_wrap {

std::function<void(std::string_view, float)> createProgressCallbackFunction(PyObject *, void (*)(PyObject *, const std::string&, float));
nod::FProgress createFProgressFunction(PyObject *, void (*)(PyObject *, float, const std::string&, size_t));

} // namespace nod_wrap
