#include "nod_wrap_util.hpp"

namespace nod_wrap {

struct BreakOutFromNative {};

class LogvisorToExceptionConverter : public logvisor::ILogger {
public:


    void report(const char* modName, logvisor::Level severity, fmt::string_view format, fmt::format_args args) override
    {
        auto error_message = fmt::vformat(format, args);
		PyErr_SetString(PyExc_RuntimeError, error_message.c_str());
    }

    void report(const char* modName, logvisor::Level severity, fmt::wstring_view format, fmt::wformat_args args) override
    {
#ifdef UNICODE
        auto buffer = fmt::vformat(format, args);
		nod::SystemUTF8Conv conv(buffer.c_str());
		PyErr_SetString(PyExc_RuntimeError, conv.c_str());
#endif
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

    void reportSource(const char* modName, logvisor::Level severity,
                      const char* file, unsigned linenum,
                      fmt::wstring_view format, fmt::wformat_args args) override
    {
        // openFile();
        // char sourceInfo[128];
        // snprintf(sourceInfo, 128, "%s:%u", file, linenum);
        // _reportHead(modName, sourceInfo, severity);
        // vfwprintf(fp, format, ap);
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
		if (holder.obj() != Py_None) {
        	callback(holder.obj(), std::string(s), p);
			if (PyErr_Occurred()) {
				throw BreakOutFromNative();
			}
		}
    };
}

nod::FProgress createFProgressFunction(PyObject * obj, void (*callback)(PyObject *, float, const std::string&, size_t)) {
	PyObjectHolder holder(obj);
    return [=](float totalProg, nod::SystemStringView fileName, size_t fileBytesXfered) {
		if (holder.obj() != Py_None) {
			nod::SystemUTF8Conv utf8_str(fileName);
        	callback(holder.obj(), totalProg, std::string(utf8_str.c_str()), fileBytesXfered);
			if (PyErr_Occurred()) {
				throw BreakOutFromNative();
			}
		}
    };
}

nod::SystemString string_to_system_string(const std::string& s) {
	nod::SystemStringConv conv(std::string_view(s.c_str()));
	return nod::SystemString(conv.sys_str());
}

void registerLogvisorToExceptionConverter() {
	if (currentConverter) return;
	auto lock = logvisor::LockLog();
	logvisor::MainLoggers.emplace_back(currentConverter = new LogvisorToExceptionConverter);
}

void removeLogvisorToExceptionConverter() {
	if (!currentConverter) return;
	auto lock = logvisor::LockLog();
	for (auto it = logvisor::MainLoggers.begin(); it != logvisor::MainLoggers.end(); ++it) {
		if (it->get() == currentConverter) {
			logvisor::MainLoggers.erase(it);
            currentConverter = nullptr;
			return;
		}
	}
}

PyObject * _handleNativeException(PyObject * callable) {
	if (PyErr_Occurred())
		return NULL;
	try {
		return PyObject_CallFunction(callable, NULL);
	} catch (BreakOutFromNative) {
		return NULL;
	}
}

}
