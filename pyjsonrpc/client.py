"""Communicate with DCS JSON-RPC Server."""
import argparse
import asyncio
import inspect
import logging
import json
from typing import Dict, Optional
from pprint import pprint
from logging import getLogger

logging.basicConfig(level=logging.INFO)
LOG = getLogger(__name__)


EVENTS = (
    "Shot",
    "Hit",
    "Takeoff",
    "Land",
    "Crash",
    "Ejection",
    "Refueling",
    "Dead",
    "PilotDead",
    "BaseCapture",
    "MissionStart",
    "MissionEnd",
    "Birth",
    "SystemFailure",
    "EngineStartup",
    "EngineShutdown",
    "PlayerEnterUnit",
    "PlayerLeaveUnit",
    "ShootingStart",
    "ShootingEnd",
    "MarkAdd",
    "MarkChange",
    "MarkRemove",
    "CommandSelect",
)

COALITIONS = {'red': 1,
              'blue': 2,
              'neutral': 0,
}

UNIT_TYPES = {'airplane': 1,
              'helicopter': 2,
              'ground_unit': 3,
              'ship': 4,
              'structure':5
}

WEAPONS = {
    "shell": 0,
    "missile": 1,
    "rocket": 2,
    "bomb": 3
}

STATIC_OBJECT_TYPES = {
    "void": 0,
    "unit": 1,
    "weapon": 2,
    "static": 3,
    "base": 4,
    "scenery": 5,
    "cargo": 6
}

TYPES = {
    "unit": 1,
    "weapon": 2,
    "static": 3,
    "base": 4,
    "scenery": 5,
    "cargo": 6
}

GROUP_CATEGORIES = {
    "airplane": 0,
    "helicopter": 1,
    "ground": 2,
    "ship": 3,
    "train": 4
}

STATE = {}
for coalition in COALITIONS:
    STATE[coalition] = {}
    for grp in GROUP_CATEGORIES:
        STATE[coalition][grp] = {}

STATE['static_objects'] = {}
for static_obj_type in STATIC_OBJECT_TYPES:
    STATE['static_objects'][static_obj_type] = {}

pprint(STATE)


class RcpClientBase:
    """Base Client interface for communication with rpc-server."""
    base_msg = {"jsonrpc": "2.0", "method": None, "id": None}
    writer = None
    reader = None

    def __init__(self, url, port, log_level='INFO'):
        self.url = url
        self.port = port
        self.log = getLogger('rpc-client')
        self.log.setLevel(log_level)
        self.id = 0
        self.requests = asyncio.Queue()
        self.responses = asyncio.Queue()
        self.calls = {}

    async def connect(self):
        """"Connect to remote rpc server."""
        self.reader, self.writer = await asyncio.open_connection(
            self.url, self.port)
        self.log.info('Connection opened...')

    async def run(self):
        if not self.writer:
            await self.connect()

        self.log.info("Starting consumer...")
        while True:
            if not self.requests.empty():
                msg = await self.requests.get()
                self.writer.write(msg)

            try:
                fut = self.reader.readline()
                resp = await asyncio.wait_for(fut, timeout=0.5)
                if resp:
                    resp = self.deser(resp)
                    await self.responses.put(resp)
                self.log.debug(resp)
            except asyncio.TimeoutError:
                pass

    async def close(self):
        """Close client connection."""
        self.writer.close()
        await self.writer.wait_closed()

    async def _queue_msg(self, params: Optional[Dict] = None,
                         method: Optional[str] = None):
        """Add an an rpc message to the queue."""
        self.id += 1
        if not method:
            (_, _, method, _, _) = inspect.getframeinfo(inspect.currentframe().f_back)

        msg = self.base_msg.copy()

        msg['method'] = method
        if params:
            msg['params'] = params

        self.calls[self.id] = msg

        msg['id'] = self.id
        msg_ser = json.dumps(msg) + "\n"
        msg_ser = msg_ser.encode('UTF-8')
        self.log.debug(f"Queueing message: {msg_ser}")
        await self.requests.put(msg_ser)

    async def send_and_await(self, params: Optional[Dict] = None):
        """Send an rpc message and await it's response."""
        (_, _, method, _, _) = inspect.getframeinfo(inspect.currentframe().f_back)
        self._queue_msg(params, method)

    async def health(self):
        """Check health of rpc server."""
        await self._queue_msg()

    async def process_responses(self):
        """Consume the message repsonse queue."""
        while True:
            if not self.responses.empty():
                resp = await self.responses.get_nowait()
                call_type = self.call_ids[resp['id']]
                if call_type == 'getGroups':
                    for result in resp['results']:
                        # STATE
                        self.log.info(result)
                        pass
                    # STATE[]


    @staticmethod
    def deser(message):
        """Read rpc response."""
        message = message.strip()
        message = json.loads(message)
        return message

    @staticmethod
    def args_to_params(kw_locals):
        """Convert to dictionary, excluding method."""
        kw_locals.pop('method', None)
        kw_locals.pop('self', None)

        if 'coalition' in kw_locals.keys():
            kw_locals['coalition'] = COALITIONS[kw_locals['coalition']]

        if 'category' in kw_locals.keys():
            kw_locals['category'] = GROUP_CATEGORIES[kw_locals['category']]

        return kw_locals


class DCSRpcClient(RcpClientBase):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

    async def subscribe(self, name):
        """Subscribe to an event."""
        params = self.args_to_params(locals())
        await self._queue_msg(params = params)

    async def outText(self, text: str, displayTime: int,
                      clearView: Optional[bool] = False):
        """Display text message to all players."""
        params = self.args_to_params(locals())
        await self._queue_msg(params = params)

    def outTextForGroup(self, name: str, text: str,
                              displayTime: int,
                              clearView: Optional[bool] = False):
        """Display text message to all players."""
        params = self.args_to_params(locals())
        self._queue_msg(params = params)

    def removeMark(self, id: int):
        """Remove mark from F10 map."""
        params = self.args_to_params(locals())
        self._queue_msg(params = params)

    async def getZone(self, name: str):
        """Get information about trigger zone."""
        params = self.args_to_params(locals())
        return await self.send_and_await(params = params)

    async def getZones(self):
        """Get a list of all trigger zones."""
        params = self.args_to_params(locals())
        return await self.send_and_await(params = params)

    async def getUserFlag(self, flag: str):
        """Get the value of a user flag."""
        params = self.args_to_params(locals())
        return await self.send_and_await(params = params)

    async def setUserFlag(self, flag: str, value: int):
        """Set a value of a user flag."""
        params = self.args_to_params(locals())
        await self._queue_msg(params = params)

    async def getGroups(self, coalition: int, category: int):
        """ Get a list of groups for a given coalition and type"""
        params = self.args_to_params(locals())
        await self._queue_msg(params = params)

    async def groupID(self, name: str):
        """Get the id of a given group."""
        params = self.args_to_params(locals())
        return await self.send_and_await(params = params)

    async def groupExists(self, name: str):
        """ Return boolean if a group exists."""
        params = self.args_to_params(locals())
        return await self.send_and_await(params = params)

    async def groupData(self, name: str):
        """Get group data per mission editor."""
        params = self.args_to_params(locals())
        return await self.send_and_await(params = params)

    async def groupCoalition(self, name: str):
        """Get coalition of a given group."""
        params = self.args_to_params(locals())
        return await self.send_and_await(params = params)

    async def groupCategory(self, name: str):
        """ Get category of a group."""
        params = self.args_to_params(locals())
        return await self.send_and_await(params = params)

    async def addGroup(self, country: int, category, int, data: Dict):
        """
        Dynamically spanwn a new group defined in mission editor.
        Data must be in same format as group defined in mission editor.
        Returns the group name.
        """
        params = self.args_to_params(locals())
        return await self.send_and_await(params = params)

    async def groupActivate(self, name: str):
        """Activate a group with delayed or late activation."""
        params = self.args_to_params(locals())
        await self._queue_msg(params = params)

    async def groupUnits(self, name: str):
        """ Return a list of units in a given group."""
        params = self.args_to_params(locals())
        return await self.send_and_await(params = params)

    async def groupSmoke(self, name: str):
        """
        Set smoke market on group's position.
        Must have embark to transport task set.
        """
        params = self.args_to_params(locals())
        await self._queue_msg(params = params)

    async def groupUnsmoke(self, name: str):
        """Remove smoke from group."""
        params = self.args_to_params(locals())
        await self._queue_msg(params = params)

    async def groupDestroy(self, name: str):
        """Destroy a group."""
        params = self.args_to_params(locals())
        self._queue_msg(params = params)

    async def groupSize(self, name: str):
        """Return the number of units in a group."""
        params = self.args_to_params(locals())
        return await self.send_and_await(params = params)

    async def unitExists(self, name: str):
        """Return bool inidicating if unit still exists."""
        params = self.args_to_params(locals())
        return await self.send_and_await(params = params)

    async def unitPosition(self, name: str):
        """Return x,y,z position of unit, relative to map origin."""
        params = self.args_to_params(locals())
        return await self.send_and_await(params = params)

    async def unitOrientation(self, name: str):
        """Oreintation of a given unit."""
        params = self.args_to_params(locals())
        return await self.send_and_await(params = params)

    async def unitGroup(self, name: str):
        """Return the group to which a unit belongs."""
        params = self.args_to_params(locals())
        return await self.send_and_await(params = params)

    async def unitLife(self, name: str):
        """Retun the current life of a unit."""
        params = self.args_to_params(locals())
        return await self.send_and_await(params = params)

    async def unitPlayerName(self, name: str):
        """Get the contorlling player name of a unit."""
        params = self.args_to_params(locals())
        return await self.send_and_await(params = params)

    async def unitCoalition(self, name: str):
        """Get the coalition of a unit."""
        params = self.args_to_params(locals())
        return await self.send_and_await(params = params)

    async def unitDestroy(self, name: str):
        """Destroy a given unit."""
        params = self.args_to_params(locals())
        await self._queue_msg(params = params)

    async def airbaseExists(self, name: str):
        """Determine if an airbase still exists."""
        params = self.args_to_params(locals())
        return await self.send_and_await(params = params)

    async def airbasePosition(self, name: str):
        """Get the x,y,z position of an airbase, relative map origin."""
        params = self.args_to_params(locals())
        return await self.send_and_await(params = params)

    async def addStatic(self, country: str, data: Dict):
        """
        Dynamically Spawn a static object.
        Data format must match mission editor.
        """
        params = self.args_to_params(locals())
        await self._queue_msg(params = params)

    async def staticID(self, name: str):
        """Get the ID of a static by name."""
        params = self.args_to_params(locals())
        return await self.send_and_await(params = params)

    async def staticName(self, str: id):
        """Get the name of a static by ID."""
        params = self.args_to_params(locals())
        return await self.send_and_await(params = params)

    async def staticExists(self, name: str):
        """Determine if a static exists."""
        params = self.args_to_params(locals())
        return await self.send_and_await(params = params)

    async def staticData(self, name: str):
        """Get data as defined in mission editor for a static."""
        params = self.args_to_params(locals())
        return await self.send_and_await(params = params)

    async def staticCountry(self, name: str):
        """Get the country associated with a static."""
        params = self.args_to_params(locals())
        return await self.send_and_await(params = params)

    async def staticDestroy(self, name: str):
        """Destroy a static object."""
        params = self.args_to_params(locals())
        await self._queue_msg(params = params)


## These need additional argument processing to work properly.
    # async def unitInfantryLoad(self, load: str, into: str):
    #     """Command a group to be loaded."""
    #     params = self.args_to_params(locals())
    #     await self._queue_msg(params = params)

    # async def unitInfantryLoaded(self, name: str):
    #     """Return how many infantry units a unit has loaded."""
    #     params = self.args_to_params(locals())
    #     return await self.send_and_await(params = params)

    # async def unitInfantryUnload(self, name: str):
    #     """Force a loaded group to leave a unit."""
    #     params = self.args_to_params(locals())
    #     await self._queue_msg(params = params)

    # async def unitInfantrySmokeUnloadArea(self, unit: str, smokeFor):
    #     """
    #     Add a smoke marker to an unload area.
    #     This requires a "Disembarking" task being setup for
    #     the given unit and group to work.
    #     """
    #     params = self.args_to_params(locals())
    #     await self._queue_msg(params = params)

# TODO: Add the following:
#  addSubMenu, addGroupSubMenu, addCoalitionSubMenu, addCommand,
#  addGroupCommand, addCoalitionCommand, removeEntry, removeGroupEntry,
#  removeCoalitionEntry
