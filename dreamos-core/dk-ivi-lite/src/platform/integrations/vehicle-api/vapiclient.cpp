// Copyright (c) 2025 Eclipse Foundation.
//
// This program and the accompanying materials are made available under the
// terms of the MIT License which is available at
// https://opensource.org/licenses/MIT.
//
// SPDX-License-Identifier: MIT
#include "vapiclient.hpp"
#include <future>
#include <chrono>


VAPIClient& VAPIClient::instance() {
  static VAPIClient inst;
  return inst;
}

VAPIClient::VAPIClient() = default;

VAPIClient::~VAPIClient() {
  shutdown();
}

bool VAPIClient::connectToServer(const std::string &serverURI,
                                 const std::vector<std::string> &signalPaths) {
  std::lock_guard lock(mClientsMtx_);
  if (mClients_.count(serverURI)) {
    std::cout << "[VAPIClient] Already connected to " << serverURI << "\n";
    return true;
  }

  // build config
  KuksaClient::Config cfg;
  cfg.serverURI   = serverURI;
  cfg.debug       = false;
  cfg.signalPaths = signalPaths;

  try {
    auto client = std::make_unique<KuksaClient::KuksaClient>(cfg);
    client->connect();
    client->getServerInfo();

    ClientEntry entry;
    entry.client = std::move(client);
    mClients_.try_emplace(serverURI, std::move(entry));

    std::cout << "[VAPIClient] Connected to " << serverURI << "\n";
    return true;
  }
  catch (const std::exception &e) {
    std::cerr << "[VAPIClient] Failed to connect to "
              << serverURI << ": " << e.what() << "\n";
    return false;
  }
}

KuksaClient::KuksaClient*
VAPIClient::findClient(const std::string &serverURI) {
  std::lock_guard lock(mClientsMtx_);
  auto it = mClients_.find(serverURI);
  if (it == mClients_.end()) {
    std::cerr << "[VAPIClient] No client for server " << serverURI << "\n";
    return nullptr;
  }
  return it->second.client.get();
}

KuksaClient::KuksaClient*
VAPIClient::findClient(const std::string &serverURI) const {
  std::lock_guard lock(mClientsMtx_);
  auto it = mClients_.find(serverURI);
  if (it == mClients_.end()) {
    std::cerr << "[VAPIClient] No client for server " << serverURI << "\n";
    return nullptr;
  }
  return it->second.client.get();
}

bool VAPIClient::getCurrentValue(const std::string &serverURI,
                                 const std::string &path,
                                 std::string       &outValue) {
  auto *c = findClient(serverURI);
  if (!c) return false;
  outValue = c->getCurrentValue(path);
  return !outValue.empty();
}

bool VAPIClient::getTargetValue(const std::string &serverURI,
                                const std::string &path,
                                std::string       &outValue) {
  auto *c = findClient(serverURI);
  if (!c) return false;
  outValue = c->getTargetValue(path);
  return !outValue.empty();
}

bool VAPIClient::subscribeCurrent(const std::string               &serverURI,
                                  const std::vector<std::string> &paths,
                                  SubscribeCallback               callback) {
  auto *c = findClient(serverURI);
  if (!c) return false;

  // Sequential subscription to prevent race conditions during gRPC setup
  {
    std::lock_guard lock(mClientsMtx_);
    auto &entry = mClients_.at(serverURI);

    // Create single thread that handles all current value subscriptions sequentially
    std::thread subThread([c, paths, callback]() {
      for (const auto &p : paths) {
        try {
          c->subscribeWithReconnect(p, callback, KuksaClient::FT_VALUE);
          // Small delay between subscriptions to prevent gRPC resource conflicts
          std::this_thread::sleep_for(std::chrono::milliseconds(100));
        } catch (const std::exception& e) {
          std::cerr << "[VAPIClient] Failed to subscribe to current value for " << p << ": " << e.what() << std::endl;
        }
      }
    });
    entry.subThreads.emplace_back(std::move(subThread));
  }
  return true;
}

bool VAPIClient::subscribeTarget(const std::string               &serverURI,
                                 const std::vector<std::string> &paths,
                                 SubscribeCallback               callback) {
  auto *c = findClient(serverURI);
  if (!c) return false;

  // Sequential subscription to prevent race conditions during gRPC setup
  {
    std::lock_guard lock(mClientsMtx_);
    auto &entry = mClients_.at(serverURI);

    // Create single thread that handles all target value subscriptions sequentially
    std::thread subThread([c, paths, callback]() {
      // Larger delay to ensure current subscriptions complete first
      std::this_thread::sleep_for(std::chrono::milliseconds(500));

      for (const auto &p : paths) {
        try {
          c->subscribeWithReconnect(p, callback, KuksaClient::FT_ACTUATOR_TARGET);
          // Small delay between subscriptions to prevent gRPC resource conflicts
          std::this_thread::sleep_for(std::chrono::milliseconds(100));
        } catch (const std::exception& e) {
          std::cerr << "[VAPIClient] Failed to subscribe to target value for " << p << ": " << e.what() << std::endl;
        }
      }
    });
    entry.subThreads.emplace_back(std::move(subThread));
  }
  return true;
}

bool VAPIClient::isConnected(const std::string &serverURI) const {
  auto *c = findClient(serverURI);
  return c ? c->isConnected() : false;
}

void VAPIClient::setAutoReconnect(const std::string &serverURI, bool enabled) {
  auto *c = findClient(serverURI);
  if (c) {
    c->setAutoReconnect(enabled);
    std::cout << "[VAPIClient] Auto-reconnect "
              << (enabled ? "enabled" : "disabled")
              << " for " << serverURI << std::endl;
  }
}

bool VAPIClient::forceReconnect(const std::string &serverURI) {
  auto *c = findClient(serverURI);
  if (c) {
    std::cout << "[VAPIClient] Forcing reconnection to " << serverURI << std::endl;
    return c->reconnect();
  }
  return false;
}

void VAPIClient::shutdown() {
  std::cout << "[VAPIClient] Shutting down all clients and threads..." << std::endl;

  std::lock_guard lock(mClientsMtx_);

  for (auto &kv : mClients_) {
    auto &entry = kv.second;

    // Signal KuksaClient to stop first
    if (entry.client) {
      std::cout << "[VAPIClient] Shutting down client for " << kv.first << std::endl;
    }

    // Join subscription threads with timeout
    std::cout << "[VAPIClient] Joining " << entry.subThreads.size()
              << " subscription threads..." << std::endl;

    size_t joinedCount = 0;
    size_t detachedCount = 0;

    for (auto &t : entry.subThreads) {
      try {
        if (t.joinable()) {
          // Try to join with timeout using async approach
          auto future = std::async(std::launch::async, [&t]() {
            t.join();
          });

          if (future.wait_for(std::chrono::seconds(3)) == std::future_status::ready) {
            joinedCount++;
          } else {
            std::cerr << "[VAPIClient] Thread join timeout, detaching thread" << std::endl;
            t.detach();
            detachedCount++;
          }
        }
      } catch (const std::exception& e) {
        std::cerr << "[VAPIClient] Exception while joining thread: " << e.what() << std::endl;
        try {
          if (t.joinable()) {
            t.detach();
            detachedCount++;
          }
        } catch (...) {
          std::cerr << "[VAPIClient] Failed to detach thread after join exception" << std::endl;
        }
      }
    }

    std::cout << "[VAPIClient] Thread cleanup completed for " << kv.first
              << " - joined: " << joinedCount << ", detached: " << detachedCount << std::endl;

    entry.subThreads.clear();
    // unique_ptr<KuksaClient> will be destroyed here
  }

  mClients_.clear();
  std::cout << "[VAPIClient] Shutdown completed" << std::endl;
}

void VAPIClient::shutdownAsync() {
  std::cout << "[VAPIClient] Starting async shutdown..." << std::endl;

  // Signal all clients to stop without blocking
  {
    std::lock_guard lock(mClientsMtx_);
    for (auto &kv : mClients_) {
      auto &entry = kv.second;

      // Just signal shutdown to KuksaClient instances
      // They will handle their own thread cleanup in their destructors
      if (entry.client) {
        std::cout << "[VAPIClient] Signaling async shutdown for " << kv.first << std::endl;
      }

      // Detach all subscription threads immediately - don't wait
      std::cout << "[VAPIClient] Detaching " << entry.subThreads.size()
                << " subscription threads for " << kv.first << std::endl;

      for (auto &t : entry.subThreads) {
        try {
          if (t.joinable()) {
            t.detach();
          }
        } catch (const std::exception& e) {
          std::cerr << "[VAPIClient] Exception while detaching thread: " << e.what() << std::endl;
        }
      }
      entry.subThreads.clear();
    }
  }

  std::cout << "[VAPIClient] Async shutdown completed" << std::endl;
}
