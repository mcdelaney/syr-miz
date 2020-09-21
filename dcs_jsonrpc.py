"""Communicate with DCS JSON-RPC Server."""
import argparse
import asyncio

from pyjsonrpc import (DCSRpcClient, EVENTS, UNIT_TYPES,
    COALITIONS, GROUP_CATEGORIES, UNIT_TYPES)


async def startup_requests(client):
    """Make initial requests to the RPC server."""
    await client.health()

    await client.outText("Hello from python", 12)

    for evt in EVENTS:
        await client.subscribe(name=evt)

    for coalition in COALITIONS:
        for group_type in GROUP_CATEGORIES:
            await client.getGroups(coalition=coalition,
                                   category=group_type)

async def main(client):
    """Start tasks to read and write to the stream."""
    await client.connect()
    t1 = asyncio.create_task(client.run())
    t2 = asyncio.create_task(startup_requests(client))
    t3 = asyncio.create_task(client.process_responses())
    await asyncio.gather(*[t1, t2])


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--url', type=str, default='127.0.0.1',
                        help="IP to connect to.")
    parser.add_argument('--port', type=int, default=7777,
                        help="Port to connect on.")
    parser.add_argument('--debug', action='store_true',
                        help="Enable debug mode.")
    args = parser.parse_args()

    client = DCSRpcClient(args.url, args.port, log_level="DEBUG" if args.debug else 'INFO')
    asyncio.run(main(client))

