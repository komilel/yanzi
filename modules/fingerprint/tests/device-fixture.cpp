// Exercise the real D-Bus Device/verification classes without a USB sensor.
#include <jinx/libevent.hpp>
#include "drv_fpc/fpc9201.cpp"

class IdleSensor : public jinx::AsyncRoutine {
    jinx::Queue<std::queue<fpc9201::FPCEvent>>* queue{};
    jinx::Queue<std::queue<fpc9201::FPCEvent>>::Get get{};
public:
    auto& operator()(jinx::Queue<std::queue<fpc9201::FPCEvent>>* events) {
        queue = events;
        async_start(&IdleSensor::wait);
        return *this;
    }
    jinx::Async wait() {
        return *this / get(queue) / &IdleSensor::consume;
    }
    jinx::Async consume() {
        const auto type = get.get_result()._type;
        if (type != fpc9201::FPCEvent::FPP_StartSensor
            && type != fpc9201::FPCEvent::FPP_StopSensor) {
            throw std::runtime_error("Unexpected fixture sensor event");
        }
        return wait();
    }
};

int main() {
    using namespace jinx;
    using namespace jinx::dbus;
    using namespace jinx::usb;
    DBusError error{};
    dbus_error_init(&error);
    AsyncDBusConnection connection{dbus_bus_get(DBUS_BUS_SESSION, &error)};
    if (dbus_error_is_set(&error)) return 1;
    if (dbus_bus_request_name(connection, "net.reactivated.Fprint", 0, &error)
        != DBUS_REQUEST_NAME_REPLY_PRIMARY_OWNER) return 1;
    // Deliberately deliver unrelated owner-change signals to the Device's
    // connection, too: its listener must not drop another client's claim.
    dbus_bus_add_match(connection,
        "type='signal',interface='org.freedesktop.DBus',member='NameOwnerChanged'",
        &error);
    if (dbus_error_is_set(&error)) return 1;

    libevent::EventEngineLibevent engine{false};
    Loop loop{&engine};
    AsyncDBus bus{engine, connection};
    AsyncUSB usb{engine};
    record::RecordCategory config{};
    fingerpp::Manager manager{loop, bus, usb, config};
    fpc::FingerprintStorage storage{}; // Never load or save real templates.
    Queue<std::queue<fpc9201::FPCEvent>> events{0}, images{0};
    manager.start();
    loop.task_new<IdleSensor>(&events);
    loop.task_new<fpc9201::WorkerDevice>(
        &events, &images, &manager, &storage, "fixture");
    loop.run();
}
