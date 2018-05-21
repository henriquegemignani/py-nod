# py-nod
Python 3.6 bindings for the [NOD](https://gitlab.axiodl.com/AxioDL/nod), a library for traversing, dumping, and authoring
GameCube and Wii optical disc images.


## Usage

### Unpacking
```python
import nod

result = nod.open_disc_from_image("game.iso")
if not result:
    raise Exception("Could not open game.iso")

disc, is_wii = result

data_partition = disc.get_data_partition()
if not data_partition:
    raise Exception("Could not find a data partition in the disc.")

def progress_callback(path, progress):
    print("Extraction {:.0%} Complete; Current node: {}".format(progress, path))

context = nod.ExtractionContext()
context.set_progress_callback(progress_callback)

if not data_partition.extract_to_directory("dir_out", context):
    raise Exception("Could not extract to 'dir_out'")
```

### Packing

```python
import nod

if nod.DiscBuilderGCN.calculate_total_size_required("dir_out") == -1:
    raise Exception("Image built with given directory would pass the maximum size.")


def fprogress_callback(progress: float, name: str, bytes: int):
    print("\r" + " " * 100, end="")
    print("\r{:.0%} {} {} B".format(progress, name, bytes), flush=True)


disc_builder = nod.DiscBuilderGCN("game.iso", fprogress_callback)
ret = disc_builder.build_from_directory("dir_out")

if ret != nod.BuildResult.Success:
    raise Exception("Failure building the image: code {}".format(ret))

```