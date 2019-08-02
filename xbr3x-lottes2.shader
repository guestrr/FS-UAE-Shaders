<?xml version="1.0" encoding="UTF-8"?>
<!--

/*
   Hyllian's xBR-lv2 Shader
   
   Copyright (C) 2011-2015 Hyllian - sergiogdb@gmail.com

   Permission is hereby granted, free of charge, to any person obtaining a copy
   of this software and associated documentation files (the "Software"), to deal
   in the Software without restriction, including without limitation the rights
   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
   copies of the Software, and to permit persons to whom the Software is 
   furnished to do so, subject to the following conditions:

   The above copyright notice and this permission notice shall be included in
   all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
   THE SOFTWARE.
*/

-->
<shader language="GLSL">
    <vertex><![CDATA[
        uniform vec2 rubyTextureSize;

        void main()
        {
                gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
                gl_TexCoord[0] = gl_MultiTexCoord0;
        }
    ]]></vertex>
	
    <fragment scale="3.0" filter="nearest"><![CDATA[
	
	uniform sampler2D rubyTexture;
	uniform vec2 rubyTextureSize;

		// Uncomment just one of the three params below to choose the corner detection
		//#define CORNER_A
		//#define CORNER_B
		#define CORNER_C
		//#define CORNER_D

		#ifndef CORNER_A
			#define SMOOTH_TIPS
		#endif

		#define XBR_SCALE 3.0
		#define XBR_Y_WEIGHT 48.0
		#define XBR_EQ_THRESHOLD 15.0
		#define XBR_LV2_COEFFICIENT 2.0
		#define lv2_cf XBR_LV2_COEFFICIENT
 
		const   float coef          = 2.0;
		const   vec3  rgbw          = vec3(14.352, 28.176, 5.472);
		const   vec4  eq_threshold  = vec4(15.0, 15.0, 15.0, 15.0);

		const vec4 delta   = vec4(1.0/XBR_SCALE, 1.0/XBR_SCALE, 1.0/XBR_SCALE, 1.0/XBR_SCALE);
		const vec4 delta_l = vec4(0.5/XBR_SCALE, 1.0/XBR_SCALE, 0.5/XBR_SCALE, 1.0/XBR_SCALE);
		const vec4 delta_u = delta_l.yxwz;

		const   vec2 OGLSize    = vec2( 1024.0, 512.0);
		const   vec2 OGLInvSize = 1.0/OGLSize; 

		const  vec4 Ao = vec4( 1.0, -1.0, -1.0, 1.0 );
		const  vec4 Bo = vec4( 1.0,  1.0, -1.0,-1.0 );
		const  vec4 Co = vec4( 1.5,  0.5, -0.5, 0.5 );
		const  vec4 Ax = vec4( 1.0, -1.0, -1.0, 1.0 );
		const  vec4 Bx = vec4( 0.5,  2.0, -0.5,-2.0 );
		const  vec4 Cx = vec4( 1.0,  1.0, -0.5, 0.0 );
		const  vec4 Ay = vec4( 1.0, -1.0, -1.0, 1.0 );
		const  vec4 By = vec4( 2.0,  0.5, -2.0,-0.5 );
		const  vec4 Cy = vec4( 2.0,  0.0, -1.0, 0.5 );
		const  vec4 Ci = vec4(0.25, 0.25, 0.25, 0.25);


		// Difference between vector components.
		vec4 df(vec4 A, vec4 B)
		{
			return vec4(abs(A-B));
		}

		// Compare two vectors and return their components are different.
		vec4 diff(vec4 A, vec4 B)
		{
			return vec4(notEqual(A, B));
		}

		// Determine if two vector components are equal based on a threshold.
		vec4 eq(vec4 A, vec4 B)
		{
			return (step(df(A, B), vec4(XBR_EQ_THRESHOLD)));
		}

		// Determine if two vector components are NOT equal based on a threshold.
		vec4 neq(vec4 A, vec4 B)
		{
			return (vec4(1.0, 1.0, 1.0, 1.0) - eq(A, B));
		}

		// Weighted distance.
		vec4 wd(vec4 a, vec4 b, vec4 c, vec4 d, vec4 e, vec4 f, vec4 g, vec4 h)
		{
			return (df(a,b) + df(a,c) + df(d,e) + df(d,f) + 4.0*df(g,h));
		}

		float c_df(vec3 c1, vec3 c2) 
		{
			vec3 df = abs(c1 - c2);
			return df.r + df.g + df.b;
		}
	
	void main()
	{
    vec4 edri, edr, edr_l, edr_u, px; // px = pixel, edr = edge detection rule
    vec4 irlv0, irlv1, irlv2l, irlv2u;
    vec4 fx, fx_l, fx_u; // inequations of straight lines.

	vec2 OGLInvSize = vec2(1.0,1.0)/rubyTextureSize;	
    vec2 fp = fract(gl_TexCoord[0].xy*rubyTextureSize);
    vec2 TexCoord_0 = gl_TexCoord[0].xy-fp*OGLInvSize + 0.5*OGLInvSize;

	float x = OGLInvSize.x;
	float y = OGLInvSize.y;
	
    vec2 dx         = vec2( x, 0.0);
    vec2 dy         = vec2( 0.0, y);
    vec2 x2         = vec2( 2.0*x , 0.0);
    vec2 y2         = vec2( 0.0 , 2.0*y);
    vec4 xy         = vec4( x, y,-x,-y);  
    vec4 zw         = vec4( 2.0*x , y,-2.0*x ,-y);  
    vec4 wz         = vec4( x, 2.0*y ,-x,-2.0*y );  

    vec3 A  = texture2D(rubyTexture, TexCoord_0 + xy.zw ).xyz;
    vec3 B  = texture2D(rubyTexture, TexCoord_0     -dy ).xyz;
    vec3 C  = texture2D(rubyTexture, TexCoord_0 + xy.xw ).xyz;
    vec3 D  = texture2D(rubyTexture, TexCoord_0 - dx    ).xyz;
    vec3 E  = texture2D(rubyTexture, TexCoord_0         ).xyz;
    vec3 F  = texture2D(rubyTexture, TexCoord_0 + dx    ).xyz;
    vec3 G  = texture2D(rubyTexture, TexCoord_0 + xy.zy ).xyz;
    vec3 H  = texture2D(rubyTexture, TexCoord_0     +dy ).xyz;
    vec3 I  = texture2D(rubyTexture, TexCoord_0 + xy.xy ).xyz;
    vec3 A1 = texture2D(rubyTexture, TexCoord_0 + wz.zw ).xyz;
    vec3 C1 = texture2D(rubyTexture, TexCoord_0 + wz.xw ).xyz;
    vec3 A0 = texture2D(rubyTexture, TexCoord_0 + zw.zw ).xyz;
    vec3 G0 = texture2D(rubyTexture, TexCoord_0 + zw.zy ).xyz;
    vec3 C4 = texture2D(rubyTexture, TexCoord_0 + zw.xw ).xyz;
    vec3 I4 = texture2D(rubyTexture, TexCoord_0 + zw.xy ).xyz;
    vec3 G5 = texture2D(rubyTexture, TexCoord_0 + wz.zy ).xyz;
    vec3 I5 = texture2D(rubyTexture, TexCoord_0 + wz.xy ).xyz;
    vec3 B1 = texture2D(rubyTexture, TexCoord_0 - y2    ).xyz;
    vec3 D0 = texture2D(rubyTexture, TexCoord_0 - x2    ).xyz;
    vec3 H5 = texture2D(rubyTexture, TexCoord_0 + y2    ).xyz;
    vec3 F4 = texture2D(rubyTexture, TexCoord_0 + x2    ).xyz;

    vec4 b  = vec4(dot(B ,rgbw), dot(D ,rgbw), dot(H ,rgbw), dot(F ,rgbw));
    vec4 c  = vec4(dot(C ,rgbw), dot(A ,rgbw), dot(G ,rgbw), dot(I ,rgbw));
    vec4 d  = b.yzwx;
    vec4 e  = vec4(dot(E,rgbw));
    vec4 f  = b.wxyz;
    vec4 g  = c.zwxy;
    vec4 h  = b.zwxy;
    vec4 i  = c.wxyz;
    vec4 i4 = vec4(dot(I4,rgbw), dot(C1,rgbw), dot(A0,rgbw), dot(G5,rgbw));
    vec4 i5 = vec4(dot(I5,rgbw), dot(C4,rgbw), dot(A1,rgbw), dot(G0,rgbw));
    vec4 h5 = vec4(dot(H5,rgbw), dot(F4,rgbw), dot(B1,rgbw), dot(D0,rgbw));
    vec4 f4 = h5.yzwx;
    
    // These inequations define the line below which interpolation occurs.
    fx   = (Ao*fp.y+Bo*fp.x); 
    fx_l = (Ax*fp.y+Bx*fp.x);
    fx_u = (Ay*fp.y+By*fp.x);

    irlv1 = irlv0 = diff(e,f) * diff(e,h);

#ifdef CORNER_B
    irlv1      = (irlv0 * ( neq(f,b) * neq(h,d) + eq(e,i) * neq(f,i4) * neq(h,i5) + eq(e,g) + eq(e,c) ) );
#endif
#ifdef CORNER_D
    vec4 c1 = i4.yzwx;
    vec4 g0 = i5.wxyz;
    irlv1     = (irlv0  *  ( neq(f,b) * neq(h,d) + eq(e,i) * neq(f,i4) * neq(h,i5) + eq(e,g) + eq(e,c) ) * (diff(f,f4) * diff(f,i) + diff(h,h5) * diff(h,i) + diff(h,g) + diff(f,c) + eq(b,c1) * eq(d,g0)));
#endif
#ifdef CORNER_C
    irlv1     = (irlv0  * ( neq(f,b) * neq(f,c) + neq(h,d) * neq(h,g) + eq(e,i) * (neq(f,f4) * neq(f,i4) + neq(h,h5) * neq(h,i5)) + eq(e,g) + eq(e,c)) );
#endif

    irlv2l = diff(e,g) * diff(d,g);
    irlv2u = diff(e,c) * diff(b,c);

    vec4 fx45i = clamp((fx   + delta   -Co - Ci)/(2*delta  ), 0.0, 1.0);
    vec4 fx45  = clamp((fx   + delta   -Co     )/(2*delta  ), 0.0, 1.0);
    vec4 fx30  = clamp((fx_l + delta_l -Cx     )/(2*delta_l), 0.0, 1.0);
    vec4 fx60  = clamp((fx_u + delta_u -Cy     )/(2*delta_u), 0.0, 1.0);
    vec4 w1, w2;
	w1 = wd( e, c, g, i, h5, f4, h, f);
	w2 = wd( h, d, i5, f, i4, b, e, i);

    edri  = step(w1, w2) * irlv0;
    edr   = step(w1 + vec4(0.1, 0.1, 0.1, 0.1), w2) * step(vec4(0.5, 0.5, 0.5, 0.5), irlv1);
	
    w1.x = dot(abs(F-G),rgbw); w1.y = dot(abs(B-I),rgbw); w1.z = dot(abs(D-C),rgbw); w1.w = dot(abs(H-A),rgbw);
    w2.x = dot(abs(H-C),rgbw); w2.y = dot(abs(F-A),rgbw); w2.z = dot(abs(B-G),rgbw); w2.w = dot(abs(D-I),rgbw);

    edr_l = step( lv2_cf*w1, w2 ) * irlv2l * edr;
    edr_u = step( lv2_cf*w2, w1 ) * irlv2u * edr;

    fx45  = edr   * fx45;
    fx30  = edr_l * fx30;
    fx60  = edr_u * fx60;
    fx45i = edri  * fx45i;

    w1.x = dot(abs(E-F),rgbw); w1.y = dot(abs(E-B),rgbw); w1.z = dot(abs(E-D),rgbw); w1.w = dot(abs(E-H),rgbw);
    w2.x = dot(abs(E-H),rgbw); w2.y = dot(abs(E-F),rgbw); w2.z = dot(abs(E-B),rgbw); w2.w = dot(abs(E-D),rgbw);
	
    px = step(w1, w2);

#ifdef SMOOTH_TIPS
    vec4 maximos = max(max(fx30, fx60), max(fx45, fx45i));
#endif
#ifndef SMOOTH_TIPS
    vec4 maximos = max(max(fx30, fx60), fx45);
#endif

    vec3 res1 = E;
    res1 = mix(res1, mix(H, F, px.x), maximos.x);
    res1 = mix(res1, mix(B, D, px.z), maximos.z);
    
    vec3 res2 = E;
    res2 = mix(res2, mix(F, B, px.y), maximos.y);
    res2 = mix(res2, mix(D, H, px.w), maximos.w);
    
    vec3 res = mix(res1, res2, step(c_df(E, res1), c_df(E, res2)));

    gl_FragColor = vec4(res,1.0);
	}
    ]]></fragment>
	

//
// PUBLIC DOMAIN CRT STYLED SCAN-LINE SHADER
//
//   by Timothy Lottes
//
// This is more along the style of a really good CGA arcade monitor.
// With RGB inputs instead of NTSC.
// The shadow mask example has the mask rotated 90 degrees for less chromatic aberration.
//
// Left it unoptimized to show the theory behind the algorithm.
//
// It is an example what I personally would want as a display option for pixel art games.
// Please take and use, change, or whatever.
//
// ported, tweaked, fast-multipass version and bloom by guest.r

-->
<shader language="GLSL">


<vertex><![CDATA[
        uniform vec2 rubyTextureSize;

        void main()
        {
				gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
				gl_TexCoord[0] = gl_MultiTexCoord0;
        }
]]></vertex>
	
	
<fragment outscale_x="1.0"  scale_y="1.0" filter="nearest"><![CDATA[

uniform sampler2D rubyTexture;
uniform vec2 rubyInputSize;
uniform vec2 rubyOutputSize;
uniform vec2 rubyTextureSize;


// CRT-Lottes settings (editable)

#define hardPix -1.7
 
vec3 ToLinear(vec3 c)
{
   return c*c;
}

// Linear to sRGB.
// Assuming using sRGB typed textures this should not be needed.


vec3 ToSrgb(vec3 c)
{
   return sqrt(c);
}

// Nearest emulated sample given floating point position and texel offset.
vec3 Fetch(vec2 pos,vec2 off){
  pos=(floor(pos*rubyTextureSize.xy+off)+vec2(0.5,0.5))/rubyTextureSize.xy;
  return ToLinear(texture2D(rubyTexture,pos.xy).xyz);
}

// Distance in emulated pixels to nearest texel.
vec2 Dist(vec2 pos){pos=pos*rubyTextureSize.xy;return -((pos-floor(pos))-vec2(0.5));}

// 1D Gaussian.
float Gaus(float pos,float scale){return exp2(scale*pos*pos);}

    
// 5-tap Gaussian filter along horz line.
vec3 Horz5(vec2 pos,float off){
  vec3 a=Fetch(pos,vec2(-2.0,off));
  vec3 b=Fetch(pos,vec2(-1.0,off));
  vec3 c=Fetch(pos,vec2( 0.0,off));
  vec3 d=Fetch(pos,vec2( 1.0,off));
  vec3 e=Fetch(pos,vec2( 2.0,off));
  float dst=Dist(pos).x;
  // Convert distance to weight.
  
  float scale=hardPix;
  float wa=Gaus(dst-2.0,scale);
  float wb=Gaus(dst-1.0,scale);
  float wc=Gaus(dst+0.0,scale);
  float wd=Gaus(dst+1.0,scale);
  float we=Gaus(dst+2.0,scale);
  // Return filtered sample.
  return (a*wa+b*wb+c*wc+d*wd+e*we)/(wa+wb+wc+wd+we);}


void main()
{
	vec3 color = Horz5(gl_TexCoord[0].xy,0.0);
	color = ToSrgb(color);
	gl_FragColor.rgb = color;
	gl_FragColor.a= 1.0;
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
uniform vec2 rubyInputSize;
uniform vec2 rubyOutputSize;
uniform vec2 rubyTextureSize;

vec2 TextureSize = rubyTextureSize;

vec2 dy = vec2(0.0, 1.0/rubyTextureSize.y);

// CRT-Lottes settings (editable)

#define shadowMask 1              // 1, 2, 3 or 4 (CRT style)
#define maskDark 0.5             
#define maskLight 1.4       
#define hardScan -2.0
#define brightboost 1.0
#define shape  2.4
#define BLOOM  0.0
#define GAMMA  1.0/2.4             // output gamma

#define warp vec2(warpX,warpY)

vec3 ToLinear(vec3 c)
{
   return c*c;
}

// Linear to sRGB.
// Assuming using sRGB typed textures this should not be needed.


vec3 ToSrgb(vec3 c)
{
   return pow(c,vec3(GAMMA));
}


// Distance in emulated pixels to nearest texel.
vec2 Dist(vec2 pos){pos=pos*TextureSize.xy;return -((pos-floor(pos))-vec2(0.5));}
    
// 1D Gaussian.
float Gaus(float pos,float scale){return exp2(scale*pow(abs(pos),shape));}

// Return scanline weight.
float Scan(vec2 pos,float off){
  float dst=Dist(pos).y;
  return Gaus(dst+off,hardScan);}
  

// Allow nearest three lines to effect pixel.
vec3 Tri(vec2 pos, vec2 crd){
  vec3 a=ToLinear(texture2D(rubyTexture,crd - dy).xyz);
  vec3 b=ToLinear(texture2D(rubyTexture,crd     ).xyz);
  vec3 c=ToLinear(texture2D(rubyTexture,crd + dy).xyz);
  float wa=Scan(pos,-1.0);
  float wb=Scan(pos, 0.0);
  float wc=Scan(pos, 1.0);
  return (a*wa+b*wb+c*wc)/(wa+wb+wc);
}
  

// Shadow mask 
vec3 Mask(vec2 pos){
  vec3 mask=vec3(maskDark,maskDark,maskDark);

  // Very compressed TV style shadow mask.
  if (shadowMask == 1) {
    float line=maskLight;
    float odd=0.0;
    if(fract(pos.x/6.0)<0.5)odd=1.0;
    if(fract((pos.y+odd)/2.0)<0.5)line=maskDark;  
    pos.x=fract(pos.x/3.0);
   
    if(pos.x<0.333)mask.r=maskLight;
    else if(pos.x<0.666)mask.g=maskLight;
    else mask.b=maskLight;
    mask*=line;  
  } 

  // Aperture-grille.
  else if (shadowMask == 2) {
	pos.x=fract(pos.x/3.0);

    if(pos.x<0.333)mask.r=maskLight;
    else if(pos.x<0.666)mask.g=maskLight;
    else mask.b=maskLight;
  } 

  // Stretched VGA style shadow mask (same as prior shaders).
  else if (shadowMask == 3) {
    pos.x+=pos.y*3.0;
    pos.x=fract(pos.x/6.0);

    if(pos.x<0.333)mask.r=maskLight;
    else if(pos.x<0.666)mask.g=maskLight;
    else mask.b=maskLight;
  }

  // VGA style shadow mask.
  else if (shadowMask == 4) {
    pos.xy=floor(pos.xy*vec2(1.0,0.5));
    pos.x+=pos.y*3.0;
    pos.x=fract(pos.x/6.0);

    if(pos.x<0.333)mask.r=maskLight;
    else if(pos.x<0.666)mask.g=maskLight;
    else mask.b=maskLight;
  }

  return mask;
  }    


void main()
{
	vec2 pos=gl_TexCoord[0].xy;
	vec2 crd = (floor(pos*rubyTextureSize) + vec2(0.5))/rubyTextureSize;
	vec3 color = Tri(pos,crd);
	color = pow(color, vec3(1.2))*brightboost;
	color*= Mask(gl_FragCoord.xy); // Tweak by SimoneT
	color = ToSrgb(color);
	color = min(color,1.0);
	color+= BLOOM*color;
	gl_FragColor.rgb = color;
	gl_FragColor.a= 1.0;
}
]]></fragment>

	
</shader>
