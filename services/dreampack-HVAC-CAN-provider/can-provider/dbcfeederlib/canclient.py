# Copyright (c) 2025 Eclipse Foundation.
# 
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT

########################################################################

import logging
from typing import Optional
import can  # type: ignore
from dbcfeederlib import canmessage

log = logging.getLogger(__name__)


class CANClient:
    """
    Wrapper class to hide dependency to CAN package.
    Reason is to make it simple to replace the CAN package dependency with something else if your KUKSA.val
    integration cannot interact directly with CAN, but rather interacts with some custom CAN solution/middleware.
    """

    def __init__(self, *args, **kwargs):
        # pylint: disable=abstract-class-instantiated
        self._bus = can.interface.Bus(*args, **kwargs)

    def stop(self):
        """Shut down CAN bus."""
        self._bus.shutdown()

    def recv(self, timeout: int = 1) -> Optional[canmessage.CANMessage]:
        """Receive message from CAN bus."""
        try:
            msg = self._bus.recv(timeout)
        except can.CanError:
            msg = None
            if self._bus:
                log.error("Error while waiting for recv from CAN", exc_info=True)
            else:
                # This is expected if we are shutting down
                log.debug("Exception received during shutdown")

        if msg:
            canmsg = canmessage.CANMessage(msg)
            return canmsg
        return None

    def send(self, arbitration_id, data):
        """Write message to CAN bus."""
        msg = can.Message(arbitration_id=arbitration_id, data=data, is_extended_id=False)
        try:
            self._bus.send(msg)
            if log.isEnabledFor(logging.DEBUG):
                log.debug("Sent message [channel: %s]: %s", self._bus.channel_info, msg)
        except can.CanError:
            log.error("Failed to send message via CAN bus")
