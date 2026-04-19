from __future__ import annotations

"""
TacNet Command Dashboard — BLE Bridge Server

Connects to TacNet iPhone mesh via BLE, decodes messages,
and pushes them to the browser dashboard via WebSocket.

Usage:
    pip install -r requirements.txt
    python server.py
    Open http://localhost:8080
"""

import asyncio
import json
import logging
import time
from pathlib import Path
from datetime import datetime, timezone

from bleak import BleakScanner, BleakClient
from bleak.backends.device import BLEDevice
from bleak.backends.scanner import AdvertisementData
import websockets
from aiohttp import web

# ---------- Constants ----------

TACNET_SERVICE_UUID = "7b4d8c10-3a8e-4d1a-9f53-2e28d9c1a001"
BROADCAST_CHAR_UUID = "7b4d8c10-3a8e-4d1a-9f53-2e28d9c1a101"
COMPACTION_CHAR_UUID = "7b4d8c10-3a8e-4d1a-9f53-2e28d9c1a102"
TREE_CONFIG_CHAR_UUID = "7b4d8c10-3a8e-4d1a-9f53-2e28d9c1a103"

WS_PORT = 8081
HTTP_PORT = 8080
SCAN_INTERVAL = 5.0  # seconds between BLE scans
RECONNECT_DELAY = 3.0

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("tacnet-dashboard")

# ---------- State ----------

ws_clients: set[websockets.WebSocketServerProtocol] = set()
connected_peers: dict[str, BleakClient] = {}
peer_metadata: dict[str, dict] = {}  # address -> {name, last_seen, msg_count, ...}
current_tree: dict | None = None
messages: list[dict] = []
demo_mode: bool = False


# ---------- WebSocket Broadcast ----------

async def ws_broadcast(event: dict):
    """Send an event to all connected browser clients."""
    if not ws_clients:
        return
    payload = json.dumps(event, default=str)
    stale = set()
    for ws in ws_clients:
        try:
            await ws.send(payload)
        except websockets.ConnectionClosed:
            stale.add(ws)
    ws_clients -= stale


async def ws_handler(ws: websockets.WebSocketServerProtocol):
    """Handle a new WebSocket connection from the browser."""
    ws_clients.add(ws)
    log.info(f"Browser connected ({len(ws_clients)} total)")

    # Send current state snapshot
    await ws.send(json.dumps({
        "type": "snapshot",
        "tree": current_tree,
        "messages": messages[-200:],  # last 200
        "peers": peer_metadata,
        "demo_mode": demo_mode,
    }, default=str))

    try:
        async for raw in ws:
            # Handle commands from browser (e.g., demo mode toggle)
            try:
                cmd = json.loads(raw)
                if cmd.get("action") == "toggle_demo":
                    await toggle_demo_mode()
            except json.JSONDecodeError:
                pass
    except websockets.ConnectionClosed:
        pass
    finally:
        ws_clients.discard(ws)
        log.info(f"Browser disconnected ({len(ws_clients)} total)")


# ---------- Demo Mode ----------

DEMO_ROLES = ["Alpha", "Bravo", "Charlie", "Delta"]
DEMO_TRANSCRIPTS = [
    "Two contacts spotted near the north entrance, moving east",
    "South side is clear, moving to cover position",
    "Copy that, holding position at rally point",
    "Eyes on target, single individual near the vehicle",
    "All clear on perimeter, no movement",
    "Contact! Three hostiles bearing north-northwest, 50 meters",
    "Casualty reported, requesting medevac at grid reference",
    "Roger, falling back to secondary position",
]
DEMO_COMPACTIONS = [
    "Alpha: 2x contacts north entrance moving east. Bravo: south clear, repositioning.",
    "Delta: single contact near vehicle. Charlie: holding rally point. No casualties.",
    "ALERT: 3x hostiles NNW 50m. Alpha engaging. Bravo falling back to secondary.",
]

demo_task: asyncio.Task | None = None


async def toggle_demo_mode():
    global demo_mode, demo_task, current_tree
    demo_mode = not demo_mode
    if demo_mode:
        log.info("Demo mode ON")
        # Set up demo tree
        current_tree = {
            "network_name": "TACNET-DEMO",
            "network_id": "demo-network-001",
            "version": 1,
            "tree": {
                "id": "cmd-root",
                "label": "Commander",
                "claimed_by": "dashboard",
                "children": [
                    {
                        "id": "alpha-node",
                        "label": "Alpha",
                        "claimed_by": "iphone-alpha",
                        "children": [
                            {"id": "delta-node", "label": "Delta", "claimed_by": "iphone-delta", "children": []}
                        ],
                    },
                    {
                        "id": "bravo-node",
                        "label": "Bravo",
                        "claimed_by": "iphone-bravo",
                        "children": [
                            {"id": "charlie-node", "label": "Charlie", "claimed_by": "iphone-charlie", "children": []}
                        ],
                    },
                ],
            },
        }
        for role in DEMO_ROLES:
            peer_metadata[f"iphone-{role.lower()}"] = {
                "name": f"iPhone ({role})",
                "last_seen": datetime.now(timezone.utc).isoformat(),
                "msg_count": 0,
                "role": role,
                "connected": True,
            }
        await ws_broadcast({"type": "tree_update", "tree": current_tree})
        await ws_broadcast({"type": "peers_update", "peers": peer_metadata})
        demo_task = asyncio.create_task(demo_loop())
    else:
        log.info("Demo mode OFF")
        if demo_task:
            demo_task.cancel()
            demo_task = None
        current_tree = None
        peer_metadata.clear()
        messages.clear()
        await ws_broadcast({"type": "snapshot", "tree": None, "messages": [], "peers": {}, "demo_mode": False})

    await ws_broadcast({"type": "demo_mode", "active": demo_mode})


async def demo_loop():
    """Generate fake messages for demo/presentation mode."""
    import random
    msg_idx = 0
    comp_idx = 0
    try:
        while True:
            await asyncio.sleep(random.uniform(2.5, 5.0))

            role = random.choice(DEMO_ROLES)
            sender_id = f"iphone-{role.lower()}"
            transcript = DEMO_TRANSCRIPTS[msg_idx % len(DEMO_TRANSCRIPTS)]
            msg_idx += 1

            msg = {
                "id": f"demo-{msg_idx}-{int(time.time())}",
                "type": "BROADCAST",
                "sender_id": sender_id,
                "sender_role": role,
                "parent_id": None,
                "tree_level": 2 if role in ("Delta", "Charlie") else 1,
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "ttl": 3,
                "payload": {
                    "location": {"lat": 51.5074 + random.uniform(-0.001, 0.001),
                                 "lon": -0.1278 + random.uniform(-0.001, 0.001),
                                 "accuracy": 5.0, "is_fallback": False},
                    "encrypted": False,
                    "transcript": transcript,
                },
            }
            messages.append(msg)
            peer_metadata[sender_id]["msg_count"] += 1
            peer_metadata[sender_id]["last_seen"] = msg["timestamp"]

            await ws_broadcast({"type": "message", "message": msg})
            await ws_broadcast({"type": "peers_update", "peers": peer_metadata})

            # Every 3rd message, send a compaction
            if msg_idx % 3 == 0:
                await asyncio.sleep(random.uniform(1.0, 2.0))
                comp = {
                    "id": f"demo-comp-{comp_idx}-{int(time.time())}",
                    "type": "COMPACTION",
                    "sender_id": "compaction-engine",
                    "sender_role": "Commander",
                    "parent_id": None,
                    "tree_level": 0,
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                    "ttl": 1,
                    "payload": {
                        "location": {"lat": 0, "lon": 0, "accuracy": -1, "is_fallback": True},
                        "encrypted": False,
                        "summary": DEMO_COMPACTIONS[comp_idx % len(DEMO_COMPACTIONS)],
                    },
                }
                comp_idx += 1
                messages.append(comp)
                await ws_broadcast({"type": "message", "message": comp})
    except asyncio.CancelledError:
        pass


# ---------- BLE Message Handling ----------

def decode_message(data: bytes, char_uuid: str) -> dict | None:
    """Decode a BLE characteristic value into a Message dict."""
    try:
        # Check for encryption header
        if data[:6] == b"TNENC1":
            log.warning("Received encrypted message — cannot decode without session key")
            return None

        text = data.decode("utf-8")
        msg = json.loads(text)
        return msg
    except (UnicodeDecodeError, json.JSONDecodeError) as e:
        log.warning(f"Failed to decode message: {e}")
        return None


def on_broadcast(sender, data: bytearray):
    """Callback for broadcast characteristic notifications."""
    msg = decode_message(bytes(data), BROADCAST_CHAR_UUID)
    if msg:
        messages.append(msg)
        sender_addr = str(sender) if hasattr(sender, '__str__') else "unknown"
        if sender_addr in peer_metadata:
            peer_metadata[sender_addr]["msg_count"] = peer_metadata[sender_addr].get("msg_count", 0) + 1
            peer_metadata[sender_addr]["last_seen"] = datetime.now(timezone.utc).isoformat()
        log.info(f"[BROADCAST] {msg.get('sender_role', '?')}: {msg.get('payload', {}).get('transcript', '')[:60]}")
        asyncio.create_task(ws_broadcast({"type": "message", "message": msg}))
        asyncio.create_task(ws_broadcast({"type": "peers_update", "peers": peer_metadata}))


def on_compaction(sender, data: bytearray):
    """Callback for compaction characteristic notifications."""
    msg = decode_message(bytes(data), COMPACTION_CHAR_UUID)
    if msg:
        messages.append(msg)
        log.info(f"[COMPACTION] {msg.get('payload', {}).get('summary', '')[:60]}")
        asyncio.create_task(ws_broadcast({"type": "message", "message": msg}))


# ---------- BLE Connection Management ----------

async def connect_to_peer(device: BLEDevice):
    """Connect to a TacNet peripheral and subscribe to its characteristics."""
    global current_tree
    addr = device.address

    if addr in connected_peers:
        return

    log.info(f"Connecting to {device.name or addr}...")

    try:
        client = BleakClient(device, timeout=10.0)
        await client.connect()

        if not client.is_connected:
            log.warning(f"Failed to connect to {addr}")
            return

        connected_peers[addr] = client
        peer_metadata[addr] = {
            "name": device.name or addr[:8],
            "last_seen": datetime.now(timezone.utc).isoformat(),
            "msg_count": 0,
            "connected": True,
        }

        # Read tree config
        try:
            tree_data = await client.read_gatt_char(TREE_CONFIG_CHAR_UUID)
            if tree_data:
                tree_json = json.loads(tree_data.decode("utf-8"))
                current_tree = tree_json
                log.info(f"Got tree config: network={tree_json.get('network_name', '?')}")
                await ws_broadcast({"type": "tree_update", "tree": current_tree})
        except Exception as e:
            log.warning(f"Could not read tree config: {e}")

        # Subscribe to broadcast notifications
        try:
            await client.start_notify(BROADCAST_CHAR_UUID, on_broadcast)
            log.info(f"Subscribed to broadcast on {device.name or addr}")
        except Exception as e:
            log.warning(f"Could not subscribe to broadcast: {e}")

        # Subscribe to compaction notifications
        try:
            await client.start_notify(COMPACTION_CHAR_UUID, on_compaction)
            log.info(f"Subscribed to compaction on {device.name or addr}")
        except Exception as e:
            log.warning(f"Could not subscribe to compaction: {e}")

        await ws_broadcast({"type": "peers_update", "peers": peer_metadata})
        log.info(f"Connected to {device.name or addr}")

    except Exception as e:
        log.error(f"Connection error for {addr}: {e}")
        connected_peers.pop(addr, None)
        peer_metadata.pop(addr, None)


async def scan_loop():
    """Continuously scan for TacNet peripherals and connect."""
    log.info("Starting BLE scan loop...")

    while True:
        if demo_mode:
            await asyncio.sleep(SCAN_INTERVAL)
            continue

        try:
            devices = await BleakScanner.discover(
                timeout=3.0,
                service_uuids=[TACNET_SERVICE_UUID],
            )

            for device in devices:
                if device.address not in connected_peers:
                    asyncio.create_task(connect_to_peer(device))

            # Check for disconnected peers
            stale = []
            for addr, client in connected_peers.items():
                if not client.is_connected:
                    stale.append(addr)

            for addr in stale:
                log.info(f"Peer {addr} disconnected")
                connected_peers.pop(addr, None)
                if addr in peer_metadata:
                    peer_metadata[addr]["connected"] = False
                await ws_broadcast({"type": "peers_update", "peers": peer_metadata})

        except Exception as e:
            log.warning(f"Scan error: {e}")

        await asyncio.sleep(SCAN_INTERVAL)


# ---------- HTTP Server ----------

STATIC_DIR = Path(__file__).parent


async def serve_static(request: web.Request):
    """Serve static files (index.html, styles.css, app.js)."""
    path = request.match_info.get("path", "index.html")
    if not path or path == "/":
        path = "index.html"

    file_path = STATIC_DIR / path

    if not file_path.exists() or not file_path.is_file():
        return web.Response(text="Not found", status=404)

    content_types = {
        ".html": "text/html",
        ".css": "text/css",
        ".js": "application/javascript",
        ".json": "application/json",
        ".svg": "image/svg+xml",
        ".png": "image/png",
        ".ico": "image/x-icon",
        ".mp4": "video/mp4",
    }

    ext = file_path.suffix
    content_type = content_types.get(ext, "application/octet-stream")

    # Stream large files (e.g. video) instead of reading into memory.
    if file_path.stat().st_size > 5_000_000:
        return web.FileResponse(file_path, headers={"Content-Type": content_type})

    return web.Response(
        body=file_path.read_bytes(),
        content_type=content_type,
    )


# ---------- Main ----------

async def main():
    log.info("=" * 50)
    log.info("  TacNet Command Dashboard")
    log.info("=" * 50)

    # Start WebSocket server
    ws_server = await websockets.serve(ws_handler, "localhost", WS_PORT)
    log.info(f"WebSocket server on ws://localhost:{WS_PORT}")

    # Start HTTP server
    app = web.Application()
    app.router.add_get("/", serve_static)
    app.router.add_get("/{path:.*}", serve_static)
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, "localhost", HTTP_PORT)
    await site.start()
    log.info(f"Dashboard at http://localhost:{HTTP_PORT}")
    log.info("")
    log.info("Scanning for TacNet devices...")
    log.info("Press Ctrl+C to stop")
    log.info("")

    # Start BLE scan loop
    scan = asyncio.create_task(scan_loop())

    try:
        await asyncio.Future()  # run forever
    except (KeyboardInterrupt, asyncio.CancelledError):
        log.info("Shutting down...")
        scan.cancel()
        ws_server.close()
        await runner.cleanup()
        for client in connected_peers.values():
            try:
                await client.disconnect()
            except Exception:
                pass


if __name__ == "__main__":
    asyncio.run(main())
