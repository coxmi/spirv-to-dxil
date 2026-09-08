// glsl fragment shader with two render targets (mrt). separate texture +
// sampler via GL_EXT_samplerless_texture_functions.

#version 450
precision highp float;
#extension GL_EXT_samplerless_texture_functions : require

layout(location = 0) in vec2 vUv;
layout(location = 0) out vec4 out0;
layout(location = 1) out vec4 out1;
layout(set = 0, binding = 0) uniform texture2D albedoTex2;
layout(set = 0, binding = 1) uniform sampler albedoSmp2;

void main() {
    vec4 c = texture(sampler2D(albedoTex2, albedoSmp2), vUv);
    out0 = c;
    out1 = vec4(c.gba, 1.0);
}