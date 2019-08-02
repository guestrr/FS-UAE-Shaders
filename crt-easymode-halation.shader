<?xml version="1.0" encoding="UTF-8"?>

<!--
/*
    CRT Shader by EasyMode (with Halation)
    License: GPL

    A flat CRT shader ideally for 1080p or higher displays.

    Recommended Settings:

    Video
    - Aspect Ratio:  4:3
    - Integer Scale: Off

    Shader
    - Filter: Nearest
    - Scale:  Don't Care

    Example RGB Mask Parameter Settings:

    Aperture Grille (Default)
    - Dot Width:  1
    - Dot Height: 1
    - Stagger:    0

    Lottes' Shadow Mask
    - Dot Width:  2
    - Dot Height: 1
    - Stagger:    3
*/ 

-->

<shader language="GLSL">

<vertex><![CDATA[

void main(void) {
    gl_Position = ftransform();
    gl_TexCoord[0] = gl_MultiTexCoord0;
}
]]></vertex>


<fragment scale="1.0" filter="nearest"><![CDATA[
uniform sampler2D rubyTexture;
uniform vec2 rubyTextureSize;

#define GLOW_FALLOFF 0.35
#define TAPS 4 

float kernel(float x)
{
	return exp(-GLOW_FALLOFF * x * x);
}
vec3 TL (vec3 c)
{
	return pow(c, vec3(2.4));
}

vec3 TS (vec3 c)
{
	return pow(c, vec3(0.416666));
}

void main()
{	
	vec3 col = vec3(0.0);
	float dx = 1.0/rubyTextureSize.x;
	float k;
	
	float k_total = 0.0;
	for (int i = -TAPS; i <= TAPS; i++)
		{
		k = kernel(float(i));
		k_total += k;
		col += k * TL(texture2D(rubyTexture, gl_TexCoord[0].xy + vec2(float(i) * dx, 0.0)).rgb);
		}
	gl_FragColor = vec4(TS(col / k_total), 1.0); 	
}	
]]></fragment>


<vertex><![CDATA[

void main(void) {
    gl_Position = ftransform();
    gl_TexCoord[0] = gl_MultiTexCoord0;
}
]]></vertex>


<fragment scale="1.0" filter="nearest"><![CDATA[
uniform sampler2D rubyTexture;
uniform vec2 rubyTextureSize;

#define GLOW_FALLOFF 0.35
#define TAPS 4 

float kernel(float x)
{
	return exp(-GLOW_FALLOFF * x * x);
}

vec3 TL (vec3 c)
{
	return pow(c, vec3(2.4));
}

vec3 TS (vec3 c)
{
	return pow(c, vec3(0.416666));
}

void main()
{	
	vec3 col = vec3(0.0);
	float dy = 1.0/rubyTextureSize.y;
	float k;
	
	float k_total = 0.0;
	for (int i = -TAPS; i <= TAPS; i++)
		{
		k = kernel(float(i));
		k_total += k;
		col += k * TL(texture2D(rubyTexture, gl_TexCoord[0].xy + vec2(0.0, float(i) * dy)).rgb);
		}
	gl_FragColor = vec4(TS(col / k_total), 1.0); 	
}	
]]></fragment>


<vertex><![CDATA[

void main(void) {
    gl_Position = ftransform();
    gl_TexCoord[0] = gl_MultiTexCoord0;
}
]]></vertex>


<fragment scale="1.0" filter="nearest"><![CDATA[
uniform sampler2D rubyTexture;
uniform sampler2D rubyOrigTexture;
uniform vec2 rubyTextureSize;

vec3 TL (vec3 c)
{
	return pow(c, vec3(2.4));
}

vec3 TS (vec3 c)
{
	return pow(c, vec3(0.416666));
}

void main()
{		
	vec3 diff = clamp(TL(texture2D(rubyTexture, gl_TexCoord[0].xy).rgb) - TL(texture2D(rubyOrigTexture, gl_TexCoord[0].xy).rgb), 0.0, 1.0);
	gl_FragColor = vec4(TS(diff), 1.0); 	
}	
]]></fragment>


<vertex><![CDATA[
    uniform vec2 rubyTextureSize;

    void main()
    {
        gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
        gl_TexCoord[0] = gl_MultiTexCoord0;
    }
]]></vertex>


<fragment outscale="1.0" filter="linear"><![CDATA[
uniform sampler2D rubyTexture;
uniform sampler2D rubyOrigTexture;
uniform vec2 rubyTextureSize;
uniform vec2 rubyOutputSize;
uniform vec2 rubyInputSize;
uniform int rubyFrameCount;


#define SATURATION 1.0
#define BRIGHTNESS 1.0
#define DIFFUSION 0.0
#define GAMMA_OUTPUT 2.2
#define GEOM_CORNER_SIZE 0.04
#define GEOM_CORNER_SMOOTH 150.0
#define GEOM_CURVATURE 0.035
#define GEOM_WARP 0.03
#define HALATION 0.05
#define MASK_SIZE 1.0
#define MASK_STRENGTH_MAX 0.30
#define MASK_STRENGTH_MIN 0.30
#define MASK_TYPE 1.0
#define SCANLINE_BEAM_MAX 0.75
#define SCANLINE_BEAM_MIN 0.95
#define SCANLINE_STRENGTH_MAX 0.4
#define SCANLINE_STRENGTH_MIN 0.3
#define SHARPNESS_H 0.5
#define SHARPNESS_V 0.6


#define FIX(c) max(abs(c), 1e-5)
#define PI 3.141592653589


vec4 TL (vec4 c)
{
	return pow(c, vec4(2.4));
}


float curve_distance(float x, float sharp)
{
    float x_step = step(0.5, x);
    float curve = 0.5 - sqrt(0.25 - (x - x_step) * (x - x_step)) * sign(0.5 - x);

    return mix(x, curve, sharp);
}

mat4 get_color_matrix(vec2 co, vec2 dx)
{
    return mat4(pow(texture2D(rubyOrigTexture, co -     dx), vec4(2.4)), 
	            pow(texture2D(rubyOrigTexture, co         ), vec4(2.4)),
				pow(texture2D(rubyOrigTexture, co +     dx), vec4(2.4)),
				pow(texture2D(rubyOrigTexture, co + 2.0*dx), vec4(2.4)));
}

vec4 filter_lanczos(vec4 coeffs, mat4 color_matrix)
{
    vec4 col = color_matrix * coeffs;
    vec4 sample_min = min(color_matrix[1], color_matrix[2]);
    vec4 sample_max = max(color_matrix[1], color_matrix[2]);

    col = clamp(col, sample_min, sample_max);

    return col;
}

vec3 get_scanline_weight(float pos, float beam, float strength)
{
    float weight = 1.0 - pow(cos(pos * 2.0 * PI) * 0.5 + 0.5, beam);
    
    weight = weight * strength * 2.0 + (1.0 - strength);
    
    return vec3(weight);
}

vec2 curve_coordinate(vec2 co, float curvature)
{
    vec2 curve = vec2(curvature, curvature * 0.75);
    vec2 co2 = co + co * curve - curve / 2.0;
    vec2 co_weight = vec2(co.y, co.x) * 2.0 - 1.0;

    co = mix(co, co2, co_weight * co_weight);

    return co;
}

float get_corner_weight(vec2 co, vec2 corner, float smoothfunc)
{
    float corner_weight;
    
    co = min(co, vec2(1.0) - co) * vec2(1.0, 0.75);
    co = (corner - min(co, corner));
    corner_weight = clamp((corner.x - sqrt(dot(co, co))) * smoothfunc, 0.0, 1.0);
    corner_weight = mix(1.0, corner_weight, ceil(corner.x));
    
    return corner_weight;
} 


void main(void)
{   
    vec2 tex_size = rubyTextureSize;
    vec2 midpoint = vec2(0.5, 0.5);
    float scan_offset = 0.0;

    vec2 co =  gl_TexCoord[0].xy * tex_size / rubyInputSize;
    vec2 xy = curve_coordinate(co, GEOM_WARP);
    float corner_weight = get_corner_weight(curve_coordinate(co, GEOM_CURVATURE), vec2(GEOM_CORNER_SIZE), GEOM_CORNER_SMOOTH);

    xy *= rubyInputSize / tex_size;

    vec2 dx = vec2(1.0 / tex_size.x, 0.0);
    vec2 dy = vec2(0.0, 1.0 / tex_size.y);
    vec2 pix_co = xy * tex_size - midpoint;
    vec2 tex_co = (floor(pix_co) + midpoint) / tex_size;
    vec2 dist = fract(pix_co);
    float curve_x, curve_y;
    vec3 col, col2, diff;

    curve_x = curve_distance(dist.x, SHARPNESS_H * SHARPNESS_H);
    curve_y = curve_distance(dist.y, SHARPNESS_V * SHARPNESS_V);

    vec4 coeffs_x = PI * vec4(1.0 + curve_x, curve_x, 1.0 - curve_x, 2.0 - curve_x);
    vec4 coeffs_y = PI * vec4(1.0 + curve_y, curve_y, 1.0 - curve_y, 2.0 - curve_y);

    coeffs_x = FIX(coeffs_x);
    coeffs_x = 2.0 * sin(coeffs_x) * sin(coeffs_x / 2.0) / (coeffs_x * coeffs_x);
    coeffs_x /= dot(coeffs_x, vec4(1.0));

    coeffs_y = FIX(coeffs_y);
    coeffs_y = 2.0 * sin(coeffs_y) * sin(coeffs_y / 2.0) / (coeffs_y * coeffs_y);
    coeffs_y /= dot(coeffs_y, vec4(1.0));

    mat4 color_matrix;

    color_matrix[0] = filter_lanczos(coeffs_x, get_color_matrix(tex_co - dy, dx));
    color_matrix[1] = filter_lanczos(coeffs_x, get_color_matrix(tex_co, dx));
    color_matrix[2] = filter_lanczos(coeffs_x, get_color_matrix(tex_co + dy, dx));
    color_matrix[3] = filter_lanczos(coeffs_x, get_color_matrix(tex_co + 2.0 * dy, dx));

    col = filter_lanczos(coeffs_y, color_matrix).rgb;
    diff = TL(texture2D(rubyTexture, xy)).rgb;

    float rgb_max = max(col.r, max(col.g, col.b));
    float sample_offset = (rubyInputSize.y / rubyOutputSize.y) * 0.5;
    float scan_pos = xy.y * tex_size.y + scan_offset;
    float scan_strength = mix(SCANLINE_STRENGTH_MAX, SCANLINE_STRENGTH_MIN, rgb_max);
    float scan_beam = clamp(rgb_max * SCANLINE_BEAM_MAX, SCANLINE_BEAM_MIN, SCANLINE_BEAM_MAX);
    vec3 scan_weight = vec3(0.0);

    float mask_colors;
    float mask_dot_width;
    float mask_dot_height;
    float mask_stagger;
    float mask_dither;
    vec4 mask_config;

    if      (MASK_TYPE == 1.0) mask_config = vec4(2.0, 1.0, 1.0, 0.0);
    else if (MASK_TYPE == 2.0) mask_config = vec4(3.0, 1.0, 1.0, 0.0);
    else if (MASK_TYPE == 3.0) mask_config = vec4(2.1, 1.0, 1.0, 0.0);
    else if (MASK_TYPE == 4.0) mask_config = vec4(3.1, 1.0, 1.0, 0.0);
    else if (MASK_TYPE == 5.0) mask_config = vec4(2.0, 1.0, 1.0, 1.0);
    else if (MASK_TYPE == 6.0) mask_config = vec4(3.0, 2.0, 1.0, 3.0);
    else if (MASK_TYPE == 7.0) mask_config = vec4(3.0, 2.0, 2.0, 3.0);

    mask_colors = floor(mask_config.x);
    mask_dot_width = mask_config.y;
    mask_dot_height = mask_config.z;
    mask_stagger = mask_config.w;
    mask_dither = fract(mask_config.x) * 10.0;

    vec2 mod_fac = floor(gl_TexCoord[0].xy * rubyOutputSize.xy * rubyTextureSize.xy / (rubyInputSize.xy * vec2(MASK_SIZE, mask_dot_height * MASK_SIZE)));
    int dot_no = int(mod((mod_fac.x + mod(mod_fac.y, 2.0) * mask_stagger) / mask_dot_width, mask_colors));
    float dither = mod(mod_fac.y + mod(floor(mod_fac.x / mask_colors), 2.0), 2.0);

    float mask_strength = mix(MASK_STRENGTH_MAX, MASK_STRENGTH_MIN, rgb_max);
    float mask_dark, mask_bright, mask_mul;
    vec3 mask_weight;

    mask_dark = 1.0 - mask_strength;
    mask_bright = 1.0 + mask_strength * 2.0;

    if (dot_no == 0) mask_weight = mix(vec3(mask_bright, mask_bright, mask_bright), vec3(mask_bright, mask_dark, mask_dark), mask_colors - 2.0);
    else if (dot_no == 1) mask_weight = mix(vec3(mask_dark, mask_dark, mask_dark), vec3(mask_dark, mask_bright, mask_dark), mask_colors - 2.0);
    else mask_weight = vec3(mask_dark, mask_dark, mask_bright);

    if (dither > 0.9) mask_mul = mask_dark;
    else mask_mul = mask_bright;

    mask_weight *= mix(1.0, mask_mul, mask_dither);
    mask_weight = mix(vec3(1.0), mask_weight, clamp(MASK_TYPE, 0.0, 1.0));

    col2 = (col * mask_weight);
    col2 *= BRIGHTNESS;

    scan_weight = get_scanline_weight(scan_pos - sample_offset, scan_beam, scan_strength);
    col = clamp(col2 * scan_weight, 0.0, 1.0);
    scan_weight = get_scanline_weight(scan_pos, scan_beam, scan_strength);
    col += clamp(col2 * scan_weight, 0.0, 1.0);
    scan_weight = get_scanline_weight(scan_pos + sample_offset, scan_beam, scan_strength);
    col += clamp(col2 * scan_weight, 0.0, 1.0);
    col /= 3.0;

    col *= vec3(corner_weight);
    col += diff * mask_weight * HALATION * vec3(corner_weight);
    col += diff * DIFFUSION * vec3(corner_weight);
    col = pow(col, vec3(1.0 / GAMMA_OUTPUT));

	float l = length(col);
	col = normalize(pow(col, vec3(SATURATION)))*l;
	
	gl_FragColor = vec4(col, 1.0); 
}

]]></fragment>


</shader>

