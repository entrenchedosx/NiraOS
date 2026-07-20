#!/usr/bin/env python3
"""Capture a QEMU framebuffer through a QMP Unix socket."""

import argparse
import json
import socket
from pathlib import Path


def receive_message(stream) -> dict:
    line = stream.readline()
    if not line:
        raise RuntimeError("QMP connection closed before a response arrived")
    return json.loads(line)


def execute(stream, command: str, arguments: dict | None = None) -> dict:
    request = {"execute": command}
    if arguments:
        request["arguments"] = arguments
    stream.write(json.dumps(request).encode("utf-8") + b"\n")
    stream.flush()

    while True:
        response = receive_message(stream)
        if "event" in response:
            continue
        if "error" in response:
            raise RuntimeError(f"QMP {command} failed: {response['error']}")
        return response


def ppm_has_visible_content(path: Path) -> bool:
    """Return true when a P6 capture contains more than trace-level light."""
    with path.open("rb") as capture:
        if capture.readline().strip() != b"P6":
            raise RuntimeError(f"unsupported framebuffer format in {path}")

        dimensions = capture.readline()
        while dimensions.startswith(b"#"):
            dimensions = capture.readline()
        try:
            width, height = (int(value) for value in dimensions.split())
            maximum = int(capture.readline())
        except ValueError as error:
            raise RuntimeError(f"invalid PPM header in {path}") from error
        if width <= 0 or height <= 0 or maximum != 255:
            raise RuntimeError(f"invalid PPM dimensions or color range in {path}")

        pixels = capture.read()

    expected = width * height * 3
    if len(pixels) != expected:
        raise RuntimeError(
            f"incomplete PPM payload in {path}: expected {expected}, got {len(pixels)}"
        )

    # A black or near-black scanout has no evidentiary value. Requiring one
    # percent of color channels above a low threshold tolerates dark themes
    # while rejecting the all-zero surface produced by QEMU -display none.
    lit_channels = sum(channel > 8 for channel in pixels)
    return lit_channels > expected // 100


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--socket", required=True, help="QMP Unix socket path")
    parser.add_argument("--output", required=True, help="Guest-visible PPM output path")
    parser.add_argument(
        "--require-visible-content",
        action="store_true",
        help="fail when the capture is entirely or effectively black",
    )
    args = parser.parse_args()

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)

    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.settimeout(10)
        client.connect(args.socket)
        with client.makefile("rwb") as stream:
            greeting = receive_message(stream)
            if "QMP" not in greeting:
                raise RuntimeError(f"invalid QMP greeting: {greeting}")
            execute(stream, "qmp_capabilities")
            execute(stream, "screendump", {"filename": str(output)})

    if not output.is_file() or output.stat().st_size == 0:
        raise RuntimeError(f"QEMU did not create a framebuffer capture at {output}")
    if args.require_visible_content and not ppm_has_visible_content(output):
        raise RuntimeError(f"QEMU framebuffer is black or has no visible content: {output}")
    print(f"Captured {output} ({output.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
