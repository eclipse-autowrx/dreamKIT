#!/usr/bin/env python3
"""
Simplified DataBroker Client for HVAC Demo
Based on qnxcabin-service DataBrokerClient pattern but without MQTT complexity
"""

import os
import asyncio
import logging
from typing import Optional
from kuksa_client.grpc import VSSClient
from kuksa_client.grpc import Datapoint

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class DataBrokerClient:
    """
    Simplified DataBroker client that:
    - Connects to KUKSA Data Broker via gRPC
    - Provides simple read/write methods for VSS signals
    - Handles reconnection automatically
    """

    def __init__(self, host: str = None, port: int = 55555):
        # Use environment variable or default to localhost
        self.host = host or os.getenv('KUKSA_ADDRESS', '127.0.0.1')
        self.port = port
        self.client = None
        self._connected = False

    async def connect(self) -> bool:
        """Connect to KUKSA Data Broker."""
        try:
            logger.info(f"Connecting to KUKSA Data Broker at {self.host}:{self.port}")

            # Create synchronous client
            self.client = VSSClient(self.host, self.port)
            await asyncio.get_event_loop().run_in_executor(None, self.client.connect)

            self._connected = True
            logger.info("✅ Successfully connected to KUKSA Data Broker")
            return True

        except Exception as e:
            logger.error(f"❌ Failed to connect to KUKSA Data Broker: {e}")
            self._connected = False
            return False

    async def disconnect(self):
        """Disconnect from KUKSA Data Broker."""
        if self.client and self._connected:
            try:
                await asyncio.get_event_loop().run_in_executor(None, self.client.disconnect)
                logger.info("Disconnected from KUKSA Data Broker")
            except Exception as e:
                logger.error(f"Error during disconnect: {e}")
            finally:
                self._connected = False

    async def set_value(self, path: str, value) -> bool:
        """Set a VSS signal value."""
        if not self._connected or not self.client:
            logger.error("Not connected to KUKSA Data Broker")
            return False

        try:
            updates = {path: Datapoint(value=value)}
            await asyncio.get_event_loop().run_in_executor(
                None, self.client.set_target_values, updates
            )
            logger.info(f"Set {path} = {value}")
            return True

        except Exception as e:
            logger.error(f"Failed to set {path} = {value}: {e}")
            return False

    async def get_value(self, path: str) -> Optional[any]:
        """Get a VSS signal value."""
        if not self._connected or not self.client:
            logger.error("Not connected to KUKSA Data Broker")
            return None

        try:
            response = await asyncio.get_event_loop().run_in_executor(
                None, self.client.get_target_values, [path]
            )
            if path in response:
                value = response[path].value
                logger.info(f"Got {path} = {value}")
                return value
            else:
                logger.warning(f"Signal {path} not found in response")
                return None

        except Exception as e:
            logger.error(f"Failed to get {path}: {e}")
            return None

# Global DataBroker client instance
databroker_client = DataBrokerClient()