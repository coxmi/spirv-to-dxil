// glsl fragment shader with true bindless: unsized descriptor arrays of
// textures and samplers indexed by a nonuniform value from an ssbo.
// lowers to: spv OpTypeRuntimeArray + ShaderNonUniformEXT, hlsl
// NonUniformResourceIndex + unsized arrays, msl argument-buffer tier 2,
// dxil CreateHandleFromHeap (descriptor-heap indexing).

#version 450
precision highp float;
#extension GL_EXT_nonuniform_qualifier : require
#extension GL_EXT_samplerless_texture_functions : require

layout(location = 0) in vec2 vUv;
layout(location = 0) out vec4 outColor;
layout(set = 0, binding = 0) uniform texture2D tex[];
layout(set = 0, binding = 1) uniform sampler smp[];
layout(set = 0, binding = 2) buffer BindlessIdx {
    uint id;
} b;

void main() {
    uint idx = b.id;
    vec3 c = texture(sampler2D(tex[nonuniformEXT(idx)], smp[nonuniformEXT(idx)]), vUv).rgb;
    outColor = vec4(c, 1.0);
}