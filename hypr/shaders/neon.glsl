#version 300 es
// Balanced neon glow - 6 circular samples
precision mediump float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

const float PI = 3.14159265;
const vec2 texelSize = vec2(0.0008, 0.0014);
const float GLOW_RADIUS = 1.8;
const float GLOW_INTENSITY = 0.35;

void main() {
    vec4 original = texture(tex, v_texcoord);
    vec3 glow = vec3(0.0);

    // 6 samples in a circle
    for (int i = 0; i < 6; i++) {
        float angle = PI * float(i) / 3.0;
        vec2 offset = vec2(cos(angle), sin(angle)) * GLOW_RADIUS * texelSize;
        glow += texture(tex, v_texcoord + offset).rgb;
    }
    glow /= 6.0;

    // Soft threshold for glow
    float brightness = dot(glow, vec3(0.299, 0.587, 0.114));
    glow *= smoothstep(0.12, 0.35, brightness) * 1.2;

    fragColor = vec4(original.rgb + glow * GLOW_INTENSITY, original.a);
}
