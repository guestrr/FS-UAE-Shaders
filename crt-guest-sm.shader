<?xml version="1.0" encoding="UTF-8"?>
<!--
/*
   CRT - Guest - SM (Scanline Mask) Shader
   
   Copyright (C) 2019 guest(r) - guest.r@gmail.com

   Big thanks to Nesguy from the Libretro forums for the masks and other ideas.
   
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

/*   README - MASKS GUIDE

To obtain the best results with masks 0, 1, 3, 4: 
must leave “mask size” at 1 and the display must be set to its native resolution to result in evenly spaced “active” LCD subpixels.

Mask 0: Uses a magenta and green pattern for even spacing of the LCD subpixels.

Mask 1: Intended for displays that have RBG subpixels (as opposed to the more common RGB). 
Uses a yellow/blue pattern for even spacing of the LCD subpixels.

Mask 2: Common red/green/blue pattern.

Mask 3: This is useful for 4K displays, where masks 0 and 1 can look too fine. 
Uses a red/yellow/cyan/blue pattern to result in even spacing of the LCD subpixels.

Mask 4: Intended for displays that have the less common RBG subpixel pattern. 
This is useful for 4K displays, where masks 0 and 1 can look too fine. 
Uses a red/magenta/cyan/green pattern for even spacing of the LCD subpixels.

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

#define smart        1.00     // smart Y integer scaling 0.0 - OFF, 1.0 - ON
#define brightboost  1.40     // adjust brightness
#define scanline     8.00     // scanline param, vertical sharpness
#define beam_min     1.20     // dark area beam min - narrow
#define beam_max     1.00     // bright area beam max - wide
#define s_gamma      2.40     // scanline gamma
#define h_sharp      2.00     // pixel sharpness (from 1.0 to 5.0)
#define mask         0.00     // crt mask type   (from 0.0 to 4.0)
#define maskdark     1.00     // crt mask strength dark pixels (from 0.0 to 1.5)
#define maskbright   0.15     // crt mask strength bright pixels (from 0.0 to 1.0)
#define masksize     1.00     // crt mask size  (1.0 or 2.0 - for 4k)
#define gamma_out    2.20     // gamma out


#define eps 1e-8

	
float st(float x)
{
	return exp2(-10.0*x*x);
}  

vec3 sw(float x, vec3 color)
{
	vec3 tmp = mix(vec3(2.75*beam_min),vec3(beam_max), color);
	tmp = mix(vec3(beam_max), tmp, pow(vec3(x), color + 0.25));
	vec3 ex = vec3(x)*tmp;
	return exp2(-scanline*ex*ex)/(0.65 + 0.35*color);
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
	vec2 texcoord = tex;
	
if ( smart == 1.0)
{
	vec2 factor = rubyOutputSize/rubyInputSize;
	vec2 intfactor = round(factor);
	vec2 diff = factor/intfactor;
	texcoord = Overscan(tex*(rubyTextureSize/rubyInputSize), diff.x, diff.y)*(rubyInputSize/rubyTextureSize); 
	texcoord.x = tex.x;
}

	vec2 size     = rubyTextureSize;
	vec2 inv_size = 1.0/rubyTextureSize;
	
	vec2 OGL2Pos = texcoord * size  - vec2(0.5,0.5);
	vec2 fp = fract(OGL2Pos);
	vec2 dx = vec2(inv_size.x,0.0);
	vec2 dy = vec2(0.0, inv_size.y);
	vec2 g1 = vec2(inv_size.x,inv_size.y);
	
	vec2 pC4 = floor(OGL2Pos) * inv_size + 0.5*inv_size;	
	
	// Reading the texels
	vec3 ul = texture2D(rubyTexture, pC4     ).xyz; ul*=ul;
	vec3 ur = texture2D(rubyTexture, pC4 + dx).xyz; ur*=ur;
	vec3 dl = texture2D(rubyTexture, pC4 + dy).xyz; dl*=dl;
	vec3 dr = texture2D(rubyTexture, pC4 + g1).xyz; dr*=dr;
	
	float lx = fp.x;        lx = pow(lx, h_sharp);
	float rx = 1.0 - fp.x;  rx = pow(rx, h_sharp);
	
	float w = 1.0/(lx+rx);
	
	vec3 color1 = w*(ur*lx + ul*rx);
	vec3 color2 = w*(dr*lx + dl*rx);


	ul*=ul*ul; ul*=ul;
	ur*=ur*ur; ur*=ur;
	dl*=dl*dl; dl*=dl;
	dr*=dr*dr; dr*=dr;	
	
	vec3 scolor1 = w*(ur*lx + ul*rx); scolor1 = pow(scolor1, vec3(s_gamma*(1.0/12.0)));
	vec3 scolor2 = w*(dr*lx + dl*rx); scolor2 = pow(scolor2, vec3(s_gamma*(1.0/12.0)));	
	
// calculating scanlines
	
	float f = fp.y;

	float t1 = st(f);
	float t2 = st(1.0-f);
	
	vec3 color = color1*t1 + color2*t2;
	vec3 scolor = scolor1*t1 + scolor2*t2;
	
	vec3 ctemp = color / (t1 + t2);
	vec3 sctemp = scolor / (t1 + t2);
	
	vec3 cref1 = mix(scolor1, sctemp, 0.35);
	vec3 cref2 = mix(scolor2, sctemp, 0.35);
	
	vec3 w1 = sw(f,cref1);
	vec3 w2 = sw(1.0-f,cref2);
	
	color = color1*w1 + color2*w2;
	color = min(color, 1.0);

	color = mix(color, normalize(ctemp + 1e-7)*length(color), 2.0*abs(f-0.5));	
	color*=brightboost;
	color = min(color, 1.0);
	
	vec3 scan3 = vec3(0.0);
	float spos = floor((gl_FragCoord.x * 1.000001)/masksize); float spos1 = 0.0;
	vec3 tmp1 = pow(sctemp, vec3(1.5/s_gamma));

	if (mask == 0.0)
	{
		spos1 = fract(spos*0.5);
		if      (spos1 < 0.5)  scan3.rb = color.rb;
		else                   scan3.g  = color.g;	
	}
	else
	if (mask == 1.0)
	{
		spos1 = fract(spos*0.5);
		if      (spos1 < 0.5)  scan3.rg = color.rg;
		else                   scan3.b  = color.b;
	}
	else
	if (mask == 2.0)
	{
		spos1 = fract(spos/3.0);
		if      (spos1 < 0.333)  scan3.r = color.r;
		else if (spos1 < 0.666)  scan3.g = color.g;
		else                     scan3.b = color.b;
	}
	else
	if (mask == 3.0)
	{
		spos1 = fract(spos*0.25);
		if      (spos1 < 0.25)  scan3.r = color.r;
		else if (spos1 < 0.50)  scan3.rg = color.rg;
		else if (spos1 < 0.75)  scan3.gb = color.gb;	
		else                    scan3.b  = color.b;	
	}
	else	
	{
		spos1 = fract(spos*0.25);
		if      (spos1 < 0.25)  scan3.r = color.r;
		else if (spos1 < 0.50)  scan3.rb = color.rb;
		else if (spos1 < 0.75)  scan3.gb = color.gb;
		else                    scan3.g =  color.g;
	}

	color = max(mix( mix(color, 1.25*scan3, maskdark), mix(color, scan3, maskbright), tmp1), 0.0);

	color = pow(color, vec3(1.0/gamma_out));

	gl_FragColor = vec4(color,1.0);
	}
	
]]></fragment>
	
</shader>
