<?xml version="1.0" encoding="UTF-8"?>
<!--
/*
   PAL Shader
   
   Copyright (C) 2018 - 2020 guest(r) - guest.r@gmail.com

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

	
<fragment scale_x="3.33" outscale_y="1.0"  filter="linear"><![CDATA[
	
uniform sampler2D rubyTexture;
uniform sampler2D rubyOrigTexture;
uniform vec2 rubyInputSize;
uniform vec2 rubyOutputSize;
uniform vec2 rubyTextureSize;
uniform int rubyFrameCount;

vec2 dxx = vec2(1.0/rubyTextureSize.x, 0.0);
vec2 dy  = vec2(0.0, 1.0/rubyTextureSize.y);

#define brightboost 1.125
#define gammaOUT    0.50
#define h_sharp    10.00    // pixel sharpness
#define scanline    7.00    // scanline param, vertical sharpness
	
#define beam_min   1.7	  // dark area beam min - wide
#define beam_max   2.2	  // bright area beam max - narrow


float sw(float x, float l)
{
	float d = x;
	float bm = scanline;
	float b = mix(beam_min,beam_max,l);
	d = exp2(-bm*d*d);
	return d;
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

	pC4.x = texcoord.x;

	vec3 tct = texture2D(rubyOrigTexture,pC4     - dy).xyz; tct*=tct;
	vec3 uct = texture2D(rubyOrigTexture,pC4         ).xyz; uct*=uct;
	vec3 bct = texture2D(rubyOrigTexture,pC4     + dy).xyz; bct*=bct;
	
	vec3 color0 = tct;
	vec3 color1 = uct;
	vec3 color2 = bct;	
	
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


<fragment scale="1.0" filter="nearest"><![CDATA[
uniform sampler2D rubyTexture;
uniform vec2 rubyInputSize;
uniform vec2 rubyOutputSize;
uniform vec2 rubyTextureSize;
		
#define h_sharp 0.335
#define saturation  1.15
#define brightboost 0.85
  
void main()
{

	vec2 texcoord = gl_TexCoord[0].xy; 
	
	vec2 inv_size = 1.0/rubyTextureSize;
	vec2 OGL2Pos = texcoord * rubyTextureSize;
	vec2 fp = fract(OGL2Pos);
	vec2 dx = vec2(inv_size.x,0.0);
	vec2 dy = vec2(0.0,inv_size.y);
	
	vec2 pC4 = floor(OGL2Pos) * inv_size + 0.5*inv_size;	

	pC4.x = texcoord.x;
	
	// Reading the texels
	vec2 x2 = 2.0*dx;

	float wl4 = 3.5 + fp.x;  wl4*=wl4; wl4 = exp2(-h_sharp*wl4);
	float wl3 = 2.5 + fp.x;  wl3*=wl3; wl3 = exp2(-h_sharp*wl3);	
	float wl2 = 1.5 + fp.x;  wl2*=wl2; wl2 = exp2(-h_sharp*wl2);
	float wl1 = 0.5 + fp.x;  wl1*=wl1; wl1 = exp2(-h_sharp*wl1);
	float wct = 0.5 - fp.x;  wct*=wct; wct = exp2(-h_sharp*wct);
	float wr1 = 1.5 - fp.x;  wr1*=wr1; wr1 = exp2(-h_sharp*wr1);
	float wr2 = 2.5 - fp.x;  wr2*=wr2; wr2 = exp2(-h_sharp*wr2);
	float wr3 = 3.5 - fp.x;  wr3*=wr3; wr3 = exp2(-h_sharp*wr3);
	float wr4 = 4.5 - fp.x;  wr4*=wr4; wr4 = exp2(-h_sharp*wr4);
	
	float wt = 1.0/(wl4+wl3+wl2+wl1+wct+wr1+wr2+wr3+wr4);

	vec3 l4 = texture2D(rubyTexture, pC4 -x2-x2).xyz; l4*=l4;
	vec3 l3 = texture2D(rubyTexture, pC4 -x2-dx).xyz; l3*=l3;	
	vec3 l2 = texture2D(rubyTexture, pC4 -x2).xyz;    l2*=l2;
	vec3 l1 = texture2D(rubyTexture, pC4 -dx).xyz;    l1*=l1;
	vec3 ct = texture2D(rubyTexture, pC4    ).xyz;    ct*=ct;
	vec3 r1 = texture2D(rubyTexture, pC4 +dx).xyz;    r1*=r1;
	vec3 r2 = texture2D(rubyTexture, pC4 +x2).xyz;    r2*=r2;
	vec3 r3 = texture2D(rubyTexture, pC4 +x2+dx).xyz; r3*=r3;
	vec3 r4 = texture2D(rubyTexture, pC4 +x2+x2).xyz; r4*=r4;
	
	vec3 E = (l4*wl4 + l3*wl3 + l2*wl2 + l1*wl1 + ct*wct + r1*wr1 + r2*wr2 + r3*wr3 + r4*wr4);

	E = min(E*brightboost,1.0);

	E = pow(E, vec3(0.450));
	
	float l = length(E);
	E = normalize(pow(E, vec3(saturation)))*l;	
	
	gl_FragColor = vec4(E,1.0);		
}	
]]></fragment>

</shader>
