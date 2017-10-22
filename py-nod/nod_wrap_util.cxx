#include "nod_wrap_util.hpp"

namespace nod_wrap {

std::function<void(const std::string&, float)> createProgressCallbackFunction(PyObject * obj, void (*callback)(PyObject *, const std::string&, float)) {
    return [=](const std::string& s, float p) {
        callback(obj, s, p);
    };
}

nod::FProgress createFProgressFunction(PyObject * obj, void (*callback)(PyObject *, float, const nod::SystemString&, size_t)) {
    return [=](float totalProg, const nod::SystemString& fileName, size_t fileBytesXfered) {
        callback(obj, totalProg, fileName, fileBytesXfered);
    };
}

}
