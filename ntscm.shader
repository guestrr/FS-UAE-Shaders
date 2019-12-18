<?xml version="1.0" encoding="UTF-8"?>
<shader language="GLSL">
<!--
/*
 * The Maister's NTSC shader
 * Ported from Retroarch
 */
-->

<vertex><![CDATA[

void main(void) {
    gl_Position = ftransform();
    gl_TexCoord[0] = gl_MultiTexCoord0;
}
]]></vertex>


<fragment scale_x="4.0" scale_y="1.0" filter="nearest"><![CDATA[
uniform sampler2D rubyTexture;

void main()
{	
	vec3 E = texture2D(rubyTexture, gl_TexCoord[0].xy        ).rgb;
	gl_FragColor = vec4(E,1.0);	
}	
]]></fragment>


<vertex><![CDATA[
uniform vec2 rubyTextureSize;

void main(void) {
    gl_Position = ftransform();
    gl_TexCoord[0] = gl_MultiTexCoord0;
	//gl_TexCoord[0].xy - vec2(0.5 / rubyTextureSize.x, 0.0); // Compensate for decimate-by-2. 	
}
]]></vertex>


<fragment scale_x="1.0" scale_y="1.0" filter="nearest"><![CDATA[
uniform sampler2D rubyTexture;
uniform vec2 rubyInputSize;
uniform vec2 rubyTextureSize;
uniform vec2 rubyOutputSize;
uniform int rubyFrameCount;

#define PI 3.14159265 
#define CHROMA_MOD_FREQ (PI / 3.0)
#define SATURATION 1.1
#define BRIGHTNESS 1.05
#define ARTIFACTING 1.0
#define FRINGING 1.0 

// begin ntsc-rgbyuv
const mat3 yiq2rgb_mat = mat3(
   1.0, 0.956, 0.6210,
   1.0, -0.2720, -0.6474,
   1.0, -1.1060, 1.7046);

vec3 yiq2rgb(vec3 yiq)
{
   return (yiq * yiq2rgb_mat);
}

const mat3 yiq_mat = mat3(
      0.2989, 0.5870, 0.1140,
      0.5959, -0.2744, -0.3216,
      0.2115, -0.5229, 0.3114
); 

vec3 rgb2yiq(vec3 col)
{
   return (col * yiq_mat);
} 

mat3 mix_mat = mat3(
	BRIGHTNESS, FRINGING, FRINGING,
	ARTIFACTING, 2.0 * SATURATION, 0.0,
	ARTIFACTING, 0.0, 2.0 * SATURATION
);


// #define fetch_offset(offset, one_x) \
//    texture2D(rubyTexture, gl_TexCoord[0].xy + vec2((offset) * (one_x), 0.0)).xyz


vec3 fetch_offset   (float offset, float one_x)
{
	vec2 tex = gl_TexCoord[0].xy + vec2(offset * (one_x), 0.0);
	vec3 col = texture2D(rubyTexture, tex).xyz; //col*=col;
	vec3 yiq = rgb2yiq(col);

	//vec2 pix_no = gl_FragCoord.xy;
	
	vec2 pix_no = 1.0*tex * rubyTextureSize.xy * (rubyOutputSize.xy / rubyInputSize.xy); 
	
	float chroma_phase = 0.6667 * PI * (mod(pix_no.y, 3.0) + floor(mod(float(rubyFrameCount),2.0)));
	//float chroma_phase = 0.6667 * PI * (mod(pix_no.y, 3.0));	

	float mod_phase = chroma_phase + pix_no.x * CHROMA_MOD_FREQ;

	float i_mod = cos(mod_phase);
	float q_mod = sin(mod_phase);

	yiq.yz *= vec2(i_mod, q_mod); // Modulate.
	yiq *= mix_mat; // Cross-talk.
	yiq.yz *= vec2(i_mod, q_mod); // Demodulate. 	
	
	return yiq;	   
}

 
float luma_filter1 = -0.000012020;
float luma_filter2 = -0.000022146;
float luma_filter3 = -0.000013155;
float luma_filter4 = -0.000012020;
float luma_filter5 = -0.000049979;
float luma_filter6 = -0.000113940;
float luma_filter7 = -0.000122150;
float luma_filter8 = -0.000005612;
float luma_filter9 = 0.000170516;
float luma_filter10 = 0.000237199;
float luma_filter11 = 0.000169640;
float luma_filter12 = 0.000285688;
float luma_filter13 = 0.000984574;
float luma_filter14 = 0.002018683;
float luma_filter15 = 0.002002275;
float luma_filter16 = -0.000909882;
float luma_filter17 = -0.007049081;
float luma_filter18 = -0.013222860;
float luma_filter19 = -0.012606931;
float luma_filter20 = 0.002460860;
float luma_filter21 = 0.035868225;
float luma_filter22 = 0.084016453;
float luma_filter23 = 0.135563500;
float luma_filter24 = 0.175261268;
float luma_filter25 = 0.190176552;

float chroma_filter1 = -0.000118847;
float chroma_filter2 = -0.000271306;
float chroma_filter3 = -0.000502642;
float chroma_filter4 = -0.000930833;
float chroma_filter5 = -0.001451013;
float chroma_filter6 = -0.002064744;
float chroma_filter7 = -0.002700432;
float chroma_filter8 = -0.003241276;
float chroma_filter9 = -0.003524948;
float chroma_filter10 = -0.003350284;
float chroma_filter11 = -0.002491729;
float chroma_filter12 = -0.000721149;
float chroma_filter13 = 0.002164659;
float chroma_filter14 = 0.006313635;
float chroma_filter15 = 0.011789103;
float chroma_filter16 = 0.018545660;
float chroma_filter17 = 0.026414396;
float chroma_filter18 = 0.035100710;
float chroma_filter19 = 0.044196567;
float chroma_filter20 = 0.053207202;
float chroma_filter21 = 0.061590275;
float chroma_filter22 = 0.068803602;
float chroma_filter23 = 0.074356193;
float chroma_filter24 = 0.077856564;
float chroma_filter25 = 0.079052396; 

void main()
{	
	
// begin ntsc-pass2-decode
	float one_x = 1.0 / rubyTextureSize.x;
	vec3 signal = vec3(0.0);

	float offset;
	vec3 sums;

	#define macro_loopz(c) offset = float(c) - 1.0; \
		sums = fetch_offset(offset - 24., one_x) + fetch_offset(24. - offset, one_x); \
		signal += sums * vec3(luma_filter##c, chroma_filter##c, chroma_filter##c);

	// unrolling the loopz
	macro_loopz(1)
	macro_loopz(2)
	macro_loopz(3)
	macro_loopz(4)
	macro_loopz(5)
	macro_loopz(6)
	macro_loopz(7)
	macro_loopz(8)
	macro_loopz(9)
	macro_loopz(10)
	macro_loopz(11)
	macro_loopz(12)
	macro_loopz(13)
	macro_loopz(14)
	macro_loopz(15)
	macro_loopz(16)
	macro_loopz(17)
	macro_loopz(18)
	macro_loopz(19)
	macro_loopz(20)
	macro_loopz(21)
	macro_loopz(22)
	macro_loopz(23)
	macro_loopz(24)

	signal += fetch_offset (0.0, 0.0) *
		vec3(luma_filter25, chroma_filter25, chroma_filter25); 	

// end ntsc-pass2-decode
	vec3 rgb = yiq2rgb(signal);
	
	gl_FragColor = vec4(rgb,1.0);	
}	
]]></fragment>


<vertex><![CDATA[

void main(void) {
    gl_Position = ftransform();
    gl_TexCoord[0] = gl_MultiTexCoord0;
}
]]></vertex>


<fragment scale_x="1.0" outscale_y="1.0" filter="linear"><![CDATA[
uniform sampler2D rubyTexture;
uniform vec2 rubyInputSize;
uniform vec2 rubyTextureSize;
uniform vec2 rubyOutputSize;
uniform int rubyFrameCount;

#define NTSC_CRT_GAMMA 2.5
#define NTSC_DISPLAY_GAMMA 2.2



void main()
{	
   vec2 pix_no = gl_TexCoord[0].xy * rubyTextureSize.xy;
   vec2 one = 1.0 / rubyTextureSize.xy; 
   vec2 pC4 = floor(pix_no) / rubyTextureSize + 0.5/rubyTextureSize;
   pC4.x = gl_TexCoord[0].x;		
   
#define TEX(off) pow(texture2D(rubyTexture, pC4 + vec2(0.0, (off) * one.y)).rgb, vec3(NTSC_CRT_GAMMA)) 
   
   vec3 frame0 = TEX(-2.0);
   vec3 frame1 = TEX(-1.0);
   vec3 frame2 = TEX(0.0);
   vec3 frame3 = TEX(1.0);
   vec3 frame4 = TEX(2.0);

   float fp = fract(pix_no.y);
   float dist0 =  1.5 + fp;
   float dist1 =  0.5 + fp;
   float dist2 = -0.5 + fp;
   float dist3 =  1.5 - fp;
   float dist4 =  2.5 - fp;

   vec3 scanline = frame0 * exp(-5.0 * dist0 * dist0);
   scanline += frame1 * exp(-5.0 * dist1 * dist1);
   scanline += frame2 * exp(-5.0 * dist2 * dist2);
   scanline += frame3 * exp(-5.0 * dist3 * dist3);
   scanline += frame4 * exp(-5.0 * dist4 * dist4);
	
   gl_FragColor = vec4(pow(1.15 * scanline, vec3(1.0 / NTSC_DISPLAY_GAMMA)), 1.0);	
}	
]]></fragment>


<vertex><![CDATA[

void main(void) {
    gl_Position = ftransform();
    gl_TexCoord[0] = gl_MultiTexCoord0;
}
]]></vertex>


<fragment outscale="1.0" filter="linear"><![CDATA[
uniform sampler2D rubyTexture;
#define saturation 1.1

void main()
{	
	vec3 E = texture2D(rubyTexture, gl_TexCoord[0].xy        ).rgb;
	float l = length(E);
	E = normalize(pow(E, vec3(saturation)))*l;	
	gl_FragColor = vec4(E,1.0);	
}	
]]></fragment>

</shader>
