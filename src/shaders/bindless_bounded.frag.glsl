// glsl fragment shader indexing a bounded array of separate textures by a
// value read from an ssbo at runtime (dynamic, non-loop, non-constant index).
// the conservative "bindless-lite": sized array, no nonuniform qualifier.
// battery of array-of-textures + separated sampler with a runtime index.

#version 450
precision highp float;
#extension GL_EXT_samplerless_texture_functions : require

layout(location = 0) in vec2 vUv;
layout(location = 0) out vec4 outColor;
layout(set = 0, binding = 0) uniform texture2D tex[8];
layout(set = 0, binding = 1) uniform sampler smp;
layout(set = 0, binding = 2) buffer BindlessIdx {
    uint id;
} b;

void main() {
    uint idx = b.id % 8;
    vec3 c = texture(sampler2D(tex[idx], smp), vUv).rgb;
    outColor = vec4(c, 1.0);
}