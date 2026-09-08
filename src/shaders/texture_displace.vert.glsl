// glsl vertex shader showing non-combined (samplerless) texture sampling
// in the vertex stage via GL_EXT_samplerless_texture_functions. separate
// texture + sampler resources, fused at the call site only. exercises the
// vertex-stage access path through glslang -> spirv-cross to hlsl/metal.

#version 450
precision highp float;
#extension GL_EXT_samplerless_texture_functions : require

layout(location = 0) in vec3 aPos;
layout(location = 1) in vec2 aUv;
layout(location = 0) out vec2 vUv;

layout(set = 0, binding = 0) uniform texture2D heightTex;
layout(set = 0, binding = 1) uniform sampler heightSmp;
layout(set = 0, binding = 2) uniform Uniforms {
    mat4 mvp;
    float amplitude;
} u;

void main() {
    float h = texture(sampler2D(heightTex, heightSmp), aUv).r * u.amplitude;
    vec3 p = aPos + vec3(0.0, h, 0.0);
    vUv = aUv;
    gl_Position = u.mvp * vec4(p, 1.0);
}