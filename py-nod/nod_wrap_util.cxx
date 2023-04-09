#include "nod_wrap_util.hpp"
#include "logvisor/logvisor.hpp"

namespace nod_wrap {

struct BreakOutFromNative {};

class LogvisorToExceptionConverter : public logvisor::ILogger {
public:
	LogvisorToExceptionConverter() : ILogger(log_typeid(LogvisorToExceptionConverter)) {}

    void report(const char* modName, logvisor::Level severity, fmt::string_view format, fmt::format_args args) override
    {
        auto state = PyGILState_Ensure();
        auto error_message = fmt::vformat(format, args);
		PyErr_SetString(PyExc_RuntimeError, error_message.c_str());
		PyGILState_Release(state);
    }
	
    void reportSource(const char* modName, logvisor::Level severity,
                      const char* file, unsigned linenum,
                      fmt::string_view format, fmt::format_args args) override
    {
        // openFile();
        // char sourceInfo[128];
        // snprintf(sourceInfo, 128, "%s:%u", file, linenum);
        // _reportHead(modName, sourceInfo, severity);
        // vfprintf(fp, format, ap);
        // fprintf(fp, "\n");
        // closeFile();
    }
};

namespace {
	LogvisorToExceptionConverter* currentConverter = nullptr;
}


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
		auto state = PyGILState_Ensure();
		Py_XINCREF(obj_);
		PyGILState_Release(state);
	}
	void decrement_and_clear() {
		auto state = PyGILState_Ensure();
		Py_CLEAR(obj_);
		PyGILState_Release(state);
	}
	void clear() {
		obj_ = nullptr;
	}
};

std::function<void(std::string_view, float)> createProgressCallbackFunction(PyObject * obj, void (*callback)(PyObject *, const std::string&, float)) {
	PyObjectHolder holder(obj);
    return [=](std::string_view s, float p) {
		if (holder.obj() != Py_None) {
			auto state = PyGILState_Ensure();
        	callback(holder.obj(), std::string(s), p);
			auto has_err = PyErr_Occurred();
			PyGILState_Release(state);
			if (has_err) {
				throw BreakOutFromNative();
			}
		}
    };
}

nod::FProgress createFProgressFunction(PyObject * obj, void (*callback)(PyObject *, float, const std::string&, size_t)) {
	PyObjectHolder holder(obj);
    return [=](float totalProg, std::string_view fileName, size_t fileBytesXfered) {
		if (holder.obj() != Py_None) {
			auto state = PyGILState_Ensure();
        	callback(holder.obj(), totalProg, std::string(fileName), fileBytesXfered);
			auto has_err = PyErr_Occurred();
			PyGILState_Release(state);
			if (has_err) {
				throw BreakOutFromNative();
			}
		}
    };
}

PyObject * getDol(const nod::IPartition* partition) {
	auto buffer = partition->getDOLBuf();
	return PyBytes_FromStringAndSize(reinterpret_cast<char*>(buffer.get()), partition->getDOLSize());
}

void registerLogvisorToExceptionConverter() {
	if (currentConverter) return;
	auto lock = logvisor::LockLog();
	logvisor::MainLoggers.emplace_back(currentConverter = new LogvisorToExceptionConverter);
}

void removeLogvisorToExceptionConverter() {
	if (!currentConverter) return;

	auto lock = logvisor::LockLog();
	auto pos = std::find_if(logvisor::MainLoggers.begin(), logvisor::MainLoggers.end(), [](auto& it) { return it.get() == currentConverter; });
	if (pos != logvisor::MainLoggers.end()) {
		logvisor::MainLoggers.erase(pos);
		currentConverter = nullptr;
	}
}

PyObject * _handleNativeException(PyObject * callable) {
	if (PyErr_Occurred())
		return NULL;

	registerLogvisorToExceptionConverter();
	PyObject * result;
	try {
		result = PyObject_CallFunction(callable, NULL);
	} catch (BreakOutFromNative) {
	    result = NULL;
	}
	removeLogvisorToExceptionConverter();
	return result;
}

}
