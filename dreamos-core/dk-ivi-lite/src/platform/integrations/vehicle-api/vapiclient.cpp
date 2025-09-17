// Copyright (c) 2025 Eclipse Foundation.
// 
// This program and the accompanying materials are made available under the
// terms of the MIT License which is available at
// https://opensource.org/licenses/MIT.
// 
// SPDX-License-Identifier: MIT
#include "vapiclient.hpp"


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

  // Use the new reconnection-aware subscription method
  {
    std::lock_guard lock(mClientsMtx_);
    auto &entry = mClients_.at(serverURI);
    for (auto &p : paths) {
      entry.subThreads.emplace_back([c, p, callback]() {
        c->subscribeWithReconnect(p, callback, KuksaClient::FT_VALUE);
      });
    }
  }
  return true;
}

bool VAPIClient::subscribeTarget(const std::string               &serverURI,
                                 const std::vector<std::string> &paths,
                                 SubscribeCallback               callback) {
  auto *c = findClient(serverURI);
  if (!c) return false;

  // Use the new reconnection-aware subscription method
  {
    std::lock_guard lock(mClientsMtx_);
    auto &entry = mClients_.at(serverURI);
    for (auto &p : paths) {
      entry.subThreads.emplace_back([c, p, callback]() {
        c->subscribeWithReconnect(p, callback, KuksaClient::FT_ACTUATOR_TARGET);
      });
    }
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
  std::lock_guard lock(mClientsMtx_);
  for (auto &kv : mClients_) {
    auto &entry = kv.second;
    // join any subscription threads
    for (auto &t : entry.subThreads) {
      if (t.joinable()) t.join();
    }
    entry.subThreads.clear();
    // unique_ptr<KuksaClient> will be destroyed here
  }
  mClients_.clear();
}
