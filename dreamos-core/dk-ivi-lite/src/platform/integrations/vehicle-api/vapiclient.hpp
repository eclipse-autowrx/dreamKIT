// Copyright (c) 2025 Eclipse Foundation.
//
// This program and the accompanying materials are made available under the
// terms of the MIT License which is available at
// https://opensource.org/licenses/MIT.
//
// SPDX-License-Identifier: MIT

// This header provides the VAPIClient interface.
// The actual implementation is in the libKuksaClient.so library.

#ifndef VAPI_CLIENT_HPP
#define VAPI_CLIENT_HPP

#include <memory>
#include <string>
#include <vector>
#include <functional>
#include <unordered_map>
#include <thread>
#include <mutex>
#include <optional>
#include <iostream>

// Forward declare KuksaClient namespace
namespace KuksaClient {
    class KuksaClient;
}

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

  // Templated conversions - declared here, implemented in library
  template<typename T>
  bool getCurrentValueAs(const std::string &serverURI,
                         const std::string &path,
                         T                  &out);

  template<typename T>
  bool getTargetValueAs(const std::string &serverURI,
                        const std::string &path,
                        T                  &out);

  template<typename T>
  bool setCurrentValue(const std::string &serverURI,
                       const std::string &path,
                       const T           &newValue);

  template<typename T>
  bool setTargetValue(const std::string &serverURI,
                      const std::string &path,
                      const T           &newValue);

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

  // Non-blocking shutdown suitable for Qt application termination
  void shutdownAsync();

  // Connection status and control
  bool isConnected(const std::string &serverURI) const;
  void setAutoReconnect(const std::string &serverURI, bool enabled);
  bool forceReconnect(const std::string &serverURI);

private:
  VAPIClient();
  ~VAPIClient();

  VAPIClient(const VAPIClient&)            = delete;
  VAPIClient& operator=(const VAPIClient&) = delete;

  // internal helper
  KuksaClient::KuksaClient* findClient(const std::string &serverURI);
  KuksaClient::KuksaClient* findClient(const std::string &serverURI) const;

  // one entry per connected server
  struct ClientEntry {
    std::unique_ptr<KuksaClient::KuksaClient> client;
    std::vector<std::thread>                  subThreads;
  };

  std::unordered_map<std::string, ClientEntry> mClients_;
  mutable std::mutex                          mClientsMtx_;
};

// convenience macro
#define VAPI_CLIENT  (VAPIClient::instance())

// Explicit template instantiations (implemented in library)
extern template bool VAPIClient::getCurrentValueAs<int>(const std::string&, const std::string&, int&);
extern template bool VAPIClient::getCurrentValueAs<float>(const std::string&, const std::string&, float&);
extern template bool VAPIClient::getCurrentValueAs<double>(const std::string&, const std::string&, double&);
extern template bool VAPIClient::getCurrentValueAs<bool>(const std::string&, const std::string&, bool&);
extern template bool VAPIClient::getCurrentValueAs<uint8_t>(const std::string&, const std::string&, uint8_t&);
extern template bool VAPIClient::getCurrentValueAs<std::string>(const std::string&, const std::string&, std::string&);

extern template bool VAPIClient::getTargetValueAs<int>(const std::string&, const std::string&, int&);
extern template bool VAPIClient::getTargetValueAs<float>(const std::string&, const std::string&, float&);
extern template bool VAPIClient::getTargetValueAs<double>(const std::string&, const std::string&, double&);
extern template bool VAPIClient::getTargetValueAs<bool>(const std::string&, const std::string&, bool&);
extern template bool VAPIClient::getTargetValueAs<uint8_t>(const std::string&, const std::string&, uint8_t&);
extern template bool VAPIClient::getTargetValueAs<std::string>(const std::string&, const std::string&, std::string&);

extern template bool VAPIClient::setCurrentValue<int>(const std::string&, const std::string&, const int&);
extern template bool VAPIClient::setCurrentValue<float>(const std::string&, const std::string&, const float&);
extern template bool VAPIClient::setCurrentValue<double>(const std::string&, const std::string&, const double&);
extern template bool VAPIClient::setCurrentValue<bool>(const std::string&, const std::string&, const bool&);
extern template bool VAPIClient::setCurrentValue<uint8_t>(const std::string&, const std::string&, const uint8_t&);
extern template bool VAPIClient::setCurrentValue<std::string>(const std::string&, const std::string&, const std::string&);

extern template bool VAPIClient::setTargetValue<int>(const std::string&, const std::string&, const int&);
extern template bool VAPIClient::setTargetValue<float>(const std::string&, const std::string&, const float&);
extern template bool VAPIClient::setTargetValue<double>(const std::string&, const std::string&, const double&);
extern template bool VAPIClient::setTargetValue<bool>(const std::string&, const std::string&, const bool&);
extern template bool VAPIClient::setTargetValue<uint8_t>(const std::string&, const std::string&, const uint8_t&);
extern template bool VAPIClient::setTargetValue<std::string>(const std::string&, const std::string&, const std::string&);

#endif // VAPI_CLIENT_HPP
