#!/usr/bin/env python3
"""
run_test.py — Local testing script for the pyGOMAS multi-agent system.

Launches a game with custom Allied agents (our .asl files) alongside
default/dummy pyGOMAS agents to simulate the lab evaluation condition.

Usage:
    python run_test.py                  # default verbosity (LOG: prints only)
    python run_test.py -v               # INFO level
    python run_test.py -vv              # TRACE level (SPADE internals)
    python run_test.py -vvv             # TRACE + SPADE INFO
    python run_test.py -vvvv            # TRACE + SPADE + aioxmpp (XMPP traffic)
    python run_test.py --config FILE    # use alternate JSON game config
"""

import argparse
import asyncio
import json
import logging
import os
import sys
import time

# ---------------------------------------------------------------------------
# Ensure the local pygomas package is importable
# ---------------------------------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
PYGOMAS_PATH = os.path.join(PROJECT_ROOT, "pygomas")

if PYGOMAS_PATH not in sys.path:
    sys.path.insert(0, PYGOMAS_PATH)

os.environ["PYGAME_HIDE_SUPPORT_PROMPT"] = "hide"

from loguru import logger                       # noqa: E402
from spade.container import Container           # noqa: E402
from spade import quit_spade                    # noqa: E402

from pygomas.config import TEAM_ALLIED, TEAM_AXIS  # noqa: E402
from pygomas.cli import create_troops, load_class    # noqa: E402


# ---------------------------------------------------------------------------
# Verbosity control (mirrors pygomas.cli.set_verbosity but more granular)
# ---------------------------------------------------------------------------
def configure_logging(verbose: int):
    """
    Configure logging levels based on verbosity count.

    Level 0: only SUCCESS (agent LOG: prints visible via loguru)
    Level 1: INFO
    Level 2: TRACE (all pyGOMAS debug)
    Level 3: TRACE + SPADE INFO
    Level 4: TRACE + SPADE + aioxmpp INFO (full XMPP traffic)
    """
    logger.remove()

    if verbose == 0:
        logger.add(sys.stderr, level="SUCCESS")
    elif verbose == 1:
        logger.add(sys.stderr, level="INFO")
    else:
        logger.add(
            sys.stderr,
            level="TRACE",
            format="<green>{time:HH:mm:ss}</green> | <level>{level: <8}</level> | <cyan>{name}</cyan> - <level>{message}</level>",
        )

    # Quiet libraries by default
    for lib in ("aiohttp", "aioopenssl", "aiosasl", "asyncio"):
        logging.getLogger(lib).setLevel(logging.WARNING)

    logging.getLogger("spade").setLevel(logging.WARNING)

    if verbose > 2:
        logging.getLogger("spade").setLevel(logging.INFO)
    if verbose > 3:
        logging.getLogger("aioxmpp").setLevel(logging.INFO)
    else:
        logging.getLogger("aioxmpp").setLevel(logging.WARNING)


# ---------------------------------------------------------------------------
# Agent runner (async)
# ---------------------------------------------------------------------------
async def run_agents(troops):
    for troop in troops:
        await troop.start()


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(
        description="PyGOMAS local test runner — spawn custom + dummy agents",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "-c", "--config",
        default=os.path.join(SCRIPT_DIR, "test_game.json"),
        help="Path to JSON game config (default: agents/test_game.json)",
    )
    parser.add_argument(
        "-mp", "--map-path",
        default=None,
        help="Path to custom maps directory",
    )
    parser.add_argument(
        "-v", "--verbose",
        action="count",
        default=0,
        help="Increase verbosity: -v, -vv, -vvv, -vvvv",
    )
    args = parser.parse_args()

    # ------------------------------------------------------------------
    # Logging
    # ------------------------------------------------------------------
    configure_logging(args.verbose)

    print("=" * 70)
    print("  PyGOMAS Test Runner")
    print("=" * 70)
    print(f"  Config : {args.config}")
    print(f"  Verbose: {args.verbose}")
    print(f"  Map    : {args.map_path or '(default)'}")
    print("=" * 70)

    # ------------------------------------------------------------------
    # Load JSON config
    # ------------------------------------------------------------------
    try:
        with open(args.config) as f:
            config = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        print(f"ERROR: Could not load config — {e}", file=sys.stderr)
        return 1

    defaults = {
        "host": "127.0.0.1",
        "manager": "cmanager",
        "service": "cservice",
        "axis": [],
        "allied": [],
    }
    for key, val in defaults.items():
        config.setdefault(key, val)

    host = config["host"]
    manager_jid = f"{config['manager']}@{host}"
    service_jid = f"{config['service']}@{host}"

    print(f"\n  XMPP Host   : {host}")
    print(f"  Manager JID : {manager_jid}")
    print(f"  Service JID : {service_jid}")

    # ------------------------------------------------------------------
    # Build troops
    # ------------------------------------------------------------------
    troops = []

    print("\n--- AXIS TEAM ---")
    for troop in config["axis"]:
        asl_label = troop.get("asl", "(default built-in)")
        amount = troop.get("amount", 1)
        print(f"  [{troop['rank']}] x{amount}  name={troop.get('name', 'auto')}  asl={asl_label}")
        new = create_troops(troop, host, manager_jid, service_jid, args.map_path, team=TEAM_AXIS)
        troops += new

    print("\n--- ALLIED TEAM ---")
    for troop in config["allied"]:
        asl_label = troop.get("asl", "(default built-in)")
        amount = troop.get("amount", 1)
        print(f"  [{troop['rank']}] x{amount}  name={troop.get('name', 'auto')}  asl={asl_label}")
        new = create_troops(troop, host, manager_jid, service_jid, args.map_path, team=TEAM_ALLIED)
        troops += new

    print(f"\n  Total troops: {len(troops)}")
    print("=" * 70)
    print("  Starting agents... (Ctrl+C to stop)\n")

    # ------------------------------------------------------------------
    # Run agents
    # ------------------------------------------------------------------
    container = Container()
    while not container.loop.is_running():
        time.sleep(0.1)

    future = asyncio.run_coroutine_threadsafe(run_agents(troops), container.loop)
    future.result()

    try:
        while any(agent.is_alive() for agent in troops):
            time.sleep(1)
    except KeyboardInterrupt:
        print("\nInterrupted by user.")

    print("Stopping troops...")
    quit_spade()
    print("Done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
