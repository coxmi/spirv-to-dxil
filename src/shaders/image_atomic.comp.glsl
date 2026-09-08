// glsl compute shader showing a read-write storage image + imageAtomicAdd to
// a uimage2D counter. storage images with atomics must lower to all targets.

#version 450
precision highp float;

layout(local_size_x = 64) in;
layout(set = 0, binding = 0, r32ui) uniform uimage2D counter;
layout(set = 0, binding = 1) buffer Data {
    uint values[];
} buf;

void main() {
    uint i = gl_GlobalInvocationID.x;
    uint prev = imageAtomicAdd(counter, ivec2(0, 0), 1u);
    buf.values[i] = prev;
}