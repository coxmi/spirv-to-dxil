// glsl blinn-phong fragment shader with a texture and a light loop. shows
// the parallel glslang+spirv-cross path handled by shade.

#version 450
precision highp float;

layout(location = 0) in vec3 vNormal;
layout(location = 1) in vec3 vWorldPos;
layout(location = 2) in vec2 vUv;
layout(location = 0) out vec4 outColor;

layout(set = 0, binding = 0) uniform sampler2D albedoTex;
layout(set = 0, binding = 1) uniform Uniforms {
    vec3 cameraPos;
    vec3 lightDir;
    vec3 lightColor;
} u;

void main() {
    vec3 albedo = texture(albedoTex, vUv).rgb;
    vec3 N = normalize(vNormal);
    vec3 L = normalize(-u.lightDir);
    vec3 V = normalize(u.cameraPos - vWorldPos);
    vec3 H = normalize(L + V);
    float ndotl = max(dot(N, L), 0.0);
    float ndoth = pow(max(dot(N, H), 0.0), 32.0);
    vec3 diff = albedo * ndotl;
    vec3 spec = u.lightColor * ndoth;
    outColor = vec4(diff + spec, 1.0);
}
