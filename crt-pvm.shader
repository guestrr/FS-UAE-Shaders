<?xml version="1.0" encoding="UTF-8"?>
<!--
/*
   CRT - Guest - SM (Scanline Mask) Shader - PVM Edition
   
   Copyright (C) 2019-2020 guest(r) - guest.r@gmail.com
   
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
        uniform vec2 rubyTextureSize;

        void main()
        {
                gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
                gl_TexCoord[0] = gl_MultiTexCoord0;
        }
]]></vertex>

	
<fragment outscale_x = "1.0"  outscale_y = "1.0" filter="linear"><![CDATA[
	
uniform sampler2D rubyTexture;
uniform sampler2D rubyOrigTexture;
uniform vec2 rubyInputSize;
uniform vec2 rubyOutputSize;
uniform vec2 rubyTextureSize;


#define bglow 0.017         // base glow value
#define autobrm 0.6        // automatic brightness for masks 0.0 to 1.0
#define smart 1.0          // "0.0:OFF 1:Smart 2:Crop 3:Overscan Y Integer Scaling"
#define brightboost1 1.25  // brightboost dark pixels
#define brightboost2 1.05 // brightboost bright pixels
#define bloom 0.40         // bloom strength 
#define stype 2.0          // scanline type 0.0, 1.0, 2.0  
#define scanline1 5.0      // Scanline Shape Center
#define scanline2 15.0     // Scanline Shape Edges
#define beam_min 1.60      // Scanline dark pixels
#define beam_max 2.00      // Scanline bright pixels
#define sclip 0.60         // Allow Scanline/Mask Clipping With Bloom 0.0 - 1.0
#define s_beam 0.20        // Overgrown Bright Beam 0.0 - 1.0 
#define h_sharp 5.0        // Horizontal sharpness 1.0 - 10.0
#define cubic 1.0          // 'Cubic filtering'  0.0 - 1.0
#define mask 0.0           // CRT Mask (3&4 are 4k masks) 0.0 - 4.0
#define maskmode 1.0       // CRT Mask Mode: Classic, Fine, Coarse  0.0 - 2.0
#define maskdark 0.5       // CRT Mask Strength Dark Pixels  0.0 - 1.50
#define maskbright -0.25   // CRT Mask Strength Bright Pixels  -0.50 - 1.0
#define masksize 1.0       // CRT Mask size (2.0 is nice for 4k for masks 0.0-2.0) 1.0 or 2.0
#define gamma_out 2.1      // Output Gamma, input gamma is 2.0
#define vertmask  0.25     // Scanline colors -0.30 for Red-Blue or up to 0.30 for Mygenta-Green

	
float st(float x)
{
	return exp2(-10.0*x*x);
}   


vec3 sw0(vec3 x, vec3 color, float scan)
{
	vec3 tmp = mix(vec3(beam_min),vec3(beam_max), color);
	vec3 ex = x*tmp;
	vec3 res = exp2(-scan*ex*ex);
	float mx2 = max(max(res.r,res.g),res.b);
	return mix(vec3(mx2), res, 0.25 + 0.75*x);
}


vec3 sw1(vec3 x, vec3 color, float scan)
{
	float mx1 = max(max(color.r,color.g),color.b);	
	vec3 tmp = mix(vec3(2.50*beam_min),vec3(beam_max), color);
	tmp = mix(vec3(beam_max), tmp, pow(vec3(x), color + 0.30));
	vec3 ex = x*tmp;
	vec3 res = exp2(-scan*ex*ex);
	float mx2 = max(max(res.r,res.g),res.b);
	float br = clamp(mix(0.20, 0.50, 2.0*(beam_min-1.0)),0.10, 0.60);
	return mix(vec3(mx2), res, 0.25 + 0.75*x)/(1.0 - br + br*mx1);
}


vec3 sw2(vec3 x, vec3 color, float scan)
{	
	float mx1 = max(max(color.r,color.g),color.b);
	vec3 ex = mix(vec3(2.0*beam_min), vec3(beam_max), color);
	vec3 m = min(0.3 + 0.35*ex, 1.0);
	ex = x*ex; 
	vec3 xx = ex*ex;
	xx = mix(xx, ex*xx, m);
	vec3 res = exp2(-1.25*scan*xx);
	float mx2 = max(max(res.r,res.g),res.b);
	float br = clamp(mix(0.10, 0.45, 2.0*(beam_min-1.0)),0.10, 0.60);
	return mix(vec3(mx2), res, 0.25 + 0.75*x)/(1.0 - br + br*mx1);
}


float Overscan(float pos, float dy){
	pos=pos*2.0-1.0;    
	pos*=dy;
	return pos*0.5+0.5;
}


vec3 declip(vec3 c, float b)
{
	float m = max(max(c.r,c.g),c.b);
	if (m > b) c = c*b/m;
	return c;
}


vec3 gc (vec3 c, float bd, float bb)
{
	float m = max(max(c.r,c.g),c.b);
	float b2 = mix(bd, bb, pow(m,0.70));
	return b2*c;
}


void main()
{
	// Calculating texel coordinates

	vec2 tex = gl_TexCoord[0].xy*1.00001;
	
	if (smart == 1.0 || smart == 2.0 || smart == 3.0)
	{
		float factor = rubyOutputSize.y/rubyInputSize.y;		
		float intfactor = floor(factor+0.5); if (smart == 2.0) intfactor = floor(factor); if (smart == 3.0) intfactor = ceil(factor);
		float diff = factor/intfactor;
		tex.y = Overscan(tex.y*(rubyTextureSize.y/rubyInputSize.y), diff)*(rubyInputSize.y/rubyTextureSize.y); 
	}

	vec2 size     = rubyTextureSize;
	vec2 inv_size = 1.0/rubyTextureSize;
	
	vec2 OGL2Pos = tex * size  - vec2(0.5,0.5);
	vec2 fp = fract(OGL2Pos);
	
	vec2 pC4 = floor(OGL2Pos) * inv_size + 0.5*inv_size;	
	
	// Reading the texels
	vec2 dx = vec2(inv_size.x,0.0);
	vec2 dy = vec2(0.0,inv_size.y);
	vec2 x2 = dx+dx;
	float zero = mix(0.0, exp2(-h_sharp), cubic);
	
	float wl2 = 1.0 + fp.x;	
	float wl1 =       fp.x;
	float wr1 = 1.0 - fp.x;
	float wr2 = 2.0 - fp.x;

	wl2*=wl2; wl2 = exp2(-h_sharp*wl2);	float sl2 = wl2;
	wl1*=wl1; wl1 = exp2(-h_sharp*wl1);	float sl1 = wl1;
	wr1*=wr1; wr1 = exp2(-h_sharp*wr1);	float sr1 = wr1;
	wr2*=wr2; wr2 = exp2(-h_sharp*wr2);	float sr2 = wr2;

	wl2 = max(wl2 - zero, mix(0.0,mix(-0.17, -0.005, fp.x),float(cubic > 0.05)));
	wl1 = max(wl1 - zero, 0.0);
	wr1 = max(wr1 - zero, 0.0);	
	wr2 = max(wr2 - zero, mix(0.0,mix(-0.17, -0.005, 1.-fp.x),float(cubic > 0.05)));

	float wtt =  1.0/(wl2+wl1+wr1+wr2);
	float wts =  1.0/(sl2+sl1+sr1+sr2);

	vec3 l2 = texture2D(rubyOrigTexture, pC4 - dx).rgb; l2*=l2;
	vec3 l1 = texture2D(rubyOrigTexture, pC4     ).rgb; l1*=l1;
	vec3 r1 = texture2D(rubyOrigTexture, pC4 + dx).rgb; r1*=r1;
	vec3 r2 = texture2D(rubyOrigTexture, pC4 + x2).rgb; r2*=r2;
	
	vec3 color1 = (wl2*l2+wl1*l1+wr1*r1+wr2*r2)*wtt;
	
	vec3 colmin = min(min(l2,l1),min(r1,r2));
	vec3 colmax = max(max(l2,l1),max(r1,r2));
	
	if (cubic > 0.05) color1 = clamp(color1, colmin, colmax);
	
	l1*=l1*l1; l1*=l1; r1*=r1*r1; r1*=r1; l2*=l2*l2; l2*=l2; r2*=r2*r2; r2*=r2;
	vec3 scolor1 = (sl2*l2+sl1*l1+sr1*r1+sr2*r2)*wts;
	scolor1 = pow(scolor1, vec3(1.0/5.0)); vec3 mscolor1 = scolor1;
	
	scolor1 = mix(color1, scolor1, 1.0);
	
	pC4+=dy;
	l2 = texture2D(rubyOrigTexture, pC4 - dx).rgb; l2*=l2;
	l1 = texture2D(rubyOrigTexture, pC4     ).rgb; l1*=l1;
	r1 = texture2D(rubyOrigTexture, pC4 + dx).rgb; r1*=r1;
	r2 = texture2D(rubyOrigTexture, pC4 + x2).rgb; r2*=r2;
	
	vec3 color2 = (wl2*l2+wl1*l1+wr1*r1+wr2*r2)*wtt;
	
	colmin = min(min(l2,l1),min(r1,r2));
	colmax = max(max(l2,l1),max(r1,r2));
	
	if (cubic > 0.05) color2 = clamp(color2, colmin, colmax);
	
	l1*=l1*l1; l1*=l1; r1*=r1*r1; r1*=r1; l2*=l2*l2; l2*=l2; r2*=r2*r2; r2*=r2;
	vec3 scolor2 = (sl2*l2+sl1*l1+sr1*r1+sr2*r2)*wts;
	scolor2 = pow(scolor2, vec3(1.0/5.0)); vec3 mscolor2 = scolor2;
	
	scolor2 = mix(color2, scolor2, 1.0);
	
	float f1 = fp.y;
	float f2 = 1.0 - fp.y;

	vec3 shift = vec3(-vertmask, vertmask, -vertmask); if (vertmask < 0.0) shift = shift.grr;

	vec3 sf1 = vec3(f1); 
	vec3 sf2 = vec3(f2);
	
	sf1 = max(f1 + shift * min(mix(0.25, 3.5, f1), 1.0), 0.7*f1); 
	sf2 = max(f2 - shift * min(mix(0.25, 3.5, f2), 1.0), 0.7*f2); 
	
	vec3 color;
	float t1 = st(f1);
	float t2 = st(f2);
	float wt = 1.0/(t1+t2);
	
// calculating scanlines

	float scan1 = mix(scanline1, scanline2, f1);
	float scan2 = mix(scanline1, scanline2, f2);
	
	vec3 sctemp = (t1*scolor1 + t2*scolor2)*wt;
	vec3 msctemp = (t1*mscolor1 + t2*mscolor2)*wt;
	vec3 ctemp = (t1*color1 + t2*color2)*wt; 
	vec3 orig = ctemp;
	float pixbr = max(max(orig.r,orig.g),orig.b);	
	
	vec3 ref1 = mix(sctemp, scolor1.rgb, s_beam); ref1 = pow(ref1, mix(vec3(1.20), vec3(0.70), pixbr));
	vec3 ref2 = mix(sctemp, scolor2.rgb, s_beam); ref2 = pow(ref2, mix(vec3(1.20), vec3(0.70), pixbr));
	
	vec3 w1, w2 = vec3(0.0);

	if (stype < 0.5)
	{
		w1 = sw0(sf1, ref1, scan1);
		w2 = sw0(sf2, ref2, scan2);
	} 
	else
	if (stype < 1.5)
	{
		w1 = sw1(sf1, ref1, scan1);
		w2 = sw1(sf2, ref2, scan2);
	}	
	else
	{
		w1 = sw2(sf1, ref1, scan1);
		w2 = sw2(sf2, ref2, scan2);
	}
	
	vec3 one = vec3(1.0);
	vec3 tmp1 = clamp(mix(orig, msctemp, 1.5),0.0,1.0);	
	ctemp = w1+w2;
	float w3 = max(max(ctemp.r,ctemp.g),ctemp.b);	
	
	tmp1 = pow(tmp1, vec3(0.75));
	float pixbr1 = max(max(tmp1.r,tmp1.g),tmp1.b);
	
	float maskd = mix(min(maskdark,1.0), 0.25*max(maskbright,0.0), pixbr1); if (mask == 2.0) maskd*=1.33; maskd = mix(1.0, 1.0/(1.0-0.5*maskd), autobrm);
	maskd = mix(maskd, 1.0, pow(pixbr,0.75));	
	
	float brightboost_d = brightboost1;
	float brightboost_b = brightboost2;

	if (stype < 0.5) maskd = 1.0;
	
	color1 = gc(color1, brightboost_d, brightboost_b);
	color2 = gc(color2, brightboost_d, brightboost_b);
	
	color1 = min(color1, 1.0);
	color2 = min(color2, 1.0);	
	
	color = w1*color1.rgb + w2*color2.rgb;
	color = maskd*color;
	//color = min(color, 1.0);
	
	vec3 scan3 = vec3(0.0);

	float spos  = (gl_FragCoord.x);
	float spos2 = floor(1.000001*gl_FragCoord.x/masksize) + floor(1.000001*gl_FragCoord.y/masksize);
	
	spos  = floor((spos  * 1.000001)/masksize); float spos1 = 0.0;


	if (mask < 1.5)
	{
		if (mask > 0.5) spos = spos2;
		spos1 = fract(spos*0.5);
		if      (spos1 < 0.3)  scan3.rb = one.rb;
		else                   scan3.g  = one.g;	
	}
	else
	if (mask < 2.5)
	{
		spos1 = fract(spos/3.0);
		if      (spos1 < 0.3)  scan3.r = one.r;
		else if (spos1 < 0.6)  scan3.g = one.g;
		else                   scan3.b = one.b;
	}
	else
	if (mask < 3.5)
	{
		spos1 = fract(spos*0.25);
		if      (spos1 < 0.2)  scan3.r  = one.r;
		else if (spos1 < 0.4)  scan3.rg = one.rg;
		else if (spos1 < 0.6)  scan3.gb = one.gb;	
		else                   scan3.b  = one.b;	
	}
	else	
	{
		spos1 = fract(spos*0.25);
		if      (spos1 < 0.2)  scan3.r  = one.r;
		else if (spos1 < 0.4)  scan3.rb = one.rb;
		else if (spos1 < 0.6)  scan3.gb = one.gb;
		else                   scan3.g  = one.g; 
	}
	
	vec3 mixmask = tmp1;
	if (maskmode == 1.0) mixmask = vec3(pixbr1); else
	if (maskmode == 2.0) mixmask = tmp1*w3;
	
	vec3 cmask = clamp(mix( mix(one, scan3, maskdark), mix(one, scan3, maskbright), mixmask), 0.0, 1.0);
	vec3 orig1 = color;
	color = color*cmask;
	
	vec3 Bloom = texture2D(rubyTexture, tex).rgb;
	vec3 Bglow = Bloom;
	
	vec3 Bloom1 = 2.0*Bloom*Bloom;
	Bloom1 = min(Bloom1, 0.75);
	float bmax = max(max(Bloom1.r,Bloom1.g),Bloom1.b);
	float pmax = 0.8;
	Bloom1 = min(Bloom1, pmax*bmax)/pmax;
	
	Bloom1 = mix(min( Bloom1, color), Bloom1, 0.5*(orig1+color));
	Bloom1 = Bloom1*mix(w1+w2,one,1.0-pixbr);

	vec3 bmask = mix(cmask,one,sclip);
	Bloom1 = bloom*Bloom1*bmask;
	
	color = color + Bloom1;
	color = min(color,1.0);
	color = declip(color, pow(w3, 1.0-sclip));		

	color = color + bglow*Bglow;
	color = min(color, bmask);
	
	float fgamma = 1.0/gamma_out;
	vec3 color1g = pow(color, vec3(fgamma));

	gl_FragColor = vec4(color1g,1.0);
	}
	
]]></fragment>
	
</shader>
