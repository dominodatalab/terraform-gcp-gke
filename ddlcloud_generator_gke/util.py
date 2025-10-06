#!/usr/bin/env python3

import argparse
import sys

import yaml

from ddlcloud_generator_gke import GKEGenerator


def parse_args(test_args: list | None = None):
    parser = argparse.ArgumentParser(prog="gke_test")
    subparser = parser.add_subparsers(title="Commands", metavar="{command}")
    _gen_args_parser = subparser.add_parser("gke", help="gke Terraform Generator")
    _gen_args_parser.add_argument("--upgrade", help="Upgrade from existing file", action="store_true")
    _gen_args_parser.add_argument("--deploy-id", help="Name for deployment", required=True)
    _gen_args_parser.add_argument("--file", help="Load existing file")
    _gen_args_parser.add_argument(
        "--kubeconfig-path", help="Override path for generated kubeconfig", default="kubeconfig"
    )
    _gen_args_parser.add_argument("--module-version", help="Version for terraform module", default="v3.1.3")
    GKEGenerator.add_specific_args(_gen_args_parser)
    _gen_args_parser.set_defaults(command=True)

    args = parser.parse_args(test_args)

    if not getattr(args, "command", None):
        parser.print_help()
        sys.exit(0)

    return args


def main():
    args = parse_args()

    existing_config = None
    if args.file:
        with open(args.file) as f:
            existing_config = yaml.safe_load(f)

    tf_module = args.generator(args, existing_config)

    print(yaml.safe_dump(tf_module.model_dump(by_alias=True)))


if __name__ == "__main__":
    main()
