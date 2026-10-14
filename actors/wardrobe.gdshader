shader_type spatial;
render_mode cull_back;
uniform float impact = 0.0;
uniform vec4 skin_tone : source_color;
uniform vec4 shirt_tone : source_color;
uniform vec4 hair_tone : source_color;
uniform vec4 trouser_tone : source_color;
uniform vec4 shoe_tone : source_color;
uniform float sleeve_style = 0.0;
varying vec3 rest_point;
void vertex() { rest_point = VERTEX; }
void fragment() {
 vec3 c = COLOR.rgb;
 if (c.r > 0.25 && c.g < 0.22 && c.b < 0.12) c = skin_tone.rgb;
 else if (c.b > 0.3 && c.r < 0.1) {
  c = shirt_tone.rgb;
  if (sleeve_style > 0.5 && abs(rest_point.x)>0.34 && rest_point.y<1.43) c = skin_tone.rgb;
 }
 else if (c.b > 0.045 && c.b < 0.06 && c.r < 0.03) c = trouser_tone.rgb;
 else if (c.b >= 0.06 && c.b < 0.08 && c.r < 0.07) c = shoe_tone.rgb;
 else if (c.r < 0.022 && c.g < 0.02 && c.b < 0.02) c = hair_tone.rgb;
 if (rest_point.y>0.14 && rest_point.y<0.98 && abs(rest_point.x)<0.28) c=trouser_tone.rgb;
 if (rest_point.y>=0.98 && rest_point.y<1.52 && abs(rest_point.x)<0.23) c=shirt_tone.rgb;
 ALBEDO = mix(c, vec3(1.0,0.22,0.15), impact * 0.55);
 ROUGHNESS = 0.83;
}
