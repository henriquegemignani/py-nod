import argparse

import nod


class Commands:
    @classmethod
    def extract(cls, args):
        result = nod.open_disc_from_image(args.image_in)
        if not result:
            if args.verbose:
                print("Could not open disc from '{}'.".format(args.image_in))
            raise SystemExit(1)

        disc, is_wii = result
        data_partition = disc.get_data_partition()
        if not data_partition:
            if args.verbose:
                print("Could not find a data partition in the disc.")
            raise SystemExit(2)

        def progress_callback(path, progress):
            if args.verbose:
                print("Extraction {:.0%} Complete; Current node: {}".format(progress, path))

        context = nod.ExtractionContext()
        context.set_progress_callback(progress_callback)

        if not data_partition.extract_to_directory(args.directory_out, context):
            if args.verbose:
                print("Could not extract to '{}'".format(args.directory_out))


def create_parsers():
    parser = argparse.ArgumentParser()
    sub_parsers = parser.add_subparsers(dest="command")

    # Extract
    extract_parser = sub_parsers.add_parser(
        "extract",
        help="Extract an iso"
    )
    extract_parser.add_argument("image_in", type=str)
    extract_parser.add_argument("directory_out", type=str)
    extract_parser.add_argument("-v", "--verbose", action="store_true")

    return parser


def parse_args(parser):
    args = parser.parse_args()
    if args.command is None:
        parser.print_help()
        raise SystemExit(1)

    getattr(Commands, args.command)(args)


parse_args(create_parsers())
