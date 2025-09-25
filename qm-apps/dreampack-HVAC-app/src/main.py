#!/usr/bin/env python3
"""
DreamPack HVAC Application with Simple DataBroker Client
Simplified version based on qnxcabin-service DataBrokerClient pattern
"""

import time
import asyncio
import signal
import logging
from vehicle import vehicle

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class SimpleHVACApp:
    """Simple HVAC Demo Application with DataBroker integration."""

    def __init__(self, vehicle_client):
        self.Vehicle = vehicle_client
        self._running = True

    def _stop(self, signum=None, frame=None):
        """Stop the application gracefully."""
        self._running = False

    async def run(self):
        """Run the vehicle app."""
        await self.on_start()

    async def on_start(self):
        # Print demo banner and description
        print("=" * 80)
        print("🤖 AI-POWERED HVAC CONTROL DEMO - Simple DataBroker Edition")
        print("=" * 80)
        print("Goal & AI Interaction:")
        print("  This demo simulates an AI assistant responding to user voice")
        print("  commands for climate control. The app uses DataBroker client")
        print("  to communicate with KUKSA DataBroker for VSS signal updates.")
        print("")
        print("Real-world Scenario:")
        print("  👤 User: 'Hey AI, I'm feeling hot, can you turn up the AC?'")
        print("  🤖 AI: 'Sure! Increasing fan speed to cool you down.'")
        print("  ⚙️  DataBroker: Receives command → Sets fan speed to 80%")
        print("")
        print("VSS Signals Controlled:")
        print("  • Vehicle.Cabin.HVAC.Station.Row1.Driver.FanSpeed")
        print("  • Vehicle.Cabin.HVAC.Station.Row1.Passenger.FanSpeed")
        print("")
        print("Architecture:")
        print("  🔄 App → Simple DataBroker Client → KUKSA DataBroker → VSS")
        print("")
        print("Starting AI-powered climate control simulation...")
        print("=" * 80)

        # Wait before starting the actual demo
        await asyncio.sleep(3)

        # Define AI scenarios with context
        ai_scenarios = [
            {"speed": 0, "context": "AI: 'Turning off AC as requested - fresh air mode activated'"},
            {"speed": 25, "context": "AI: 'Setting gentle breeze for comfortable reading'"},
            {"speed": 50, "context": "AI: 'Moderate cooling for normal driving comfort'"},
            {"speed": 75, "context": "AI: 'Increasing airflow - detected warm weather outside'"},
            {"speed": 100, "context": "AI: 'Maximum cooling - hot day detected, cooling cabin quickly'"},
            {"speed": 40, "context": "AI: 'Reducing to comfortable level - target temperature reached'"}
        ]

        scenario_index = 0

        print("\n🚀 AI Climate Assistant Demo Started! Press Ctrl+C to stop.\n")

        while self._running:
            # Get current scenario
            current_scenario = ai_scenarios[scenario_index]
            fan_speed = current_scenario["speed"]
            ai_context = current_scenario["context"]

            # Simulate AI decision making
            print(f"🎤 User Request Detected...")
            await asyncio.sleep(1)

            print(f"🤖 {ai_context}")
            await asyncio.sleep(1)

            print(f"⚙️  DataBroker: Executing AI command → Fan Speed: {fan_speed}% {'(OFF)' if fan_speed == 0 else '(ACTIVE)'}")

            # Set driver fan speed via DataBroker
            await self.Vehicle.Cabin.HVAC.Station.Row1.Driver.FanSpeed.set(fan_speed)

            # Set passenger fan speed via DataBroker
            await self.Vehicle.Cabin.HVAC.Station.Row1.Passenger.FanSpeed.set(fan_speed)

            print(f"✅ Climate adjustment complete via DataBroker!\n")

            # Move to next scenario
            scenario_index = (scenario_index + 1) % len(ai_scenarios)

            # Wait before next AI interaction
            await asyncio.sleep(4)

async def main():
    print("🚀 Starting DreamPack HVAC Demo with Simple DataBroker...")

    # Connect to DataBroker first
    print("🔌 Connecting to KUKSA DataBroker at 127.0.0.1:55555...")
    if not await vehicle.connect():
        print("❌ Failed to connect to KUKSA DataBroker")
        print("💡 Make sure KUKSA DataBroker is running and accessible at port 55555")
        return

    hvac_app = SimpleHVACApp(vehicle)
    try:
        await hvac_app.run()
    except KeyboardInterrupt:
        print("\n👋 Demo stopped by user")
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
    finally:
        # Clean disconnect
        print("🔌 Disconnecting from KUKSA DataBroker...")
        await vehicle.disconnect()

if __name__ == "__main__":
    asyncio.run(main())