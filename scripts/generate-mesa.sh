#!/bin/bash
set -euo pipefail

# generates Mako-templated C files from Mesa source

# requires: python3, mako (pip install mako)
# Run from the repo root

MESA_DIR="${MESA_DIR:-mesa}"
OUT_DIR="${OUT_DIR:-mesa_generated}"

PYTHON="${PYTHON:-python3}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
if [ -x "$REPO_ROOT/.venv/bin/python" ]; then
  PYTHON="$REPO_ROOT/.venv/bin/python"
fi

NIR_DIR="$MESA_DIR/src/compiler/nir"
SPIRV_DIR="$MESA_DIR/src/compiler/spirv"
UTIL_DIR="$MESA_DIR/src/util"
FORMAT_DIR="$UTIL_DIR/format"
COMPILER_DIR="$MESA_DIR/src/compiler"
MS_DIR="$MESA_DIR/src/microsoft/compiler"

mkdir -p "$OUT_DIR"

echo "Generating NIR opcodes..."
PYTHONPATH="$NIR_DIR:$COMPILER_DIR:$SPIRV_DIR:$MS_DIR:$UTIL_DIR:$FORMAT_DIR:$MESA_DIR/src" \
  "$PYTHON" "$NIR_DIR/nir_opcodes_h.py" > "$OUT_DIR/nir_opcodes.h"

PYTHONPATH="$NIR_DIR:$COMPILER_DIR:$SPIRV_DIR:$MS_DIR:$UTIL_DIR:$FORMAT_DIR:$MESA_DIR/src" \
  "$PYTHON" "$NIR_DIR/nir_opcodes_c.py" > "$OUT_DIR/nir_opcodes.c"

echo "Generating NIR intrinsics..."
PYTHONPATH="$NIR_DIR:$COMPILER_DIR:$SPIRV_DIR:$MS_DIR:$UTIL_DIR:$FORMAT_DIR:$MESA_DIR/src" \
  "$PYTHON" "$NIR_DIR/nir_intrinsics_h.py" --out "$OUT_DIR/nir_intrinsics.h"

PYTHONPATH="$NIR_DIR:$COMPILER_DIR:$SPIRV_DIR:$MS_DIR:$UTIL_DIR:$FORMAT_DIR:$MESA_DIR/src" \
  "$PYTHON" "$NIR_DIR/nir_intrinsics_c.py" --out "$OUT_DIR/nir_intrinsics.c"

PYTHONPATH="$NIR_DIR:$COMPILER_DIR:$SPIRV_DIR:$MS_DIR:$UTIL_DIR:$FORMAT_DIR:$MESA_DIR/src" \
  "$PYTHON" "$NIR_DIR/nir_intrinsics_indices_h.py" --out "$OUT_DIR/nir_intrinsics_indices.h"

echo "Generating NIR builder opcodes..."
PYTHONPATH="$NIR_DIR:$COMPILER_DIR:$SPIRV_DIR:$MS_DIR:$UTIL_DIR:$FORMAT_DIR:$MESA_DIR/src" \
  "$PYTHON" "$NIR_DIR/nir_builder_opcodes_h.py" > "$OUT_DIR/nir_builder_opcodes.h"

echo "Generating NIR constant expressions..."
PYTHONPATH="$NIR_DIR:$COMPILER_DIR:$SPIRV_DIR:$MS_DIR:$UTIL_DIR:$FORMAT_DIR:$MESA_DIR/src" \
  "$PYTHON" "$NIR_DIR/nir_constant_expressions.py" > "$OUT_DIR/nir_constant_expressions.c"

echo "Generating NIR opt algebraic..."
PYTHONPATH="$NIR_DIR:$COMPILER_DIR:$SPIRV_DIR:$MS_DIR:$UTIL_DIR:$FORMAT_DIR:$MESA_DIR/src" \
  "$PYTHON" "$NIR_DIR/nir_opt_algebraic.py" --out "$OUT_DIR/nir_opt_algebraic.c"

echo "Generating DXIL NIR algebraic..."
PYTHONPATH="$NIR_DIR:$COMPILER_DIR:$SPIRV_DIR:$MS_DIR:$UTIL_DIR:$FORMAT_DIR:$MESA_DIR/src" \
  "$PYTHON" "$MS_DIR/dxil_nir_algebraic.py" -p "$NIR_DIR" > "$OUT_DIR/dxil_nir_algebraic.c"

echo "Generating SPIRV info..."
mkdir -p "$OUT_DIR/spirv"
PYTHONPATH="$NIR_DIR:$COMPILER_DIR:$SPIRV_DIR:$MS_DIR:$UTIL_DIR:$FORMAT_DIR:$MESA_DIR/src" \
  "$PYTHON" "$SPIRV_DIR/spirv_info_gen.py" \
    --json "$SPIRV_DIR/spirv.core.grammar.json" \
    --out-h "$OUT_DIR/spirv/spirv_info.h" \
    --out-c "$OUT_DIR/spirv/spirv_info.c"

echo "Generating VTN gather types..."
PYTHONPATH="$NIR_DIR:$COMPILER_DIR:$SPIRV_DIR:$MS_DIR:$UTIL_DIR:$FORMAT_DIR:$MESA_DIR/src" \
  "$PYTHON" "$SPIRV_DIR/vtn_gather_types_c.py" \
    "$SPIRV_DIR/spirv.core.grammar.json" \
    "$OUT_DIR/vtn_gather_types.c"

echo "Generating VTN generator IDs..."
PYTHONPATH="$NIR_DIR:$COMPILER_DIR:$SPIRV_DIR:$MS_DIR:$UTIL_DIR:$FORMAT_DIR:$MESA_DIR/src" \
  "$PYTHON" "$SPIRV_DIR/vtn_generator_ids_h.py" \
    "$SPIRV_DIR/spir-v.xml" \
    "$OUT_DIR/vtn_generator_ids.h"

echo "Generating builtin types..."
PYTHONPATH="$NIR_DIR:$COMPILER_DIR:$SPIRV_DIR:$MS_DIR:$UTIL_DIR:$FORMAT_DIR:$MESA_DIR/src" \
  "$PYTHON" "$COMPILER_DIR/builtin_types_h.py" "$OUT_DIR/builtin_types.h"

PYTHONPATH="$NIR_DIR:$COMPILER_DIR:$SPIRV_DIR:$MS_DIR:$UTIL_DIR:$FORMAT_DIR:$MESA_DIR/src" \
  "$PYTHON" "$COMPILER_DIR/builtin_types_c.py" "$OUT_DIR/builtin_types.c"

echo "Generating format sRGB..."
PYTHONPATH="$NIR_DIR:$COMPILER_DIR:$SPIRV_DIR:$MS_DIR:$UTIL_DIR:$FORMAT_DIR:$MESA_DIR/src" \
  "$PYTHON" "$UTIL_DIR/format_srgb.py" > "$OUT_DIR/format_srgb.c"

echo "Generating format table..."
PYTHONPATH="$NIR_DIR:$COMPILER_DIR:$SPIRV_DIR:$MS_DIR:$UTIL_DIR:$FORMAT_DIR:$MESA_DIR/src" \
  "$PYTHON" "$FORMAT_DIR/u_format_table.py" "$FORMAT_DIR/u_format.yaml" > "$OUT_DIR/u_format_table.c"

echo "Generating format pack header..."
PYTHONPATH="$NIR_DIR:$COMPILER_DIR:$SPIRV_DIR:$MS_DIR:$UTIL_DIR:$FORMAT_DIR:$MESA_DIR/src" \
  "$PYTHON" "$FORMAT_DIR/u_format_table.py" --header "$FORMAT_DIR/u_format.yaml" > "$OUT_DIR/u_format_pack.h"

echo "Generating format enums header..."
mkdir -p "$OUT_DIR/util/format"
PYTHONPATH="$NIR_DIR:$COMPILER_DIR:$SPIRV_DIR:$MS_DIR:$UTIL_DIR:$FORMAT_DIR:$MESA_DIR/src" \
  "$PYTHON" "$FORMAT_DIR/u_format_table.py" --enums "$FORMAT_DIR/u_format.yaml" > "$OUT_DIR/util/format/u_format_gen.h"

echo "Done. Generated files in $OUT_DIR/"
ls -la "$OUT_DIR/"
