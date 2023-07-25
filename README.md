# py-nod
Python 3.8 bindings for the [NOD](https://gitlab.axiodl.com/AxioDL/nod), a library for traversing, dumping, and authoring
GameCube and Wii optical disc images.


## Usage

### Unpacking
```python
import nod

def progress_callback(path, progress):
    if args.verbose:
        print("Extraction {:.0%} Complete; Current node: {}".format(progress, path))

context = nod.ExtractionContext()
context.set_progress_callback(progress_callback)

try:
    disc, is_wii = nod.open_disc_from_image("game.iso")
    data_partition = disc.get_data_partition()
    if not data_partition:
        raise RuntimeError("Could not find a data partition in the disc.")
    data_partition.extract_to_directory("dir_out", context)
except RuntimeError as e:
    raise Exception("Could not extract disc at 'game.iso' to 'dir_out': {}".format(e))

```

### Packing

```python
import nod

if nod.DiscBuilderGCN.calculate_total_size_required("dir_out") is None:
    raise Exception("Image built with given directory would pass the maximum size.")

def fprogress_callback(progress: float, name: str, bytes: int):
    print("\r" + " " * 100, end="")
    print("\r{:.0%} {} {} B".format(progress, name, bytes), flush=True)

disc_builder = nod.DiscBuilderGCN("game.iso", fprogress_callback)
try:
    disc_builder.build_from_directory("dir_out")    
except RuntimeError as e:
    raise Exception("Failure building the image: {}".format(e))


```
