#include "nod_wrap_util.hpp"

namespace nod_wrap {

class LogvisorToExceptionConverter : public logvisor::ILogger {
public:

    void report(const char* modName, logvisor::Level severity,
                const char* format, va_list ap) override
    {
		PyErr_FormatV(PyExc_RuntimeError, format, ap);
    }

    void report(const char* modName, logvisor::Level severity,
                const wchar_t* format, va_list ap) override
    {
		auto correctSize = _vscwprintf(format, ap) + 1;
		std::wstring buffer(correctSize, 0);
		vswprintf(buffer.data(), correctSize, format, ap);

		nod::SystemUTF8Conv conv(buffer.c_str());
		PyErr_SetString(PyExc_RuntimeError, conv.c_str());
    }

    void reportSource(const char* modName, logvisor::Level severity,
                      const char* file, unsigned linenum,
                      const char* format, va_list ap) override
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
                      const wchar_t* format, va_list ap) override
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
		}
    };
}

nod::FProgress createFProgressFunction(PyObject * obj, void (*callback)(PyObject *, float, const std::string&, size_t)) {
	PyObjectHolder holder(obj);
    return [=](float totalProg, nod::SystemStringView fileName, size_t fileBytesXfered) {
		if (holder.obj() != Py_None) {
			nod::SystemUTF8Conv utf8_str(fileName);
        	callback(holder.obj(), totalProg, std::string(utf8_str.c_str()), fileBytesXfered);
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
			return;
		}
	}
}

}
