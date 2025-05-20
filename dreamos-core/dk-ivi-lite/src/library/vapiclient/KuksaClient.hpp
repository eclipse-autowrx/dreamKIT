#ifndef KUKSA_CLIENT_HPP
#define KUKSA_CLIENT_HPP

#include <string>
#include <vector>
#include <memory>
#include <functional>

namespace KuksaClient {

// A plain configuration structure.
struct Config {
    std::string serverURI;
    bool debug = false;
    std::vector<std::string> signalPaths;
};

// A lightweight JSON-based configuration parser.
// (Users of this API do not see any gRPC/Proto dependencies.)
class ConfigParser {
public:
    // Parse the JSON config file specified by filename.
    // Returns true if parsing succeeds, false otherwise.
    static bool parse(const std::string &filename, Config &config);
};

// Public API for the DataBroker client interface.
// All gRPC/Proto details are hidden in the implementation.
class DataBrokerClient {
public:
    DataBrokerClient();
    ~DataBrokerClient();

    // Establish a connection to the server.
    void Connect(const std::string &serverURI);

    // Get the current value for the specified entry.
    bool GetTargetValue(const std::string &entryPath, std::string &singalValue);
    bool GetCurrentValue(const std::string &entryPath, std::string &singalValue);

    // Send a streamed update (for example, update a value).
    void StreamedUpdate(const std::string &entryPath, float newValue);

    // Define the callback type.
    // The callback receives two strings: the path and the updated value.
    using Callback = std::function<void(const std::string&, const std::string&)>;
    // Subscribe to changes/updates for the given entry.
    void Subscribe(const std::string &entryPath, Callback userCallback);
    void SubscribeTarget(const std::string &entryPath, Callback userCallback);

    // Retrieve basic server information.
    void GetServerInfo();

    // Set the value of an entry.
    // We provide several overloads (non-templated) to avoid "exposing" template code.
    void SetCurrentValue(const std::string &entryPath, float newValue);
    void SetCurrentValue(const std::string &entryPath, double newValue);
    void SetCurrentValue(const std::string &entryPath, uint8_t newValue);
    void SetCurrentValue(const std::string &entryPath, int8_t newValue);
    void SetCurrentValue(const std::string &entryPath, uint32_t newValue);
    void SetCurrentValue(const std::string &entryPath, int32_t newValue);
    void SetCurrentValue(const std::string &entryPath, int64_t newValue);
    void SetCurrentValue(const std::string &entryPath, uint64_t newValue);
    void SetCurrentValue(const std::string &entryPath, bool newValue);
    void SetCurrentValue(const std::string &entryPath, const std::string &newValue);
    
    void SetTargetValue(const std::string &entryPath, float newValue);
    void SetTargetValue(const std::string &entryPath, double newValue);
    void SetTargetValue(const std::string &entryPath, uint8_t newValue);
    void SetTargetValue(const std::string &entryPath, int8_t newValue);
    void SetTargetValue(const std::string &entryPath, uint32_t newValue);
    void SetTargetValue(const std::string &entryPath, int32_t newValue);
    void SetTargetValue(const std::string &entryPath, uint64_t newValue);
    void SetTargetValue(const std::string &entryPath, int64_t newValue);
    void SetTargetValue(const std::string &entryPath, bool newValue);
    void SetTargetValue(const std::string &entryPath, const std::string &newValue);

private:
    // The implementations of the above functions are hidden.
    class Impl;
    std::unique_ptr<Impl> pImpl;
};

// The SubscriptionManager starts subscriptions in separate threads.
class SubscriptionManager {
public:
    SubscriptionManager(DataBrokerClient &client, const std::vector<std::string> &paths);
    ~SubscriptionManager();

    // Start one subscription thread per signal path.
    void startSubscriptions(std::function<void(const std::string&, const std::string&)> userCallback);
    void startTargetSubscriptions(std::function<void(const std::string&, const std::string&)> userCallback);

    // Optionally join all threads.
    void joinAll();

    // Alternatively, detach all subscription threads.
    void detachAll();

private:
    class Impl;
    std::unique_ptr<Impl> pImpl;
};

} // namespace KuksaClient

#endif // KUKSA_CLIENT_HPP
