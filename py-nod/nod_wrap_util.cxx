#include "nod_wrap_util.hpp"

namespace nod_wrap {

class PyObjectHolder {
public:
	PyObjectHolder(PyObject* the_obj) : obj_(the_obj) {
		Py_XINCREF(the_obj);
	}
	~PyObjectHolder() {
		Py_XDECREF(obj_);
	}

	PyObject* obj() const { return obj_; }
private:
	PyObject* obj_;
};

std::function<void(const std::string&, float)> createProgressCallbackFunction(PyObject * obj, void (*callback)(PyObject *, const std::string&, float)) {
	PyObjectHolder holder(obj);
    return [=](const std::string& s, float p) {
        callback(holder.obj(), s, p);
    };
}

nod::FProgress createFProgressFunction(PyObject * obj, void (*callback)(PyObject *, float, const nod::SystemString&, size_t)) {
	PyObjectHolder holder(obj);
    return [=](float totalProg, const nod::SystemString& fileName, size_t fileBytesXfered) {
        callback(holder.obj(), totalProg, fileName, fileBytesXfered);
    };
}

}
