// glsl fragment shader with a multisampled texture (texture2DMS) used via
// texelFetch. samplerless form (extension) — needs the dummy-sampler for
// hlsl combined pass.

#version 450
precision highp float;
#extension GL_EXT_samplerless_texture_functions : require

layout(location = 0) out vec4 outColor;
layout(set = 0, binding = 0) uniform texture2DMS msTex;
layout(set = 0, binding = 1) uniform sampler msSmp;

void main() {
    ivec2 c = ivec2(gl_FragCoord.xy);
    vec4 a = texelFetch(msTex, c, 0);
    vec4 b = texelFetch(msTex, c, 1);
    outColor = a + b;
}