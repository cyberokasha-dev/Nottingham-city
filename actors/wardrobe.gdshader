shader_type spatial;
render_mode cull_back;
uniform float impact = 0.0;
uniform vec4 skin_tone : source_color;
uniform vec4 shirt_tone : source_color;
uniform vec4 hair_tone : source_color;
void fragment() {
 vec3 c = COLOR.rgb;
 if (c.r > 0.25 && c.g < 0.22 && c.b < 0.12) c = skin_tone.rgb;
 else if (c.b > 0.3 && c.r < 0.1) c = shirt_tone.rgb;
 else if (c.r < 0.022 && c.g < 0.02 && c.b < 0.02) c = hair_tone.rgb;
 ALBEDO = mix(c, vec3(1.0,0.22,0.15), impact * 0.55);
 ROUGHNESS = 0.83;
}
