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

std::function<void(std::string_view, float)> createProgressCallbackFunction(PyObject * obj, void (*callback)(PyObject *, const std::string&, float)) {
	PyObjectHolder holder(obj);
    return [=](std::string_view s, float p) {
        callback(holder.obj(), std::string(s), p);
    };
}

nod::FProgress createFProgressFunction(PyObject * obj, void (*callback)(PyObject *, float, const std::string&, size_t)) {
	PyObjectHolder holder(obj);
    return [=](float totalProg, nod::SystemStringView fileName, size_t fileBytesXfered) {
		nod::SystemUTF8Conv utf8_str(fileName);
        callback(holder.obj(), totalProg, std::string(utf8_str.c_str()), fileBytesXfered);
    };
}

nod::SystemString string_to_system_string(const std::string& s) {
	nod::SystemStringConv conv(std::string_view(s.c_str()));
	return nod::SystemString(conv.sys_str());
}

}
