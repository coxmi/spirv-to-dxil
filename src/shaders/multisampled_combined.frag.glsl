// glsl fragment shader with a combined, multisampled texture. the implicit
// sampler version of multisampled.frag.glsl.

#version 450
precision highp float;

layout(location = 0) out vec4 outColor;
layout(set = 0, binding = 0) uniform sampler2DMS msTex2;

void main() {
    ivec2 c = ivec2(gl_FragCoord.xy);
    outColor = texelFetch(msTex2, c, 0);
}