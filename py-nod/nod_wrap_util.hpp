#include <functional>
#include <string>
#include "Python.h"

namespace nod_wrap {

std::function<void(const std::string&, float)> createProgressCallbackFunction(PyObject *, void (*)(PyObject *, const std::string&, float));

} // namespace nod_wrap
