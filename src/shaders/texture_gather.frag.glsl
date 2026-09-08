// glsl fragment shader using textureGather on a combined sampler. lower to
// all targets.

#version 450
precision highp float;

layout(location = 0) in vec2 vUv;
layout(location = 0) out vec4 outColor;
layout(set = 0, binding = 0) uniform sampler2D albedoTexG;

void main() {
    outColor = textureGather(albedoTexG, vUv, 1);
}