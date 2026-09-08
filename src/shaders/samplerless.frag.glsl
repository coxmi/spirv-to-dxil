// glsl fragment shader using non-combined (samplerless) textures via
// GL_EXT_samplerless_texture_functions. texture + sampler declared as
// separate resources and fused only at the call site, matching the
// hlsl/metal model that spirv-cross emits.

#version 450
precision highp float;
#extension GL_EXT_samplerless_texture_functions : require

layout(location = 0) in vec2 vUv;
layout(location = 0) out vec4 outColor;

layout(set = 0, binding = 0) uniform texture2D albedoTex;
layout(set = 0, binding = 1) uniform sampler albedoSmp;
layout(set = 0, binding = 2) uniform Uniforms {
    vec3 color;
} u;

void main() {
    vec3 albedo = texture(sampler2D(albedoTex, albedoSmp), vUv).rgb;
    outColor = vec4(albedo * u.color, 1.0);
}