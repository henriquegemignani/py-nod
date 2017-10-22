import argparse

import nod


class Commands:
    @classmethod
    def extract(cls, args):
        result = nod.open_disc_from_image(args.image_in)
        if not result:
            raise SystemExit(1)
            pass

        disc, is_wii = result
        data_partition = disc.get_data_partition()

        def progress_callback(path, progress):
            if args.verbose:
                print("Current node: {}, Extraction {:.0%} Complete".format(path, progress))

        context = nod.ExtractionContext()
        context.set_progress_callback(progress_callback)

        data_partition.extract_to_directory(r"D:\wth", context)
        pass


def create_parsers():
    parser = argparse.ArgumentParser()
    sub_parsers = parser.add_subparsers(dest="command")

    # Extract
    extract_parser = sub_parsers.add_parser(
        "extract",
        help="Extract an iso"
    )
    extract_parser.add_argument("image_in", type=str)
    extract_parser.add_argument("directory_out", type=str, nargs='?')
    extract_parser.add_argument("--verbose", action="store_true")

    return parser


def parse_args(parser):
    args = parser.parse_args()
    if args.command is None:
        parser.print_help()
        raise SystemExit(1)

    getattr(Commands, args.command)(args)


parse_args(create_parsers())
