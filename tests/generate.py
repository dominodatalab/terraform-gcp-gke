#!/usr/bin/env python3

import argparse
import sys

from ddlcloud_generator_gke import gke_subparser

def generate(args: argparse.Namespace):
    pass

parser = argparse.ArgumentParser(prog="gke_test")
subparser = parser.add_subparsers(title="Commands", metavar="{command}")
common_args = argparse.ArgumentParser(add_help=False)
common_args.add_argument("--upgrade", help="Upgrade from existing file", action="store_true")
common_args.add_argument("--deploy-id", help="Name for deployment", required=True)
gke_subparser(subparser, [common_args]).set_defaults(command=True)
args = parser.parse_args()

if not getattr(args, "command", None):
    parser.print_help()
    sys.exit(0)

tf_module = args.generator(args, {})

print(tf_module)
