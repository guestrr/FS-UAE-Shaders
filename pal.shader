<?xml version="1.0" encoding="UTF-8"?>
<!--
/*
   PAL Shader
   
   Copyright (C) 2018 guest(r) - guest.r@gmail.com

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

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

/*
   PAL Shader
   
   Copyright (C) 2018 guest(r) - guest.r@gmail.com

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

*/
	
<fragment scale_x="3.25" outscale_y="1.0"  filter="linear"><![CDATA[
	
uniform sampler2D rubyTexture;
uniform sampler2D rubyOrigTexture;
uniform vec2 rubyInputSize;
uniform vec2 rubyOutputSize;
uniform vec2 rubyTextureSize;
uniform int rubyFrameCount;

vec2 dxx = vec2(1.0/rubyTextureSize.x, 0.0);
vec2 dy  = vec2(0.0, 1.0/rubyTextureSize.y);

#define brightboost 1.125
#define gammaOUT    0.41
#define h_sharp    10.00    // pixel sharpness
#define scanline    6.00    // scanline param, vertical sharpness
	
#define beam_min   1.7	  // dark area beam min - wide
#define beam_max   2.2	  // bright area beam max - narrow


float sw(float x, float l)
{
	float d = x;
	float bm = scanline;
	float b = mix(beam_min,beam_max,l);
	d = exp2(-bm*pow(d,b));
	return d;
}

float l(float x)
{
	return exp2(-h_sharp*x*x);
}

vec3 Mask(float pos){

	float m = fract(pos/3.0);
	if (m < 1.0/3.0) return vec3(1.0, 0.0, 0.0); else
	if (m < 2.0/3.0) return vec3(0.0, 1.0, 0.0); else	
	return vec3(0.0, 0.0, 1.0);
}    


  
void main()
{
	// Calculating texel coordinates
	
	vec2 texcoord = gl_TexCoord[0].xy; 
	
	vec2 inv_size = 1.0/rubyTextureSize;
	vec2 OGL2Pos = texcoord * rubyTextureSize;
	vec2 fp = fract(OGL2Pos);
	vec2 dx = vec2(inv_size.x,0.0);
	vec2 dy = vec2(0.0,inv_size.y);
	
	vec2 pC4 = floor(OGL2Pos) * inv_size + 0.5*inv_size;	

	vec3 tl1 = texture2D(rubyOrigTexture,pC4 -     dx - dy).xyz; tl1*=tl1;
	vec3 tct = texture2D(rubyOrigTexture,pC4          - dy).xyz; tct*=tct;
	vec3 tr1 = texture2D(rubyOrigTexture,pC4 +     dx - dy).xyz; tr1*=tr1;
	
	vec3 ul2 = texture2D(rubyOrigTexture,pC4 - dx -dx).xyz; ul2*=ul2;
	vec3 ul1 = texture2D(rubyOrigTexture,pC4 -     dx).xyz; ul1*=ul1;
	vec3 uct = texture2D(rubyOrigTexture,pC4         ).xyz; uct*=uct;
	vec3 ur1 = texture2D(rubyOrigTexture,pC4 +     dx).xyz; ur1*=ur1;
	vec3 ur2 = texture2D(rubyOrigTexture,pC4 + dx +dx).xyz; ur2*=ur2;
	
	vec3 bl1 = texture2D(rubyOrigTexture,pC4 -     dx + dy).xyz; bl1*=bl1;
	vec3 bct = texture2D(rubyOrigTexture,pC4          + dy).xyz; bct*=bct;
	vec3 br1 = texture2D(rubyOrigTexture,pC4 +     dx + dy).xyz; br1*=br1;
	
	float wl2 = l(fp.x+1.5);
	float wl1 = l(fp.x+0.5);
	float wct = l(fp.x-0.5);	
	float wr1 = l(1.5-fp.x);
	float wr2 = l(2.5-fp.x);
	
	vec3 color0 = (wl1*tl1 + wct*tct + wr1*tr1)/(wl1+wct+wr1);	
	vec3 color1 = (wl2*ul2 + wl1*ul1 + wct*uct + wr1*ur1 + wr2*ur2)/(wl2+wl1+wct+wr1+wr2);	
	vec3 color2 = (wl1*bl1 + wct*bct + wr1*br1)/(wl1+wct+wr1);	
	
// calculating scanlines
	
	float sw2 = sw(1.5-fp.y, max(max(color2.r,color2.g),color2.b));
	float sw1 = sw(0.5-fp.y, max(max(color1.r,color1.g),color1.b));
	float sw0 = sw(fp.y+0.5, max(max(color0.r,color0.g),color0.b));
	
	vec3 color = color2*sw2 + color1*sw1 + color0*sw0;	
	
// applying mask

	float msk = 1.2;	
	
	color = pow(color, vec3(msk));	
	color = color * Mask(gl_FragCoord.x);

	color = pow(color, vec3(gammaOUT));	
	
	gl_FragColor = vec4(color*brightboost,1.0);	

	}
    ]]></fragment>
	
<vertex><![CDATA[

void main(void) {
    gl_Position = ftransform();
    gl_TexCoord[0] = gl_MultiTexCoord0;
}
]]></vertex>

// CRT Lottes code is used for artifacting, lazy me :)

<fragment scale="1.0" filter="nearest"><![CDATA[
uniform sampler2D rubyTexture;
uniform vec2 rubyInputSize;
uniform vec2 rubyOutputSize;
uniform vec2 rubyTextureSize;
		

#define saturation  1.20
#define brightboost 1.0
#define hardBloomScan -2.0

vec3 ToLinear(vec3 c)
{
   return c*c;
}

// Nearest emulated sample given floating point position and texel offset.
// Also zero's off screen.

vec3 Fetch(vec2 pos,vec2 off){
  pos=(floor(pos*rubyTextureSize.xy+off)+vec2(0.5,0.5))/rubyTextureSize.xy;
  return ToLinear(brightboost * texture2D(rubyTexture,pos.xy).xyz);
}

// Distance in emulated pixels to nearest texel.
vec2 Dist(vec2 pos){pos=pos*rubyTextureSize.xy;return -((pos-floor(pos))-vec2(0.5));}
    
// 1D Gaussian.
float Gaus(float pos,float scale){return exp2(scale*pos*pos);}


float intensity (vec3 A) 
{
	return -0.325;
} 
  
// 5-tap Gaussian filter along horz line.
vec3 Horz5(vec2 pos,float off){
  vec3 a=Fetch(pos,vec2(-2.0,off));
  vec3 b=Fetch(pos,vec2(-1.0,off));
  vec3 c=Fetch(pos,vec2( 0.0,off));
  vec3 d=Fetch(pos,vec2( 1.0,off));
  vec3 e=Fetch(pos,vec2( 2.0,off));
  float dst=Dist(pos).x;
  // Convert distance to weight.

  float wa=Gaus(dst-2.0,intensity(a));
  float wb=Gaus(dst-1.0,intensity(b));
  float wc=Gaus(dst+0.0,intensity(c));
  float wd=Gaus(dst+1.0,intensity(d));
  float we=Gaus(dst+2.0,intensity(e));
  // Return filtered sample.
  return (a*wa+b*wb+c*wc+d*wd+e*we)/(wa+wb+wc+wd+we);}
  
  
// 7-tap Gaussian filter along horz line.
vec3 Horz7(vec2 pos,float off){
  vec3 a=Fetch(pos,vec2(-3.0,off));
  vec3 b=Fetch(pos,vec2(-2.0,off));
  vec3 c=Fetch(pos,vec2(-1.0,off));
  vec3 d=Fetch(pos,vec2( 0.0,off));
  vec3 e=Fetch(pos,vec2( 1.0,off));
  vec3 f=Fetch(pos,vec2( 2.0,off));
  vec3 g=Fetch(pos,vec2( 3.0,off));
  float dst=Dist(pos).x;
  // Convert distance to weight.

  float wa=Gaus(dst-3.0,intensity(a));
  float wb=Gaus(dst-2.0,intensity(b));
  float wc=Gaus(dst-1.0,intensity(c));
  float wd=Gaus(dst+0.0,intensity(d));
  float we=Gaus(dst+1.0,intensity(e));
  float wf=Gaus(dst+2.0,intensity(f));
  float wg=Gaus(dst+3.0,intensity(g));
  // Return filtered sample.
  //return (a*wa+b*wb+c*wc+d*wd+e*we+f*wf+g*wg)/(wa+wb+wc+wd+we+wf+wg);
  return (a*wa+b*wb+c*wc+d*wd+e*we+f*wf+g*wg);  
}
   
  // Return scanline weight for bloom.
float BloomScan(vec2 pos,float off){
  float dst=Dist(pos).y;
  return Gaus(dst+off,hardBloomScan);}

  
// Small bloom.
vec3 Bloom(vec2 pos){

  vec3 b=Horz5(pos,-1.0);
  vec3 c=Horz7(pos, 0.0);
  vec3 d=Horz5(pos, 1.0);

  float wb=BloomScan(pos,-1.0);
  float wc=BloomScan(pos, 0.0);
  float wd=BloomScan(pos, 1.0);

  return (b*wb+c*wc+d*wd)/(wb+wc+wd);
}
  
void main()
{	
	vec3 E = Bloom(gl_TexCoord[0].xy);
	E = min(E,1.0);

	E = pow(E, vec3(0.525));
	
	float l = length(E);
	E = normalize(pow(E, vec3(saturation)))*l;	
	
	gl_FragColor = vec4(E*brightboost,1.0);		
}	
]]></fragment>

</shader>
