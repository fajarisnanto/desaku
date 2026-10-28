shader_type canvas_item;
render_mode unshaded;
uniform vec2 uv_origin;
uniform vec2 uv_size;
uniform float phase = 0.0;
uniform float walking = 0.0;

// Continuous puppet gait: breathing, alternating steps and cloth follow-through.
void vertex() {
    vec2 local_uv = (UV - uv_origin) / uv_size;
    float legs = smoothstep(0.66, 0.96, local_uv.y);
    float side = tanh((local_uv.x - 0.5) * 14.0);
    float stride = sin(phase) * side;
    VERTEX.x += walking * (legs * stride * 2.1 + sin(phase) * (1.0-legs) * 0.7);
    VERTEX.y -= walking * (legs * max(0.0,stride) * 3.0 + (1.0-legs) * abs(sin(phase)) * 1.1);
    VERTEX.x += sin(phase*0.5+local_uv.y*3.0) * 0.3 * (1.0-legs);
    VERTEX.y -= sin(phase*0.25) * 0.45 * (1.0-legs) * (1.0-walking);
}
