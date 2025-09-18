// Copyright (c) 2025 Eclipse Foundation.
// 
// This program and the accompanying materials are made available under the
// terms of the MIT License which is available at
// https://opensource.org/licenses/MIT.
// 
// SPDX-License-Identifier: MIT
#ifndef KUKSA_CLIENT_HPP
#define KUKSA_CLIENT_HPP

#include <cstdint>
#include <fstream>
#include <functional>
#include <iostream>
#include <limits>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>
#include <set>
#include <atomic>
#include <mutex>
#include <condition_variable>
#include <chrono>


namespace KuksaClient {

//------------------------------------------------------------------------------
// Configuration structure declaration
//------------------------------------------------------------------------------
struct Config {
  std::string serverURI;
  bool debug = false;
  std::vector<std::string> signalPaths;
};

//------------------------------------------------------------------------------
// Local enumeration for field types (for set operations)
//------------------------------------------------------------------------------
enum FieldType {
  FT_VALUE = 1,           // For setting the “current” value
  FT_ACTUATOR_TARGET = 2  // For setting the “target” actuator value
};

//------------------------------------------------------------------------------
// Local enumeration for get views
//------------------------------------------------------------------------------
enum GetView {
  GV_CURRENT = 0,
  GV_TARGET = 1,
  GV_ALL = 2
};

//------------------------------------------------------------------------------
// KuksaClient Class Declaration
// 
// This class hides all gRPC/Proto details behind a private implementation (pImpl).
// No gRPC or proto types appear anywhere in this header.
//------------------------------------------------------------------------------
class KuksaClient {
public:
  // Constructors & Destructor
  explicit KuksaClient(const Config &config);
  explicit KuksaClient(const std::string &configFile);
  ~KuksaClient();

  //--------------------------------------------------------------------------
  // Public API: Connection & Data Operations
  //--------------------------------------------------------------------------

  // Establish connection to the broker server.
  void connect();

  // Check if client is currently connected
  bool isConnected() const;

  // Enable/disable automatic reconnection (default: enabled)
  void setAutoReconnect(bool enabled);

  // Force a reconnection attempt
  bool reconnect();

  // Get the current value for an entry as a string.
  std::string getCurrentValue(const std::string &entryPath);

  // Get the target (actuator) value for an entry as a string.
  std::string getTargetValue(const std::string &entryPath);

  //--------------------------------------------------------------------------
  // Conversion API: Retrieve and convert values.
  // The templated functions call the string‐based getter and then perform a conversion.
  //--------------------------------------------------------------------------
  template <typename T>
  bool getCurrentValueAs(const std::string &entryPath, T &out) {
    std::string strVal = getCurrentValue(entryPath);
    return convertString(strVal, out);
  }

  template <typename T>
  bool getTargetValueAs(const std::string &entryPath, T &out) {
    std::string strVal = getTargetValue(entryPath);
    return convertString(strVal, out);
  }

  // Stream an update to an entry.
  void streamUpdate(const std::string &entryPath, float newValue);

  //--------------------------------------------------------------------------
  // Set Value API: Set current (or target) value for an entry.
  //--------------------------------------------------------------------------
  template <typename T>
  void setCurrentValue(const std::string &entryPath, const T &newValue) {
    setValueInternal(entryPath, newValue, FT_VALUE);
  }

  template <typename T>
  void setTargetValue(const std::string &entryPath, const T &newValue) {
    setValueInternal(entryPath, newValue, FT_ACTUATOR_TARGET);
  }

  //--------------------------------------------------------------------------
  // Subscription APIs
  //--------------------------------------------------------------------------
  
  void subscribeTargetValue(const std::string &entryPath,
                  std::function<void(const std::string &, const std::string &, const int &)> userCallback);

  void subscribeCurrentValue(const std::string &entryPath,
                  std::function<void(const std::string &, const std::string &, const int &)> userCallback);
  // Subscribe to updates for a specific entry.
  // The provided callback is invoked with (entryPath, updateValue) for every update.
  void subscribe(const std::string &entryPath,
                  std::function<void(const std::string &, const std::string &, const int &)> userCallback, int field);

  // Enhanced subscribe with automatic reconnection
  void subscribeWithReconnect(const std::string &entryPath,
                             std::function<void(const std::string &, const std::string &, const int &)> userCallback,
                             int field);

  // Subscribe to all signal paths (from our configuration).
  // Each subscription runs in its own thread.
  void subscribeAll(std::function<void(const std::string &, const std::string &, const int &)> userCallback);

  // Wait for all subscription threads to finish.
  void joinAllSubscriptions();

  // Wait for all subscription threads to finish with timeout.
  void joinAllSubscriptionsWithTimeout();

  // Detach all subscription threads.
  void detachAllSubscriptions();

  // Retrieve broker server info.
  void getServerInfo();

  //--------------------------------------------------------------------------
  // Static Helper: Parse a configuration file into a Config structure.
  //--------------------------------------------------------------------------
  static bool parseConfig(const std::string &filename, Config &config);

private:
  //--------------------------------------------------------------------------
  // Private Helper Functions
  //--------------------------------------------------------------------------
  // Common function used by getCurrentValue() and getTargetValue().
  // It uses our local GetView enumeration.
  std::string getValue(const std::string &entryPath, GetView view, bool target);

  // Templated helper used to set values.
  // Its implementation is provided in the CPP file.
  template <typename T>
  void setValueInternal(const std::string &entryPath, const T &newValue, int field) {
    setValueInternalImpl(entryPath, newValue, field);
  }

  // Non-templated implementation helper (definition is in the CPP file).
  template <typename T>
  void setValueInternalImpl(const std::string &entryPath, const T &newValue, int field);

  //--------------------------------------------------------------------------
  // Private Helper: Conversion from string to a standard type.
  // Returns true if conversion succeeded.
  //--------------------------------------------------------------------------
  template <typename T>
  static bool convertString(const std::string &str, T &out) {
    std::istringstream iss(str);
    iss >> out;
    return !iss.fail() && iss.eof();
  }
  static bool convertString(const std::string &str, bool &out);
  static bool convertString(const std::string &str, uint8_t &out);
  static bool convertString(const std::string &str, uint16_t &out);
  static bool convertString(const std::string &str, uint32_t &out);

  //--------------------------------------------------------------------------
  // Private Helper Methods for Reconnection
  //--------------------------------------------------------------------------
  bool attemptReconnection();
  void handleConnectionFailure();
  void restartSubscriptions();

  //--------------------------------------------------------------------------
  // Private Members
  //--------------------------------------------------------------------------
  // All gRPC/Proto-related members are hidden in the implementation.
  struct Impl;
  std::unique_ptr<Impl> pImpl;

  // We also store configuration items directly.
  std::string serverURI_;
  bool debug_{false};
  Config config_;
  std::vector<std::string> signalPaths_;

  // Threads dedicated to subscription updates.
  std::vector<std::thread> subscriptionThreads_;

  // Track active subscription paths to prevent duplicates
  std::set<std::string> activeSubscriptionPaths_;
  std::mutex subscriptionPathsMutex_;

  // Connection state management
  mutable std::atomic<bool> connected_{false};
  std::atomic<bool> autoReconnect_{true};
  std::atomic<bool> shouldStop_{false};

  // Connection synchronization
  mutable std::mutex connectionMutex_;

  // Reconnection mechanism
  std::mutex reconnectMutex_;
  std::condition_variable reconnectCV_;
  std::thread reconnectThread_;

  // Active subscription tracking for restart after reconnection
  struct SubscriptionInfo {
    std::string entryPath;
    std::function<void(const std::string &, const std::string &, const int &)> callback;
    int field;
  };
  std::vector<SubscriptionInfo> activeSubscriptions_;
  std::mutex subscriptionsMutex_;
};

} // namespace KuksaClient

#endif // KUKSA_CLIENT_HPP
