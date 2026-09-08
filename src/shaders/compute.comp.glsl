// glsl compute shader over a storage buffer. avoids std140 blocks so it
// lowers to all targets.

#version 450
precision highp float;

layout(local_size_x = 64) in;
layout(set = 0, binding = 0) buffer Data {
    float values[];
} buf;

void main() {
    uint i = gl_GlobalInvocationID.x;
    buf.values[i] = buf.values[i] * 2.0 + 1.0;
}
