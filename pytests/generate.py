#!/usr/bin/env python3

import argparse
import sys
from os import path
from os.path import dirname, join, normpath
from subprocess import run
from tempfile import TemporaryDirectory

from ddlcloud_tf_base_schemas import TFBackendConfig, TFLocalBackend
from pydantic_yaml import to_yaml_str

from ddlcloud_generator_gke import gke_subparser

module_root = normpath(join(dirname(path.realpath(__file__)), ".."))


def validate(module):
    with TemporaryDirectory() as tmpdir:
        module.backend = TFBackendConfig(type="local", config=TFLocalBackend(path=path.join(tmpdir, "the.tfstate")))
        module.module.gke_cluster.source = module_root
        with open(path.join(tmpdir, "main.tf.json"), "w") as f:
            f.write(module.render_to_json())
        run(["terraform", "init"], cwd=tmpdir, check=True)
        run(["terraform", "validate"], cwd=tmpdir, check=True)


def parse_args(test_args: list | None = None):
    parser = argparse.ArgumentParser(prog="gke_test")
    subparser = parser.add_subparsers(title="Commands", metavar="{command}")
    common_args = argparse.ArgumentParser(add_help=False)
    common_args.add_argument("--upgrade", help="Upgrade from existing file", action="store_true")
    common_args.add_argument("--deploy-id", help="Name for deployment", required=True)
    gke_subparser(subparser, [common_args]).set_defaults(command=True)

    args = parser.parse_args(test_args)

    if not getattr(args, "command", None):
        parser.print_help()
        sys.exit(0)

    return args


def main():
    args = parse_args()

    tf_module = args.generator(args, {})

    # print(yaml.safe_dump(tf_module.model_dump(by_alias=True)))
    print(to_yaml_str(tf_module, add_comments=True, by_alias=True))


if __name__ == "__main__":
    main()
