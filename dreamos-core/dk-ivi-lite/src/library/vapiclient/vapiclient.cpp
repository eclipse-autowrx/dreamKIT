#include "vapiclient.hpp"

namespace VAPI {

VAPIClient::VAPIClient() {
    // Initially, no connections are set up.
}

VAPIClient::~VAPIClient() {
    // All DataBrokerClient instances will be destroyed automatically.
}

void VAPIClient::connectToServer(const std::string &serverURI) {
    // Only connect if a client for serverURI does not already exist.
    if (mClients.find(serverURI) == mClients.end()) {
        auto client = std::make_unique<KuksaClient::DataBrokerClient>();
        client->Connect(serverURI);
        client->GetServerInfo();
        mClients[serverURI] = std::move(client);
        std::cout << "Connected to server " << serverURI << std::endl;
    } else {
        std::cout << "Already connected to " << serverURI << std::endl;
    }
}

KuksaClient::DataBrokerClient* VAPIClient::getClient(const std::string &serverURI) {
    auto it = mClients.find(serverURI);
    if (it != mClients.end()) {
        return it->second.get();
    }
    return nullptr;
}

bool VAPIClient::getCurrentValue(const std::string &serverURI,
                                 const std::string &path,
                                 std::string &value) {
    auto client = getClient(serverURI);
    if (client) {
        return client->GetCurrentValue(path, value);
    } else {
        std::cerr << "Client for server " << serverURI << " not found." << std::endl;
        return false;
    }
}

bool VAPIClient::getTargetValue(const std::string &serverURI,
    const std::string &path,
    std::string &value) {
    auto client = getClient(serverURI);
    if (client) {
        return client->GetTargetValue(path, value);
    } else {
        std::cerr << "Client for server " << serverURI << " not found." << std::endl;
        return false;
    }
}

// Inside VAPIClient::subscribe
void VAPIClient::subscribe(const std::string &serverURI,
    const std::vector<std::string> &signalPaths,
    const KuksaClient::DataBrokerClient::Callback &userCallback) {

    auto client = getClient(serverURI);
    if (client) {
        auto subManager = std::make_unique<KuksaClient::SubscriptionManager>(*client, signalPaths);
        subManager->startSubscriptions(userCallback);
        subManager->detachAll();
        mSubscriptionManagers.push_back({std::move(subManager)});
    } else {
        std::cerr << "Client for server " << serverURI << " not found: cannot subscribe." << std::endl;
    }
}

void VAPIClient::subscribeTarget(const std::string &serverURI,
    const std::vector<std::string> &signalPaths,
    const KuksaClient::DataBrokerClient::Callback &userCallback) {

    auto client = getClient(serverURI);
    if (client) {
        auto subManager = std::make_unique<KuksaClient::SubscriptionManager>(*client, signalPaths);
        subManager->startTargetSubscriptions(userCallback);
        subManager->detachAll();
        mSubscriptionManagers.push_back({std::move(subManager)});
    } else {
        std::cerr << "Client for server " << serverURI << " not found: cannot subscribe." << std::endl;
    }
}

void VAPIClient::getServerInfo(const std::string &serverURI) {
    auto client = getClient(serverURI);
    if (client) {
        client->GetServerInfo();
    } else {
        std::cerr << "Client for server " << serverURI << " not found." << std::endl;
    }
}

} // namespace VAPI
