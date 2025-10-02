# Copyright (c) 2025 Eclipse Foundation.
# 
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT
import asyncio
import logging
import signal

from vehicle import Vehicle, vehicle  # type: ignore
from velocitas_sdk.util.log import (  # type: ignore
    get_opentelemetry_log_factory,
    get_opentelemetry_log_format,
)
from velocitas_sdk.vehicle_app import VehicleApp

# Configure the VehicleApp logger with the necessary log config and level.
logging.setLogRecordFactory(get_opentelemetry_log_factory())
logging.basicConfig(format=get_opentelemetry_log_format())
logging.getLogger().setLevel("INFO")
logger = logging.getLogger(__name__)


class TestApp(VehicleApp):
    def __init__(self, vehicle_client: Vehicle):
        super().__init__()
        self.Vehicle = vehicle_client
        self.running = True

    async def on_start(self):
        # Print demo banner and description
        logger.info("=" * 80)
        logger.info("🤖 AI-POWERED HVAC CONTROL DEMO")
        logger.info("=" * 80)
        logger.info("Goal & AI Interaction:")
        logger.info("  This demo simulates an AI assistant responding to user voice")
        logger.info("  commands for climate control. The QM app reacts to AI decisions")
        logger.info("  and automatically adjusts HVAC fan speeds accordingly.")
        logger.info("")
        logger.info("Real-world Scenario:")
        logger.info("  👤 User: 'Hey AI, I'm feeling hot, can you turn up the AC?'")
        logger.info("  🤖 AI: 'Sure! Increasing fan speed to cool you down.'")
        logger.info("  ⚙️  QM App: Receives AI command → Sets fan speed to 80%")
        logger.info("")
        logger.info("  👤 User: 'It's too cold now, reduce the airflow please.'")
        logger.info("  🤖 AI: 'Of course! Reducing fan speed for your comfort.'")
        logger.info("  ⚙️  QM App: Receives AI command → Sets fan speed to 30%")
        logger.info("")
        logger.info("VSS Signals Controlled:")
        logger.info("  • Vehicle.Cabin.HVAC.Station.Row1.Driver.FanSpeed")
        logger.info("  • Vehicle.Cabin.HVAC.Station.Row1.Passenger.FanSpeed")
        logger.info("")
        logger.info("Demo Simulation:")
        logger.info("  • Simulates various AI-driven climate adjustment scenarios")
        logger.info("  • Shows different fan speed levels based on user comfort needs")
        logger.info("  • Demonstrates intelligent HVAC control through voice commands")
        logger.info("  • Range: 0-100% (percentage of maximum fan speed)")
        logger.info("")
        logger.info("Starting AI-powered climate control simulation...")
        logger.info("=" * 80)
        
        await asyncio.sleep(3)
        
        ai_scenarios = [
            {"speed": 0, "context": "AI: 'Turning off AC as requested - fresh air mode activated'"},
            {"speed": 25, "context": "AI: 'Setting gentle breeze for comfortable reading'"},
            {"speed": 50, "context": "AI: 'Moderate cooling for normal driving comfort'"},
            {"speed": 75, "context": "AI: 'Increasing airflow - detected warm weather outside'"},
            {"speed": 100, "context": "AI: 'Maximum cooling - hot day detected, cooling cabin quickly'"},
            {"speed": 40, "context": "AI: 'Reducing to comfortable level - target temperature reached'"}
        ]
        
        scenario_index = 0
        
        logger.info("\n🚀 AI Climate Assistant Demo Started! Press Ctrl+C to stop.\n")
        
        while True:
            current_scenario = ai_scenarios[scenario_index]
            fan_speed = current_scenario["speed"]
            ai_context = current_scenario["context"]
            
            logger.info(f"🎤 User Request Detected...")
            await asyncio.sleep(1)
            
            logger.info(f"🤖 {ai_context}")
            await asyncio.sleep(1)
            
            logger.info(f"⚙️  QM App: Executing AI command → Fan Speed: {fan_speed}% {'(OFF)' if fan_speed == 0 else '(ACTIVE)'}")
            
            await self.Vehicle.Cabin.HVAC.Station.Row1.Driver.FanSpeed.set(fan_speed)
            await self.Vehicle.Cabin.HVAC.Station.Row1.Passenger.FanSpeed.set(fan_speed)
            
            logger.info(f"✅ Climate adjustment complete!\n")
            
            scenario_index = (scenario_index + 1) % len(ai_scenarios)
            
            await asyncio.sleep(4)

async def main():
    """Main function"""
    logger.info("Starting Vehical App...")
    vehicle_app = TestApp(vehicle)
    await vehicle_app.run()

LOOP = asyncio.get_event_loop()
LOOP.add_signal_handler(signal.SIGTERM, LOOP.stop)
LOOP.run_until_complete(main())
LOOP.close()
