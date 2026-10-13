shader_type spatial;
render_mode cull_back;
uniform sampler2D face_albedo : source_color, filter_linear_mipmap;
uniform float impact = 0.0;
void fragment() {
 float rest_y = UV2.y;
 vec3 base = COLOR.rgb;
 if (rest_y > 0.14 && rest_y < 0.98) base = vec3(0.64,0.46,0.29);
 if (rest_y > 1.747 && COLOR.a < 0.1) base = vec3(0.025,0.018,0.014);
 vec3 c = mix(base, texture(face_albedo, clamp(UV,vec2(0.001),vec2(0.999))).rgb,COLOR.a);
 ALBEDO = mix(c,vec3(1.0,0.22,0.15),impact*0.55);
 ROUGHNESS = 0.95;
}
