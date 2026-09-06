# spirv\_to\_dxil

SPIR-V to DXIL converter built from [mesa](https://gitlab.freedesktop.org/mesa/mesa) source, packaged for use in zig.


## Use pre-built libraries

Download the tarball for your target from [releases](https://github.com/coxmi/spirv_to_dxil/releases).
Each tarball contains:

```sh
# header files
include/spirv_to_dxil.h
include/dxil_versions.h

# library file (lib/spirv_to_dxil.lib on windows)
lib/libspirv_to_dxil.a
```


## Updating mesa

The mesa source is vendored in `mesa/` and generated files live in `mesa_generated/`.


To update manually:

```bash
# install dependencies
uv venv
uv pip install mako pyyaml
source .venv/bin/activate

# grab mesa source (uses latest tag by default)
# use `./mesa-vendor mesa-25.1.0` for a specific tag
./mesa-vendor

# regenerate required files
./mesa-generate

# build
zig build -Doptimize=ReleaseFast

# exit venv shell
deactivate
```

## License

Mesa is licensed under the MIT license. See `mesa/src/compiler/nir/nir.h` for details.
