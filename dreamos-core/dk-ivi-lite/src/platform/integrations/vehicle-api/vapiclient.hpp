#ifndef VAPI_CLIENT_HPP
#define VAPI_CLIENT_HPP

#include "KuksaClient.hpp"
#include <memory>
#include <string>
#include <vector>
#include <functional>
#include <unordered_map>
#include <thread>
#include <mutex>
#include <optional>
#include <iostream>

// Define VAPI server names for consistency across your project.
#define DK_VAPI_DATABROKER   "127.0.0.1:55555"

// Optionally, define a list (macro) of VAPI server names:
#define VAPI_SERVER_LIST { DK_VAPI_DATABROKER }

//----------------------------------------------------------------------
// callback signature used by KuksaClient::subscribe*()
//----------------------------------------------------------------------  
using SubscribeCallback = 
  std::function<void(const std::string &entryPath,
                     const std::string &value,
                     const int &field)>;

//----------------------------------------------------------------------
// VAPIClient: singleton  
//----------------------------------------------------------------------  
class VAPIClient {
public:
  static VAPIClient& instance();

  // Connect (once) to a server. You may optionally pass a list of
  // signalPaths that you intend to subscribe to later.
  // Returns true on success.
  bool connectToServer(const std::string &serverURI,
    const std::vector<std::string> &signalPaths = {});

  // Get/Set current or target values.
  // getCurrent/TargetValue return true if non-empty string was retrieved.
  bool getCurrentValue(const std::string &serverURI,
                       const std::string &path,
                       std::string       &outValue);

  bool getTargetValue(const std::string &serverURI,
                      const std::string &path,
                      std::string       &outValue);

  // Templated conversions
  template<typename T>
  bool getCurrentValueAs(const std::string &serverURI,
                         const std::string &path,
                         T                  &out) {
    auto *c = findClient(serverURI);
    return c ? c->getCurrentValueAs<T>(path, out) : false;
  }

  template<typename T>
  bool getTargetValueAs(const std::string &serverURI,
                        const std::string &path,
                        T                  &out) {
    auto *c = findClient(serverURI);
    return c ? c->getTargetValueAs<T>(path, out) : false;
  }

  template<typename T>
  bool setCurrentValue(const std::string &serverURI,
                       const std::string &path,
                       const T           &newValue) {
    auto *c = findClient(serverURI);
    if (!c) return false;
    c->setCurrentValue<T>(path, newValue);
    return true;
  }

  template<typename T>
  bool setTargetValue(const std::string &serverURI,
                      const std::string &path,
                      const T           &newValue) {
    auto *c = findClient(serverURI);
    if (!c) return false;
    c->setTargetValue<T>(path, newValue);
    return true;
  }

  // Subscribe to *current* value updates for a list of paths.
  // Each subscription runs in its own thread.
  bool subscribeCurrent(const std::string               &serverURI,
                        const std::vector<std::string> &paths,
                        SubscribeCallback               callback);

  // Subscribe to *target* value updates
  bool subscribeTarget(const std::string               &serverURI,
                       const std::vector<std::string> &paths,
                       SubscribeCallback               callback);

  // Blocks/destroys all subscription threads and clients.
  void shutdown();

private:
  VAPIClient();
  ~VAPIClient();

  VAPIClient(const VAPIClient&)            = delete;
  VAPIClient& operator=(const VAPIClient&) = delete;

  // internal helper
  KuksaClient::KuksaClient* findClient(const std::string &serverURI);

  // one entry per connected server
  struct ClientEntry {
    std::unique_ptr<KuksaClient::KuksaClient> client;
    std::vector<std::thread>                  subThreads;
  };

  std::unordered_map<std::string, ClientEntry> mClients_;
  std::mutex                                  mClientsMtx_;
};

// convenience macro
#define VAPI_CLIENT  (VAPIClient::instance())


#endif // VAPI_CLIENT_HPP
