#!/usr/bin/env python3
"""Send deterministic pointer or keyboard input to a QEMU guest via QMP."""

import argparse
import json
import socket
import time


class QmpClient:
    def __init__(self, path: str) -> None:
        self._socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self._socket.settimeout(10)
        self._socket.connect(path)
        self._stream = self._socket.makefile("rwb")
        greeting = self._receive()
        if "QMP" not in greeting:
            raise RuntimeError(f"invalid QMP greeting: {greeting}")
        self.execute("qmp_capabilities")

    def close(self) -> None:
        self._stream.close()
        self._socket.close()

    def _receive(self) -> dict:
        line = self._stream.readline()
        if not line:
            raise RuntimeError("QMP connection closed before a response arrived")
        return json.loads(line)

    def execute(self, command: str, arguments: dict | None = None) -> dict:
        request: dict = {"execute": command}
        if arguments is not None:
            request["arguments"] = arguments
        self._stream.write(json.dumps(request).encode("utf-8") + b"\n")
        self._stream.flush()
        while True:
            response = self._receive()
            if "event" in response:
                continue
            if "error" in response:
                raise RuntimeError(f"QMP {command} failed: {response['error']}")
            return response


def key_event(key: str, down: bool) -> dict:
    return {
        "type": "key",
        "data": {
            "down": down,
            "key": {"type": "qcode", "data": key},
        },
    }


def click(client: QmpClient, x: int, y: int, width: int, height: int) -> None:
    if not 0 <= x < width or not 0 <= y < height:
        raise ValueError("click coordinates are outside the declared framebuffer")
    absolute_x = round(x * 0x7FFF / max(width - 1, 1))
    absolute_y = round(y * 0x7FFF / max(height - 1, 1))
    # Deliver motion, press, and release as distinct input frames. Sending all
    # four events in one QMP request is legal, but QtWayland can coalesce them
    # before a frame is dispatched, producing intermittent hover-only clicks.
    client.execute(
        "input-send-event",
        {"events": [
            {"type": "abs", "data": {"axis": "x", "value": absolute_x}},
            {"type": "abs", "data": {"axis": "y", "value": absolute_y}},
        ]},
    )
    time.sleep(0.05)
    client.execute(
        "input-send-event",
        {"events": [{"type": "btn", "data": {"down": True, "button": "left"}}]},
    )
    time.sleep(0.05)
    client.execute(
        "input-send-event",
        {"events": [{"type": "btn", "data": {"down": False, "button": "left"}}]},
    )


def type_text(client: QmpClient, value: str) -> None:
    for character in value:
        if "a" <= character <= "z" or "0" <= character <= "9":
            qcode = character
        elif character == " ":
            qcode = "spc"
        else:
            raise ValueError(f"unsupported test character: {character!r}")
        client.execute(
            "input-send-event",
            {"events": [key_event(qcode, True), key_event(qcode, False)]},
        )
        time.sleep(0.03)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--socket", required=True, help="QMP Unix socket path")
    subparsers = parser.add_subparsers(dest="operation", required=True)

    click_parser = subparsers.add_parser("click")
    click_parser.add_argument("x", type=int)
    click_parser.add_argument("y", type=int)
    click_parser.add_argument("--width", type=int, required=True)
    click_parser.add_argument("--height", type=int, required=True)

    type_parser = subparsers.add_parser("type")
    type_parser.add_argument("text")

    args = parser.parse_args()
    client = QmpClient(args.socket)
    try:
        if args.operation == "click":
            click(client, args.x, args.y, args.width, args.height)
        else:
            type_text(client, args.text)
    finally:
        client.close()


if __name__ == "__main__":
    main()
