#!/usr/bin/env python3
"""Emit small, local-only desktop telemetry snapshots as JSON lines."""

import json
import os
import time
from pathlib import Path


def cpu_times():
    fields = Path('/proc/stat').read_text().splitlines()[0].split()[1:]
    values = [int(value) for value in fields]
    return sum(values), values[3] + values[4]


def memory_percent():
    lines = Path('/proc/meminfo').read_text().splitlines()
    values = {key.rstrip(':'): int(value.split()[0]) for key, value in (line.split(':', 1) for line in lines)}
    return round(100 * (1 - values['MemAvailable'] / values['MemTotal']))


def battery():
    for path in Path('/sys/class/power_supply').glob('BAT*'):
        try:
            return {'percent': int((path / 'capacity').read_text().strip()),
                    'status': (path / 'status').read_text().strip()}
        except (OSError, ValueError):
            pass
    return None


def uptime():
    seconds = int(float(Path('/proc/uptime').read_text().split()[0]))
    hours, minutes = divmod(seconds // 60, 60)
    days, hours = divmod(hours, 24)
    return f'{days}d {hours}h' if days else f'{hours}h {minutes}m'


previous_total, previous_idle = cpu_times()
while True:
    try:
        total, idle = cpu_times()
        delta = max(1, total - previous_total)
        cpu = round(100 * (1 - (idle - previous_idle) / delta))
        previous_total, previous_idle = total, idle
        disk = os.statvfs(os.path.expanduser('~'))
        used = 100 * (1 - disk.f_bavail / disk.f_blocks)
        print(json.dumps({'cpu': max(0, min(100, cpu)),
                          'memory': memory_percent(),
                          'disk': round(used),
                          'battery': battery(),
                          'uptime': uptime()}), flush=True)
    except (OSError, ValueError, KeyError, ZeroDivisionError):
        pass
    time.sleep(3)
