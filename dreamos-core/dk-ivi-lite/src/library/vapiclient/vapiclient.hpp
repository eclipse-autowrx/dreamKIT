#ifndef VAPI_CLIENT_HPP
#define VAPI_CLIENT_HPP

#include "KuksaClient.hpp"
#include <memory>
#include <string>
#include <vector>
#include <functional>
#include <unordered_map>
#include <iostream>

// Define VAPI server names for consistency across your project.
#define DK_SYSTEM_DATABROKER "127.0.0.1:55569"
#define DK_VAPI_DATABROKER   "127.0.0.1:55555"

// Optionally, define a list (macro) of VAPI server names:
#define VAPI_SERVER_LIST { DK_SYSTEM_DATABROKER, DK_VAPI_DATABROKER }

namespace VAPI {

//------------------------------------------------------------------------------
// Vehicle API keys
//
// These inline constants define the available keys for the vehicle Software Update API.
// Using these constants throughout your code enables code completion and minimizes errors.
//------------------------------------------------------------------------------
namespace VehicleAPI {
    inline constexpr const char* V_U_UpdateTrigger           = "Vehicle.SwUpdate.UpdateTrigger";
    inline constexpr const char* V_U_PatchUpdateTrigger      = "Vehicle.SwUpdate.PatchUpdateTrigger";
    inline constexpr const char* V_U_Fota_UpdateTrigger      = "Vehicle.SwUpdate.Fota.UpdateTrigger";
    inline constexpr const char* V_U_XipHost_UpdateTrigger   = "Vehicle.SwUpdate.XipHost.UpdateTrigger";
    inline constexpr const char* V_U_IsNewUpdateAvailable    = "Vehicle.SwUpdate.IsNewUpdateAvailable";
    inline constexpr const char* V_U_CurrentVersion          = "Vehicle.SwUpdate.CurrentVersion";
    inline constexpr const char* V_U_CurrentDescription      = "Vehicle.SwUpdate.CurrentDescription";
    inline constexpr const char* V_U_TargetVersion           = "Vehicle.SwUpdate.TargetVersion";
    inline constexpr const char* V_U_TargetDescription       = "Vehicle.SwUpdate.TargetDescription";
    inline constexpr const char* V_U_Status                  = "Vehicle.SwUpdate.Status";
    inline constexpr const char* V_U_PercentageDone          = "Vehicle.SwUpdate.PercentageDone";
    inline constexpr const char* V_U_StatusDescription       = "Vehicle.SwUpdate.StatusDescription";
    inline constexpr const char* V_U_ErrorCode               = "Vehicle.SwUpdate.ErrorCode";
    inline constexpr const char* V_U_ErrorCodeDescription    = "Vehicle.SwUpdate.ErrorCodeDescription";
    inline constexpr const char* V_U_Fota_PercentageDone     = "Vehicle.SwUpdate.Fota.PercentageDone";
    inline constexpr const char* V_U_XipHost_PercentageDone  = "Vehicle.SwUpdate.XipHost.PercentageDone";
    inline constexpr const char* V_U_Xip_PercentageDone      = "Vehicle.SwUpdate.Xip.PercentageDone";
    inline constexpr const char* V_U_Vip_PercentageDone      = "Vehicle.SwUpdate.Vip.PercentageDone";
    inline constexpr const char* V_U_About_DiskCapacity      = "Vehicle.AboutSystem.DiskCapacity";
    inline constexpr const char* V_U_About_DiskAvailable     = "Vehicle.AboutSystem.DiskAvailable";

    inline constexpr const char* V_Bo_Lights_Beam_Low_IsOn               = "Vehicle.Body.Lights.Beam.Low.IsOn";
    inline constexpr const char* V_Bo_Lights_Beam_High_IsOn              = "Vehicle.Body.Lights.Beam.High.IsOn";
    inline constexpr const char* V_Bo_Lights_Hazard_IsSignaling          = "Vehicle.Body.Lights.Hazard.IsSignaling";
    inline constexpr const char* V_Bo_Trunk_Rear_IsOpen                  = "Vehicle.Body.Trunk.Front.IsOpen";

    inline constexpr const char* V_Ca_Lights_Ambient_Color               = "Vehicle.Cabin.Light.AmbientLight.Row1.DriverSide.Color";
    inline constexpr const char* V_Ca_Lights_Ambient_Intensity           = "Vehicle.Cabin.Light.AmbientLight.Row1.DriverSide.Intensity";
    inline constexpr const char* V_Ca_Lights_Ambient_IsLightOn           = "Vehicle.Cabin.Light.AmbientLight.Row1.DriverSide.IsLightOn";
    inline constexpr const char* V_Ca_Door_R1_DriverSide_IsOpen          = "Vehicle.Cabin.Door.Row1.DriverSide.IsOpen";
    inline constexpr const char* V_Ca_Door_R1_PassengerSide_IsOpen       = "Vehicle.Cabin.Door.Row1.PassengerSide.IsOpen";
    inline constexpr const char* V_Ca_HVAC_Station_R1_Driver_FanSpeed    = "Vehicle.Cabin.HVAC.Station.Row1.Driver.FanSpeed";
    inline constexpr const char* V_Ca_HVAC_Station_R1_Passenger_FanSpeed = "Vehicle.Cabin.HVAC.Station.Row1.Passenger.FanSpeed";

    inline constexpr const char* V_PT_Trans_SelectedGear                 = "Vehicle.Powertrain.Transmission.SelectedGear";

    // Enum for Vehicle.SwUpdate.Status
    enum SwUpdateStatus {
        V_U_Status_Idle = 0,
        V_U_Status_Downloading = 1,
        V_U_Status_Installing = 2,
        V_U_Status_Verifying = 3,
        V_U_Status_ReadyForActivation = 4,
        V_U_Status_Activated = 5,
        V_U_Status_RollingBack = 6,
        V_U_Status_Failed = 7
    };
}

// In VAPIClient.h
struct SubscriptionEntry {
    std::unique_ptr<KuksaClient::SubscriptionManager> manager;
};

//------------------------------------------------------------------------------
// VAPIClient singleton definition
//
// This class wraps one or more KuksaClient::DataBrokerClient instances so that
// many servers (for example, "dksystem_databroker" and "dkvapi_databroker")
// can be used within a single application. The singleton provides a unified
// interface to connect to a given server, query values, and subscribe to signal updates.
//------------------------------------------------------------------------------
class VAPIClient {
public:
    // Get the singleton instance.
    static VAPIClient& instance() {
        static VAPIClient instance;
        return instance;
    }

    // Connect to a server (if not already connected).
    // This will create a new DataBrokerClient if needed and initialize it.
    void connectToServer(const std::string &serverURI);

    // Retrieves the current value for a given path on the specified server.
    // Returns true if successful; false otherwise.
    bool getCurrentValue(const std::string &serverURI,
                         const std::string &path,
                         std::string &value);

    // Set the current value for a given path on the specified server.
    template<typename T>
    void setCurrentValue(const std::string &serverURI, const std::string &path, const T & newValue) 
    {
        auto client = getClient(serverURI);
        if (client) {
            client->SetCurrentValue(path, newValue);
        } else {
            std::cerr << "Client for server " << serverURI << " not found." << std::endl;
        }
    }

    // Retrieves the target value for a given path on the specified server.
    // Returns true if successful; false otherwise.
    bool getTargetValue(const std::string &serverURI,
                         const std::string &path,
                         std::string &value);

    // Set the target value for a given path on the specified server.
    template<typename T>
    void setTargetValue(const std::string &serverURI, const std::string &path, const T & newValue) 
    {
        auto client = getClient(serverURI);
        if (client) {
            client->SetTargetValue(path, newValue);
        } else {
            std::cerr << "Client for server " << serverURI << " not found." << std::endl;
        }
    }

    // Subscribe to a set of signal paths (with a callback) on the specified server.
    // Each call creates a new SubscriptionManager for the given paths.
    void subscribe(const std::string &serverURI,
                   const std::vector<std::string> &signalPaths,
                   const KuksaClient::DataBrokerClient::Callback &userCallback);

    void subscribeTarget(const std::string &serverURI,
                   const std::vector<std::string> &signalPaths,
                   const KuksaClient::DataBrokerClient::Callback &userCallback);

    // Convenience method to retrieve server info from the specified server.
    void getServerInfo(const std::string &serverURI);

private:
    VAPIClient();
    ~VAPIClient();

    // Delete copy constructor and assignment operator.
    VAPIClient(const VAPIClient&) = delete;
    VAPIClient& operator=(const VAPIClient&) = delete;

    // Helper to check if a client exists for the given serverURI.
    // Returns pointer to the client if found, else nullptr.
    KuksaClient::DataBrokerClient* getClient(const std::string &serverURI);

    // Mapping from server URI to the corresponding DataBrokerClient instance.
    std::unordered_map<std::string, std::unique_ptr<KuksaClient::DataBrokerClient>> mClients;

    // Container for persistent SubscriptionManager objects.
    std::vector<SubscriptionEntry> mSubscriptionManagers;

};

} // namespace VAPI

using namespace VAPI;

#define VAPI_CLIENT (VAPIClient::instance())


#endif // VAPI_CLIENT_HPP
