#include "nod_wrap_util.hpp"

namespace nod_wrap {

class PyObjectHolder {
public:
	PyObjectHolder(PyObject* the_obj)
	: obj_(the_obj) {
		increment();
	}
	~PyObjectHolder() {
		decrement_and_clear();
	}

	PyObjectHolder(const PyObjectHolder& other)
	: obj_(other.obj_) {
		increment();
	}

	PyObjectHolder(PyObjectHolder&& other)
	: obj_(other.obj_) {
		other.clear();
	}

	PyObjectHolder& operator=(const PyObjectHolder& other) {
		decrement_and_clear();
		obj_ = other.obj_;
		increment();
		return *this;
	}

	PyObjectHolder& operator=(PyObjectHolder&& other) {
		decrement_and_clear();
		obj_ = other.obj_;
		other.clear();
	}

	PyObject* obj() const { return obj_; }
private:
	PyObject* obj_;

	void increment() const {
		Py_XINCREF(obj_);
	}
	void decrement_and_clear() {
		Py_CLEAR(obj_);
	}
	void clear() {
		obj_ = nullptr;
	}
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
