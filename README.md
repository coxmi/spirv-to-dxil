# spirv\_to\_dxil

SPIR-V to DXIL converter built from [mesa](https://gitlab.freedesktop.org/mesa/mesa) source, packaged for use in zig as an individual component.


## Use pre-built libraries

Download the tarball for your target from [releases](https://github.com/coxmi/spirv-to-dxil/releases).
Each tarball contains:

```sh
# header files
include/spirv_to_dxil.h
include/dxil_versions.h

# library file (lib/spirv_to_dxil.lib on windows)
lib/libspirv_to_dxil.a
```


## Use as a zig dependency

Fetch the package and give the bindings module to your build:

```sh
zig fetch --save git+https://github.com/coxmi/spirv-to-dxil.git
```

```zig
// build.zig
const spirv_to_dxil = b.dependency("spirv_to_dxil", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("spirv_to_dxil", spirv_to_dxil.module("spirv_to_dxil"));
exe.root_module.linkLibrary(spirv_to_dxil.artifact("spirv_to_dxil"));
```

In your program:

```zig
const spirv_to_dxil = @import("spirv_to_dxil");

// bytes
const dxil = try spirv_to_dxil.convert(allocator, spv_bytes, .vertex, .{});
defer allocator.free(dxil);

// file
const dxil = try spirv_to_dxil.convertFile(allocator, io, "shader.spv", .fragment, .{});
defer allocator.free(dxil);
```


## Updating mesa

The mesa source is vendored in `mesa/` and generated files live in `mesa_generated/`.


To update manually:

```bash
# use uv/venv for installing dependencies
uv venv
uv pip install mako pyyaml

# grab mesa source (uses latest tag by default)
# use e.g. `./mesa-vendor mesa-26.2.2` for a specific mesa version
./mesa-vendor

# regenerate required files
source .venv/bin/activate
./mesa-generate
deactivate

# build
zig build -Doptimize=ReleaseFast
```

## License

Mesa is licensed under the MIT license. See `mesa/src/compiler/nir/nir.h` for details.
