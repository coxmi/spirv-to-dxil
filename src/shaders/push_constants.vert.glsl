// glsl vertex shader using push constants (no descriptor set/ubo). must
// lower to all targets (hlsl uses a cbuffer, metal a buffer).

#version 450
precision highp float;

layout(location = 0) in vec3 aPos;
layout(location = 0) out vec4 vCol;
layout(push_constant) uniform PC {
    mat4 mvp;
    vec4 color;
} pc;

void main() {
    gl_Position = pc.mvp * vec4(aPos, 1.0);
    vCol = pc.color;
}