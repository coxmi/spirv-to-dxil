// glsl fragment shader sampling from an array of separate textures with a
// single sampler. needs msl 2.x (arrays of textures) which shade sets.

#version 450
precision highp float;
#extension GL_EXT_samplerless_texture_functions : require

layout(location = 0) in vec2 vUv;
layout(location = 0) out vec4 outColor;
layout(set = 0, binding = 0) uniform texture2D tex[2];
layout(set = 0, binding = 1) uniform sampler smp;

void main() {
    vec3 c = vec3(0);
    for (int i = 0; i < 2; ++i)
        c += texture(sampler2D(tex[i], smp), vUv).rgb;
    outColor = vec4(c, 1.0);
}