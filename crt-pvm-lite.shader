<?xml version="1.0" encoding="UTF-8"?>
<!--
/*
   CRT PVM Lite shader
   
   Copyright (C) 2017 guest(r) - guest.r@gmail.com

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


	
<fragment outscale_x = "1.0"  outscale_y = "2.0" filter="nearest"><![CDATA[
	
uniform sampler2D rubyTexture;
uniform vec2 rubyInputSize;
uniform vec2 rubyOutputSize;
uniform vec2 rubyTextureSize;

// Tweakable options

#define saturation  1.10    // 1.0 is normal saturation
#define brightboost 1.25
#define gammaIN     2.4
#define gammaOUT    2.5
#define shape1     11.0     // scanline shape params
#define shape2      2.0
#define cutoff      0.4     // 0.0 to 0.9 - for thicker/darker scanlines
#define beam_min    0.90
#define beam_max    1.02
#define v_sharp     6.0
#define mask_v      0.70    // vertical mask strength

 	
const vec3 dt = vec3(1.0,1.0,1.0);


float sharp (vec3 A, vec3 B)
{
	vec3 diff = length(A-B);
	float luma = clamp(dot(mix(min(A,B), 0.5*(A+B), 0.333),dt), 0.0001, 1.0);
	float mx = diff/luma;
	return 1.0 + clamp(8.0*(mx-0.6), 0.0, 1.0);
}

float sw(float x)
{
	float d = x;	
	float bm = shape1;
	float b  = shape2;
	d = exp2(-bm*pow(d,b));
	return d;
}

vec2 Overscan(vec2 pos, float dx, float dy){
  pos=pos*2.0-1.0;    
  pos*=vec2(dx,dy);
  return pos*0.5+0.5;
}

void main()
{
	// Calculating texel coordinates

	vec2 tex = gl_TexCoord[0].xy*1.0001;
	vec2 factor = rubyOutputSize/rubyInputSize;
	vec2 intfactor = floor(factor+0.5);
	vec2 diff = factor/intfactor;
	vec2 texcoord = Overscan(tex*(rubyTextureSize/rubyInputSize), diff.x, diff.y)*(rubyInputSize/rubyTextureSize); 
	texcoord.x = tex.x;

	vec2 size     = rubyTextureSize;
	vec2 inv_size = 1.0/size;
	
	vec2 OGL2Pos = texcoord * size;
	vec2 fp = fract(OGL2Pos);
	vec2 dx = vec2(inv_size.x,0.0);
	vec2 dy = vec2(0.0, inv_size.y);
	vec2 g1 = vec2(inv_size.x,inv_size.y);
	
	vec2 pC4 = floor(OGL2Pos) * inv_size;	
	
	// Reading the texels
	vec3 ul = texture2D(rubyTexture, pC4     ).xyz; vec3 ulg = pow(ul, vec3(gammaIN));
	vec3 ur = texture2D(rubyTexture, pC4 + dx).xyz; vec3 urg = pow(ur, vec3(gammaIN));
	vec3 dl = texture2D(rubyTexture, pC4 + dy).xyz; vec3 dlg = pow(dl, vec3(gammaIN));
	vec3 dr = texture2D(rubyTexture, pC4 + g1).xyz; vec3 drg = pow(dr, vec3(gammaIN));

	float h_sharp1 = sharp(ul, ur);
	float h_sharp2 = sharp(dl, dr);
	
	float lx = fp.x;        float lx1 = pow(lx, h_sharp1); float lx2 = pow(lx, h_sharp2);
	float rx = 1.0 - fp.x;  float rx1 = pow(rx, h_sharp1); float rx2 = pow(rx, h_sharp2);
	float uy = fp.y;        uy = pow(uy, v_sharp);
	float by = 1.0 - fp.y;  by = pow(by, v_sharp);
	
	vec3 tline = (urg*lx1+ulg*rx1)/(lx1+rx1);
	vec3 bline = (drg*lx2+dlg*rx2)/(lx2+rx2);
	vec3 color = (bline*uy+tline*by)/(uy+by);
	
// applying masks

	float m = fract((texcoord.y + 0.5/rubyTextureSize.y) * rubyTextureSize.y);
	vec3 mask = mix(vec3(-0.4, 1.0, -0.4), vec3(1.0, -0.4, 1.0), m);
	mask = mask/max(max(mask.r, mask.g),mask.b);
	color = mix(color, color*mask, mask_v);
	
// calculating scanlines

	float f = fract(texcoord.y * rubyTextureSize.y);
	
	float bw = mix(beam_min, beam_max, pow(max(max(color.r,color.g),color.b),0.7));
	float w1 = f / bw;
	float w2 = (1.0-f) / bw;
	
	color*= pow(clamp((sw(w1) + sw(w2)-cutoff)/(1.0-cutoff), 0.005, 1.0), 0.7)*1.2;
	
	color = pow(color, vec3(1.0/gammaOUT));
	
	float l = length(color);
	color = normalize(pow(color, vec3(saturation, saturation, saturation)))*l;	
	
	gl_FragColor = vec4(color*brightboost,1.0);
	}
    ]]></fragment>
	

</shader>
