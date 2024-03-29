import argparse
from pathlib import Path

import nod


class Commands:
    def __init__(self, args):
        self.args = args

    def fprogress_callback(self, progress: float, name: str, bytes: int):
        if self.args.verbose:
            print("\r" + " " * 100, end="")
            print(f"\r{progress:.0%} {name} {bytes} B", flush=True)

    def extract(self):
        args = self.args

        def progress_callback(path, progress):
            if args.verbose:
                print(f"Extraction {progress:.0%} Complete; Current node: {path}")

        context = nod.ExtractionContext()
        context.set_progress_callback(progress_callback)

        try:
            disc, is_wii = nod.open_disc_from_image(args.image_in)
            data_partition = disc.get_data_partition()
            if not data_partition:
                raise RuntimeError("Could not find a data partition in the disc.")
            data_partition.extract_to_directory(args.directory_out, context)

        except RuntimeError as e:
            if args.verbose:
                print(f"Could not extract disc at '{args.image_in}' to '{args.directory_out}': {e}")
            raise SystemExit(1)

    def makegcn(self):
        filesystem_root = self.args.filesystem_root

        if not Path(filesystem_root).is_dir():
            print(f"Error, '{filesystem_root}' is not a directory.")
            raise SystemExit(1)

        if nod.DiscBuilderGCN.calculate_total_size_required(filesystem_root) is None:
            print("Image built with given directory would pass the maximum size.")
            raise SystemExit(2)

        disc_builder = nod.DiscBuilderGCN(self.args.image_out, self.fprogress_callback)
        try:
            disc_builder.build_from_directory(filesystem_root)
            if self.args.verbose:
                print()
        except RuntimeError as e:
            print(
                f"Error when trying to create an ISO at '{self.args.image_out}' with '{filesystem_root}' as input: {e}"
            )
            raise SystemExit(3)

    def execute(self):
        getattr(self, self.args.command)()


def create_parsers():
    parser = argparse.ArgumentParser()
    sub_parsers = parser.add_subparsers(dest="command")

    # Extract
    extract_parser = sub_parsers.add_parser("extract", help="Extract an iso")
    extract_parser.add_argument("image_in", type=str)
    extract_parser.add_argument("directory_out", type=str)
    extract_parser.add_argument("-v", "--verbose", action="store_true")

    # Make GCN
    make_gcn_parser = sub_parsers.add_parser("makegcn", help="Create a Nintendo GameCube ISO from files.")
    make_gcn_parser.add_argument("filesystem_root", type=str)
    make_gcn_parser.add_argument("image_out", type=str)
    make_gcn_parser.add_argument("-v", "--verbose", action="store_true")

    return parser


def parse_args(parser):
    args = parser.parse_args()
    if args.command is None:
        parser.print_help()
        raise SystemExit(1)

    Commands(args).execute()


if __name__ == "__main__":
    parse_args(create_parsers())
