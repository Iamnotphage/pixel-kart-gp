shader_type canvas_item;
uniform sampler2D track_map : filter_nearest, repeat_disable;
uniform vec2 camera = vec2(1024.0);
uniform vec2 forward_dir = vec2(0.0,1.0);
uniform float horizon = 0.30;
void fragment() {
 float sy = UV.y * 360.0;
 float depth = 6500.0 / max(sy - horizon*360.0, 1.0);
 vec2 right_dir = vec2(forward_dir.y, -forward_dir.x);
 vec2 world = camera + forward_dir*depth + right_dir*((UV.x*640.0-320.0)*depth/330.0);
 vec2 tex_uv = world / 2048.0;
 vec3 col = texture(track_map,tex_uv).rgb;
 if (tex_uv.x<0.0 || tex_uv.y<0.0 || tex_uv.x>1.0 || tex_uv.y>1.0) { col=vec3(0.06,0.20,0.20); }
 float haze = clamp((depth-500.0)/1800.0,0.0,0.75);
 COLOR=vec4(mix(col, vec3(0.47,0.72,0.73), haze), step(horizon,UV.y));
}
