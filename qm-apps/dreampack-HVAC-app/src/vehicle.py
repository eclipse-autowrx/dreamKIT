"""Simple Vehicle model using DataBroker client - no MQTT complexity."""

import os
import asyncio
from typing import Union
import logging
from databroker_client import databroker_client

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class SimpleFanSpeedService:
    """Simple DataBroker service for HVAC fan speed control."""

    def __init__(self, signal_path: str):
        self._signal_path = signal_path
        self._value = 0

    async def set(self, value: Union[int, float]):
        """Set fan speed (0-100) via DataBroker."""
        try:
            self._value = max(0, min(100, float(value)))

            # Set value via DataBroker
            success = await databroker_client.set_value(self._signal_path, self._value)

            if success:
                print(f"    → VSS Signal Update: {self._signal_path} = {self._value}%")
                return True
            else:
                print(f"    → VSS Signal Update (failed): {self._signal_path} = {self._value}%")
                return False

        except Exception as e:
            logger.warning(f"Failed to set via DataBroker: {e}")
            print(f"    → VSS Signal Update (error): {self._signal_path} = {self._value}%")
            return False

    async def get(self):
        """Get current fan speed from DataBroker."""
        try:
            value = await databroker_client.get_value(self._signal_path)
            if value is not None:
                self._value = value
            return self._value
        except Exception as e:
            logger.error(f"Failed to get {self._signal_path}: {e}")
            return self._value

class SimpleHVACStation:
    """HVAC station with DataBroker connection."""

    def __init__(self):
        self.Driver = type('Driver', (), {
            'FanSpeed': SimpleFanSpeedService(
                'Vehicle.Cabin.HVAC.Station.Row1.Driver.FanSpeed'
            )
        })()
        self.Passenger = type('Passenger', (), {
            'FanSpeed': SimpleFanSpeedService(
                'Vehicle.Cabin.HVAC.Station.Row1.Passenger.FanSpeed'
            )
        })()

class SimpleHVACSystem:
    """HVAC system with DataBroker connection."""

    def __init__(self):
        self.Station = type('Station', (), {
            'Row1': SimpleHVACStation()
        })()

class SimpleCabin:
    """Vehicle cabin with DataBroker connection."""

    def __init__(self):
        self.HVAC = SimpleHVACSystem()

class SimpleVehicle:
    """Simple vehicle model with DataBroker connection."""

    def __init__(self, databroker_host: str = None, databroker_port: int = 55555):
        # Use environment variable or default to localhost
        self._databroker_host = databroker_host or os.getenv('KUKSA_ADDRESS', '127.0.0.1')
        self._databroker_port = databroker_port
        self.Cabin = None

    async def connect(self):
        """Connect to DataBroker."""
        try:
            # Configure DataBroker client
            databroker_client.host = self._databroker_host
            databroker_client.port = self._databroker_port

            # Connect to DataBroker
            if not await databroker_client.connect():
                logger.error("Failed to connect to DataBroker")
                return False

            # Initialize vehicle structure
            self.Cabin = SimpleCabin()

            logger.info("✅ Successfully connected to DataBroker")
            return True

        except Exception as e:
            logger.error(f"❌ Failed to connect to DataBroker: {e}")
            return False

    async def disconnect(self):
        """Disconnect from DataBroker."""
        await databroker_client.disconnect()

# Global simple vehicle instance
vehicle = SimpleVehicle()