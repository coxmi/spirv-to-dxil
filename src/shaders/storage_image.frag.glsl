// glsl fragment shader reading a readonly rgba32f storage image. a separate
// image (not sampler-based) that must lower to spirv/hlsl/metal.

#version 450
precision highp float;

layout(set = 0, binding = 0, rgba32f) readonly uniform image2D inputImg;
layout(location = 0) out vec4 outColor;

void main() {
    ivec2 c = ivec2(gl_FragCoord.xy);
    outColor = imageLoad(inputImg, c);
}