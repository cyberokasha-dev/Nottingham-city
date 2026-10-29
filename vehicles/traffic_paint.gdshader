shader_type spatial;
render_mode cull_back;
uniform sampler2D colormap : source_color, filter_nearest;
uniform vec4 paint : source_color = vec4(0.2,0.4,0.8,1.0);
void fragment() {
 vec3 c=texture(colormap,UV).rgb;
 float hi=max(c.r,max(c.g,c.b));
 float lo=min(c.r,min(c.g,c.b));
 ALBEDO=(hi>0.82 && lo>0.74) ? vec3(0.12,0.22,0.3) : ((hi-lo>0.18 && hi>0.25) ? paint.rgb*(0.65+hi*0.35) : c);
 METALLIC=hi-lo>0.18 ? 0.45 : 0.12;
 ROUGHNESS=0.35;
}
