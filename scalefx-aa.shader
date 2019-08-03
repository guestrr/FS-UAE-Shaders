<?xml version="1.0" encoding="UTF-8"?>
<shader language="GLSL">

/*
	ScaleFX - 5 Passes
	by Sp00kyFox, 2017-03-01 

ScaleFX is an edge interpolation algorithm specialized in pixel art. It was
originally intended as an improvement upon Scale3x but became a new filter in
its own right.
ScaleFX interpolates edges up to level 6 and makes smooth transitions between
different slopes. The filtered picture will only consist of colours present
in the original.

Pass 0 prepares metric data for the next pass.
Pass 1 calculates the strength of interpolation candidates.
Pass 2 resolves ambiguous configurations of corner candidates at pixel junctions.
Pass 3 determines which edge level is present and prepares tags for subpixel output in the final pass. 
Pass 4 outputs subpixels based on previously calculated tags.

Copyright (c) 2016 Sp00kyFox - ScaleFX@web.de

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

ported to XML format by guest.r
*/

// ScaleFX pass 0
<vertex><![CDATA[
uniform vec2 rubyTextureSize;

void main(void) {
    gl_Position = ftransform();
    gl_TexCoord[0] = gl_MultiTexCoord0;
}
]]></vertex>

<fragment scale="1.0" filter="nearest"><![CDATA[
uniform sampler2D rubyTexture;

// Reference: http://www.compuphase.com/cmetric.htm
float dist(vec3 A, vec3 B)
{
	float r = 0.5 * (A.r + B.r);
	vec3 d = A - B;
	vec3 c = vec3(2. + r, 4., 3. - r);

	return sqrt(dot(c*d, d)) / 3.;
}

void main()
{
	/*	grid		metric

		A B C		x y z
		  E F		  o w
	*/
	
#define TEX(x, y) textureOffset(rubyTexture, gl_TexCoord[0].xy, ivec2(x, y)).rgb
	// read texels
	vec3 A = TEX(-1,-1);
	vec3 B = TEX( 0,-1);
	vec3 C = TEX( 1,-1);
	vec3 E = TEX( 0, 0);
	vec3 F = TEX( 1, 0); 

	// output
	gl_FragColor = vec4(dist(E,A), dist(E,B), dist(E,C), dist(E,F)); 
}	
]]></fragment>



// ScaleFX pass 1
<vertex><![CDATA[
uniform vec2 rubyTextureSize;

void main(void) {
    gl_Position = ftransform();
    gl_TexCoord[0] = gl_MultiTexCoord0;
	gl_TexCoord[0].xy*=vec2(2.0,1.0);	
}
]]></vertex>

<fragment scale_x="2.0" scale_y="1.0" filter="nearest"><![CDATA[
uniform sampler2D rubyTexture;
uniform vec2 rubyTextureSize;
uniform vec2 rubyInputSize;

#define SFX_CLR 0.6
#define SFX_SAA 1.0


// corner strength
float str(float d, vec2 a, vec2 b){
	float diff = a.x - a.y;
	float wght1 = max(SFX_CLR - d, 0.) / SFX_CLR;
	float wght2 = clamp((1.-d) + (min(a.x, b.x) + a.x > min(a.y, b.y) + a.y ? diff : -diff), 0., 1.);
	return (SFX_SAA == 1. || 2.*d < a.x + a.y) ? (wght1 * wght2) * (a.x * a.y) : 0.;
} 

void main()
{
	/*	grid		metric		pattern

		A B		x y z	x y
		D E F	o w		w z
		G H I
	*/ 
	
#define TEX(x, y) textureOffset(rubyTexture, gl_TexCoord[0].xy, ivec2(x, y))

	// metric data
	vec4 A = TEX(-1,-1), B = TEX( 0,-1);
	vec4 D = TEX(-1, 0), E = TEX( 0, 0), F = TEX( 1, 0);
	vec4 G = TEX(-1, 1), H = TEX( 0, 1), I = TEX( 1, 1);  

	// corner strength
	vec4 res;
	res.x = str(D.z, vec2(D.w, E.y), vec2(A.w, D.y));
	res.y = str(F.x, vec2(E.w, E.y), vec2(B.w, F.y));
	res.z = str(H.z, vec2(E.w, H.y), vec2(H.w, I.y));
	res.w = str(H.x, vec2(D.w, H.y), vec2(G.w, G.y));

	if (gl_TexCoord[0].x >= rubyInputSize.x/rubyTextureSize.x) res = texture2D(rubyTexture, gl_TexCoord[0].xy - vec2(rubyInputSize.x/rubyTextureSize.x,0.0));
	
	gl_FragColor = res; 
}	
]]></fragment>


// ScaleFX pass 2
<vertex><![CDATA[
uniform vec2 rubyTextureSize;

void main(void) {
    gl_Position = ftransform();
    gl_TexCoord[0] = gl_MultiTexCoord0;
}
]]></vertex>

<fragment scale_x="0.5" scale_y="1.0" filter="nearest"><![CDATA[
uniform sampler2D rubyTexture;
uniform vec2 rubyTextureSize;
uniform vec2 rubyInputSize;

#define LE(x, y) (1. - step(y, x))
#define GE(x, y) (1. - step(x, y))
#define LEQ(x, y) step(x, y)
#define GEQ(x, y) step(y, x)
#define NOT(x) (1. - (x))

// corner dominance at junctions
vec4 dom(vec3 x, vec3 y, vec3 z, vec3 w){
	return 2. * vec4(x.y, y.y, z.y, w.y) - (vec4(x.x, y.x, z.x, w.x) + vec4(x.z, y.z, z.z, w.z));
}

// necessary but not sufficient junction condition for orthogonal edges
float clear(vec2 crn, vec2 a, vec2 b){
	return (crn.x >= max(min(a.x, a.y), min(b.x, b.y))) && (crn.y >= max(min(a.x, b.y), min(b.x, a.y))) ? 1. : 0.;
}
 

void main()
{
	/*	grid		metric		pattern

		A B C		x y z		x y
		D E F		  o w		w z
		G H I
	*/ 
	
	vec2 c0 = vec2(0.5,1.0)*gl_TexCoord[0].xy;
	vec2 cp = vec2(0.5,1.0)*gl_TexCoord[0].xy + vec2(0.5*rubyInputSize.x/rubyTextureSize.x,0.0);
	
	#define TEXm(x, y) textureOffset(rubyTexture, cp, ivec2(x, y))
	#define TEXs(x, y) textureOffset(rubyTexture, c0, ivec2(x, y))

	// metric data
	vec4 A = TEXm(-1,-1); vec4 B = TEXm( 0,-1);
	vec4 D = TEXm(-1, 0); vec4 E = TEXm( 0, 0); vec4 F = TEXm( 1, 0);
	vec4 G = TEXm(-1, 1); vec4 H = TEXm( 0, 1); vec4 I = TEXm( 1, 1);	

	// strength data
	vec4 As = TEXs(-1,-1), Bs = TEXs( 0,-1), Cs = TEXs( 1,-1);
	vec4 Ds = TEXs(-1, 0), Es = TEXs( 0, 0), Fs = TEXs( 1, 0);
	vec4 Gs = TEXs(-1, 1), Hs = TEXs( 0, 1), Is = TEXs( 1, 1); 

	// strength & dominance junctions
	vec4 jSx = vec4(As.z, Bs.w, Es.x, Ds.y), jDx = dom(As.yzw, Bs.zwx, Es.wxy, Ds.xyz);
	vec4 jSy = vec4(Bs.z, Cs.w, Fs.x, Es.y), jDy = dom(Bs.yzw, Cs.zwx, Fs.wxy, Es.xyz);
	vec4 jSz = vec4(Es.z, Fs.w, Is.x, Hs.y), jDz = dom(Es.yzw, Fs.zwx, Is.wxy, Hs.xyz);
	vec4 jSw = vec4(Ds.z, Es.w, Hs.x, Gs.y), jDw = dom(Ds.yzw, Es.zwx, Hs.wxy, Gs.xyz);


	// majority vote for ambiguous dominance junctions
	vec4 zero4 = vec4(0.);
	vec4 jx = min(GE(jDx, zero4) * (LEQ(jDx.yzwx, zero4) * LEQ(jDx.wxyz, zero4) + GE(jDx + jDx.zwxy, jDx.yzwx + jDx.wxyz)), 1.);
	vec4 jy = min(GE(jDy, zero4) * (LEQ(jDy.yzwx, zero4) * LEQ(jDy.wxyz, zero4) + GE(jDy + jDy.zwxy, jDy.yzwx + jDy.wxyz)), 1.);
	vec4 jz = min(GE(jDz, zero4) * (LEQ(jDz.yzwx, zero4) * LEQ(jDz.wxyz, zero4) + GE(jDz + jDz.zwxy, jDz.yzwx + jDz.wxyz)), 1.);
	vec4 jw = min(GE(jDw, zero4) * (LEQ(jDw.yzwx, zero4) * LEQ(jDw.wxyz, zero4) + GE(jDw + jDw.zwxy, jDw.yzwx + jDw.wxyz)), 1.);


	// inject strength without creating new contradictions
	vec4 res;
	res.x = min(jx.z + NOT(jx.y) * NOT(jx.w) * GE(jSx.z, 0.) * (jx.x + GE(jSx.x + jSx.z, jSx.y + jSx.w)), 1.);
	res.y = min(jy.w + NOT(jy.z) * NOT(jy.x) * GE(jSy.w, 0.) * (jy.y + GE(jSy.y + jSy.w, jSy.x + jSy.z)), 1.);
	res.z = min(jz.x + NOT(jz.w) * NOT(jz.y) * GE(jSz.x, 0.) * (jz.z + GE(jSz.x + jSz.z, jSz.y + jSz.w)), 1.);
	res.w = min(jw.y + NOT(jw.x) * NOT(jw.z) * GE(jSw.y, 0.) * (jw.w + GE(jSw.y + jSw.w, jSw.x + jSw.z)), 1.);	


	// single pixel & end of line detection
	res = min(res * (vec4(jx.z, jy.w, jz.x, jw.y) + NOT(res.wxyz * res.yzwx)), 1.);


	// output

	vec4 clr;
	clr.x = clear(vec2(D.z, E.x), vec2(D.w, E.y), vec2(A.w, D.y));
	clr.y = clear(vec2(F.x, E.z), vec2(E.w, E.y), vec2(B.w, F.y));
	clr.z = clear(vec2(H.z, I.x), vec2(E.w, H.y), vec2(H.w, I.y));
	clr.w = clear(vec2(H.x, G.z), vec2(D.w, H.y), vec2(G.w, G.y));

	vec4 h = vec4(min(D.w, A.w), min(E.w, B.w), min(E.w, H.w), min(D.w, G.w));
	vec4 v = vec4(min(E.y, D.y), min(E.y, F.y), min(H.y, I.y), min(H.y, G.y));

	vec4 or   = GE(h + vec4(D.w, E.w, E.w, D.w), v + vec4(E.y, E.y, H.y, H.y));	// orientation
	vec4 hori = LE(h, v) * clr;	// horizontal edges
	vec4 vert = GE(h, v) * clr;	// vertical edges

	gl_FragColor = (res + 2. * hori + 4. * vert + 8. * or) / 15.; 
}	
]]></fragment>


// ScaleFX pass 3
<vertex><![CDATA[
uniform vec2 rubyTextureSize;

void main(void) {
    gl_Position = ftransform();
    gl_TexCoord[0] = gl_MultiTexCoord0;
}
]]></vertex>

<fragment scale="1.0" filter="nearest"><![CDATA[
uniform sampler2D rubyTexture;

#define SFX_SCN 0.0

// extract first bool4 from vec4 - corners
bvec4 loadCorn(vec4 x){
	return bvec4(floor(mod(x*15. + 0.5, 2.)));
}

// extract second bool4 from vec4 - horizontal edges
bvec4 loadHori(vec4 x){
	return bvec4(floor(mod(x*7.5 + 0.25, 2.)));
}

// extract third bool4 from vec4 - vertical edges
bvec4 loadVert(vec4 x){
	return bvec4(floor(mod(x*3.75 + 0.125, 2.)));
}

// extract fourth bool4 from vec4 - orientation
bvec4 loadOr(vec4 x){
	return bvec4(floor(mod(x*1.875 + 0.0625, 2.)));
} 

void main()
{
	/*	grid		corners		mids		

		  B		x   y	  	  x
		D E F				w   y
		  H		w   z	  	  z
	*/ 
#define TEX(x, y) textureOffset(rubyTexture, gl_TexCoord[0].xy, ivec2(x, y))

	// read data
	vec4 E = TEX( 0, 0);
	vec4 D = TEX(-1, 0), D0 = TEX(-2, 0), D1 = TEX(-3, 0);
	vec4 F = TEX( 1, 0), F0 = TEX( 2, 0), F1 = TEX( 3, 0);
	vec4 B = TEX( 0,-1), B0 = TEX( 0,-2), B1 = TEX( 0,-3);
	vec4 H = TEX( 0, 1), H0 = TEX( 0, 2), H1 = TEX( 0, 3); 
	
	// extract data
	bvec4 Ec = loadCorn(E), Eh = loadHori(E), Ev = loadVert(E), Eo = loadOr(E);
	bvec4 Dc = loadCorn(D),	Dh = loadHori(D), Do = loadOr(D), D0c = loadCorn(D0), D0h = loadHori(D0), D1h = loadHori(D1);
	bvec4 Fc = loadCorn(F),	Fh = loadHori(F), Fo = loadOr(F), F0c = loadCorn(F0), F0h = loadHori(F0), F1h = loadHori(F1);
	bvec4 Bc = loadCorn(B),	Bv = loadVert(B), Bo = loadOr(B), B0c = loadCorn(B0), B0v = loadVert(B0), B1v = loadVert(B1);
	bvec4 Hc = loadCorn(H),	Hv = loadVert(H), Ho = loadOr(H), H0c = loadCorn(H0), H0v = loadVert(H0), H1v = loadVert(H1);

	
	// lvl1 corners (hori, vert)
	bool lvl1x = Ec.x && (Dc.z || Bc.z || SFX_SCN == 1.);
	bool lvl1y = Ec.y && (Fc.w || Bc.w || SFX_SCN == 1.);
	bool lvl1z = Ec.z && (Fc.x || Hc.x || SFX_SCN == 1.);
	bool lvl1w = Ec.w && (Dc.y || Hc.y || SFX_SCN == 1.);

	// lvl2 mid (left, right / up, down)
	bvec2 lvl2x = bvec2((Ec.x && Eh.y) && Dc.z, (Ec.y && Eh.x) && Fc.w);
	bvec2 lvl2y = bvec2((Ec.y && Ev.z) && Bc.w, (Ec.z && Ev.y) && Hc.x);
	bvec2 lvl2z = bvec2((Ec.w && Eh.z) && Dc.y, (Ec.z && Eh.w) && Fc.x);
	bvec2 lvl2w = bvec2((Ec.x && Ev.w) && Bc.z, (Ec.w && Ev.x) && Hc.y);

	// lvl3 corners (hori, vert)
	bvec2 lvl3x = bvec2(lvl2x.y && (Dh.y && Dh.x) && Fh.z, lvl2w.y && (Bv.w && Bv.x) && Hv.z);
	bvec2 lvl3y = bvec2(lvl2x.x && (Fh.x && Fh.y) && Dh.w, lvl2y.y && (Bv.z && Bv.y) && Hv.w);
	bvec2 lvl3z = bvec2(lvl2z.x && (Fh.w && Fh.z) && Dh.x, lvl2y.x && (Hv.y && Hv.z) && Bv.x);
	bvec2 lvl3w = bvec2(lvl2z.y && (Dh.z && Dh.w) && Fh.y, lvl2w.x && (Hv.x && Hv.w) && Bv.y);

	// lvl4 corners (hori, vert)
	bvec2 lvl4x = bvec2((Dc.x && Dh.y && Eh.x && Eh.y && Fh.x && Fh.y) && (D0c.z && D0h.w), (Bc.x && Bv.w && Ev.x && Ev.w && Hv.x && Hv.w) && (B0c.z && B0v.y));
	bvec2 lvl4y = bvec2((Fc.y && Fh.x && Eh.y && Eh.x && Dh.y && Dh.x) && (F0c.w && F0h.z), (Bc.y && Bv.z && Ev.y && Ev.z && Hv.y && Hv.z) && (B0c.w && B0v.x));
	bvec2 lvl4z = bvec2((Fc.z && Fh.w && Eh.z && Eh.w && Dh.z && Dh.w) && (F0c.x && F0h.y), (Hc.z && Hv.y && Ev.z && Ev.y && Bv.z && Bv.y) && (H0c.x && H0v.w));
	bvec2 lvl4w = bvec2((Dc.w && Dh.z && Eh.w && Eh.z && Fh.w && Fh.z) && (D0c.y && D0h.x), (Hc.w && Hv.x && Ev.w && Ev.x && Bv.w && Bv.x) && (H0c.y && H0v.z));

	// lvl5 mid (left, right / up, down)
	bvec2 lvl5x = bvec2(lvl4x.x && (F0h.x && F0h.y) && (D1h.z && D1h.w), lvl4y.x && (D0h.y && D0h.x) && (F1h.w && F1h.z));
	bvec2 lvl5y = bvec2(lvl4y.y && (H0v.y && H0v.z) && (B1v.w && B1v.x), lvl4z.y && (B0v.z && B0v.y) && (H1v.x && H1v.w));
	bvec2 lvl5z = bvec2(lvl4w.x && (F0h.w && F0h.z) && (D1h.y && D1h.x), lvl4z.x && (D0h.z && D0h.w) && (F1h.x && F1h.y));
	bvec2 lvl5w = bvec2(lvl4x.y && (H0v.x && H0v.w) && (B1v.z && B1v.y), lvl4w.y && (B0v.w && B0v.x) && (H1v.y && H1v.z));

	// lvl6 corners (hori, vert)
	bvec2 lvl6x = bvec2(lvl5x.y && (D1h.y && D1h.x), lvl5w.y && (B1v.w && B1v.x));
	bvec2 lvl6y = bvec2(lvl5x.x && (F1h.x && F1h.y), lvl5y.y && (B1v.z && B1v.y));
	bvec2 lvl6z = bvec2(lvl5z.x && (F1h.w && F1h.z), lvl5y.x && (H1v.y && H1v.z));
	bvec2 lvl6w = bvec2(lvl5z.y && (D1h.z && D1h.w), lvl5w.x && (H1v.x && H1v.w));

	
	// subpixels - 0 = E, 1 = D, 2 = D0, 3 = F, 4 = F0, 5 = B, 6 = B0, 7 = H, 8 = H0

	vec4 crn;
	crn.x = (lvl1x && Eo.x || lvl3x.x && Eo.y || lvl4x.x && Do.x || lvl6x.x && Fo.y) ? 5. : (lvl1x || lvl3x.y && !Eo.w || lvl4x.y && !Bo.x || lvl6x.y && !Ho.w) ? 1. : lvl3x.x ? 3. : lvl3x.y ? 7. : lvl4x.x ? 2. : lvl4x.y ? 6. : lvl6x.x ? 4. : lvl6x.y ? 8. : 0.;
	crn.y = (lvl1y && Eo.y || lvl3y.x && Eo.x || lvl4y.x && Fo.y || lvl6y.x && Do.x) ? 5. : (lvl1y || lvl3y.y && !Eo.z || lvl4y.y && !Bo.y || lvl6y.y && !Ho.z) ? 3. : lvl3y.x ? 1. : lvl3y.y ? 7. : lvl4y.x ? 4. : lvl4y.y ? 6. : lvl6y.x ? 2. : lvl6y.y ? 8. : 0.;
	crn.z = (lvl1z && Eo.z || lvl3z.x && Eo.w || lvl4z.x && Fo.z || lvl6z.x && Do.w) ? 7. : (lvl1z || lvl3z.y && !Eo.y || lvl4z.y && !Ho.z || lvl6z.y && !Bo.y) ? 3. : lvl3z.x ? 1. : lvl3z.y ? 5. : lvl4z.x ? 4. : lvl4z.y ? 8. : lvl6z.x ? 2. : lvl6z.y ? 6. : 0.;
	crn.w = (lvl1w && Eo.w || lvl3w.x && Eo.z || lvl4w.x && Do.w || lvl6w.x && Fo.z) ? 7. : (lvl1w || lvl3w.y && !Eo.x || lvl4w.y && !Ho.w || lvl6w.y && !Bo.x) ? 1. : lvl3w.x ? 3. : lvl3w.y ? 5. : lvl4w.x ? 2. : lvl4w.y ? 8. : lvl6w.x ? 4. : lvl6w.y ? 6. : 0.;

	vec4 mid;
	mid.x = (lvl2x.x &&  Eo.x || lvl2x.y &&  Eo.y || lvl5x.x &&  Do.x || lvl5x.y &&  Fo.y) ? 5. : lvl2x.x ? 1. : lvl2x.y ? 3. : lvl5x.x ? 2. : lvl5x.y ? 4. : (Ec.x && Dc.z && Ec.y && Fc.w) ? ( Eo.x ?  Eo.y ? 5. : 3. : 1.) : 0.;
	mid.y = (lvl2y.x && !Eo.y || lvl2y.y && !Eo.z || lvl5y.x && !Bo.y || lvl5y.y && !Ho.z) ? 3. : lvl2y.x ? 5. : lvl2y.y ? 7. : lvl5y.x ? 6. : lvl5y.y ? 8. : (Ec.y && Bc.w && Ec.z && Hc.x) ? (!Eo.y ? !Eo.z ? 3. : 7. : 5.) : 0.;
	mid.z = (lvl2z.x &&  Eo.w || lvl2z.y &&  Eo.z || lvl5z.x &&  Do.w || lvl5z.y &&  Fo.z) ? 7. : lvl2z.x ? 1. : lvl2z.y ? 3. : lvl5z.x ? 2. : lvl5z.y ? 4. : (Ec.z && Fc.x && Ec.w && Dc.y) ? ( Eo.z ?  Eo.w ? 7. : 1. : 3.) : 0.;
	mid.w = (lvl2w.x && !Eo.x || lvl2w.y && !Eo.w || lvl5w.x && !Bo.x || lvl5w.y && !Ho.w) ? 1. : lvl2w.x ? 5. : lvl2w.y ? 7. : lvl5w.x ? 6. : lvl5w.y ? 8. : (Ec.w && Hc.y && Ec.x && Bc.z) ? (!Eo.w ? !Eo.x ? 1. : 5. : 7.) : 0.;


	// ouput
	gl_FragColor = (crn + 9. * mid) / 80.; 
}	
]]></fragment>



// ScaleFX pass 4
<vertex><![CDATA[
uniform vec2 rubyTextureSize;
uniform vec2 rubyOrigTextureSize;

void main(void) {

    gl_Position = ftransform();
    gl_TexCoord[0] = gl_MultiTexCoord0;

	vec2 ps = 1.0/rubyOrigTextureSize;
	float dx = ps.x, dy = ps.y;

	gl_TexCoord[1] = gl_TexCoord[0].xxxy + vec4( 0, -dx, -2*dx,     0);	// E, D, D0
	gl_TexCoord[2] = gl_TexCoord[0].xyxy + vec4(dx,   0,  2*dx,     0);	// F, F0
	gl_TexCoord[3] = gl_TexCoord[0].xyxy + vec4( 0, -dy,     0, -2*dy);	// B, B0
	gl_TexCoord[4] = gl_TexCoord[0].xyxy + vec4( 0,  dy,     0,  2*dy);	// H, H0	
}

]]></vertex>

<fragment scale="3.0" filter="nearest"><![CDATA[
uniform sampler2D rubyTexture;
uniform sampler2D rubyOrigTexture;
uniform vec2 rubyTextureSize;

// extract corners
vec4 loadCrn(vec4 x){
	return floor(mod(x*80. + 0.5, 9.));
}

// extract mids
vec4 loadMid(vec4 x){
	return floor(mod(x*8.888888 + 0.055555, 9.));
}

void main()
{
	// read data
	vec4 E = texture2D(rubyTexture, gl_TexCoord[0].xy);

	// extract data
	vec4 crn = loadCrn(E);
	vec4 mid = loadMid(E);

	// determine subpixel
	vec2 fp = floor(3.0 * fract(gl_TexCoord[0].xy * rubyTextureSize));
	float sp = fp.y == 0. ? (fp.x == 0. ? crn.x : fp.x == 1. ? mid.x : crn.y) : (fp.y == 1. ? (fp.x == 0. ? mid.w : fp.x == 1. ? 0. : mid.y) : (fp.x == 0. ? crn.w : fp.x == 1. ? mid.z : crn.z));

	// output coordinate - 0 = E, 1 = D, 2 = D0, 3 = F, 4 = F0, 5 = B, 6 = B0, 7 = H, 8 = H0
	vec2 res = sp == 0. ? vec2(0.,0.) : sp == 1. ? vec2(-1.,0.) : sp == 2. ? vec2(-2.,0.) : sp == 3. ? vec2(1.,0.) : sp == 4. ? vec2(2.,0.) : sp == 5. ? vec2(0,-1) : sp == 6. ? vec2(0.,-2.) : sp == 7. ? vec2(0.,1.) : vec2(0.,2.);

	// ouput
	gl_FragColor = texture2D(rubyOrigTexture, gl_TexCoord[0].xy + res / rubyTextureSize); 
}	
]]></fragment>



<vertex><![CDATA[

void main(void) {
    gl_Position = ftransform();
    gl_TexCoord[0] = gl_MultiTexCoord0;
}
]]></vertex>


<fragment scale="1.0" filter="linear"><![CDATA[
uniform sampler2D rubyTexture;
uniform vec2 rubyTextureSize;

vec2 InvSize = 1.0/rubyTextureSize;

// FXAA newer version

/**
 * @license
 * Copyright (c) 2011 NVIDIA Corporation. All rights reserved.
 *
 * TO  THE MAXIMUM  EXTENT PERMITTED  BY APPLICABLE  LAW, THIS SOFTWARE  IS PROVIDED
 * *AS IS*  AND NVIDIA AND  ITS SUPPLIERS DISCLAIM  ALL WARRANTIES,  EITHER  EXPRESS
 * OR IMPLIED, INCLUDING, BUT NOT LIMITED  TO, NONINFRINGEMENT,IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  IN NO EVENT SHALL  NVIDIA 
 * OR ITS SUPPLIERS BE  LIABLE  FOR  ANY  DIRECT, SPECIAL,  INCIDENTAL,  INDIRECT,  OR  
 * CONSEQUENTIAL DAMAGES WHATSOEVER (INCLUDING, WITHOUT LIMITATION,  DAMAGES FOR LOSS 
 * OF BUSINESS PROFITS, BUSINESS INTERRUPTION, LOSS OF BUSINESS INFORMATION, OR ANY 
 * OTHER PECUNIARY LOSS) ARISING OUT OF THE  USE OF OR INABILITY  TO USE THIS SOFTWARE, 
 * EVEN IF NVIDIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
 */ 

/*
FXAA_PRESET - Choose compile-in knob preset 0-5.
------------------------------------------------------------------------------
FXAA_EDGE_THRESHOLD - The minimum amount of local contrast required 
                      to apply algorithm.
                      1.0/3.0  - too little
                      1.0/4.0  - good start
                      1.0/8.0  - applies to more edges
                      1.0/16.0 - overkill
------------------------------------------------------------------------------
FXAA_EDGE_THRESHOLD_MIN - Trims the algorithm from processing darks.
                          Perf optimization.
                          1.0/32.0 - visible limit (smaller isn't visible)
                          1.0/16.0 - good compromise
                          1.0/12.0 - upper limit (seeing artifacts)
------------------------------------------------------------------------------
FXAA_SEARCH_STEPS - Maximum number of search steps for end of span.
------------------------------------------------------------------------------
FXAA_SEARCH_THRESHOLD - Controls when to stop searching.
                        1.0/4.0 - seems to be the best quality wise
------------------------------------------------------------------------------
FXAA_SUBPIX_TRIM - Controls sub-pixel aliasing removal.
                   1.0/2.0 - low removal
                   1.0/3.0 - medium removal
                   1.0/4.0 - default removal
                   1.0/8.0 - high removal
                   0.0 - complete removal
------------------------------------------------------------------------------
FXAA_SUBPIX_CAP - Insures fine detail is not completely removed.
                  This is important for the transition of sub-pixel detail,
                  like fences and wires.
                  3.0/4.0 - default (medium amount of filtering)
                  7.0/8.0 - high amount of filtering
                  1.0 - no capping of sub-pixel aliasing removal
*/ 

#ifndef FXAA_PRESET
    #define FXAA_PRESET 3
#endif
#if (FXAA_PRESET == 3)
    #define FXAA_EDGE_THRESHOLD      (1.0/16.0)
    #define FXAA_EDGE_THRESHOLD_MIN  (1.0/16.0)
    #define FXAA_SEARCH_STEPS        16
    #define FXAA_SEARCH_THRESHOLD    (1.0/4.0)
    #define FXAA_SUBPIX_CAP          (3.0/4.0)
    #define FXAA_SUBPIX_TRIM         (1.0/4.0)
#endif
#if (FXAA_PRESET == 4)
    #define FXAA_EDGE_THRESHOLD      (1.0/8.0)
    #define FXAA_EDGE_THRESHOLD_MIN  (1.0/24.0)
    #define FXAA_SEARCH_STEPS        24
    #define FXAA_SEARCH_THRESHOLD    (1.0/4.0)
    #define FXAA_SUBPIX_CAP          (3.0/4.0)
    #define FXAA_SUBPIX_TRIM         (1.0/8.0)
#endif
#if (FXAA_PRESET == 5)
    #define FXAA_EDGE_THRESHOLD      (1.0/16.0)
    #define FXAA_EDGE_THRESHOLD_MIN  (1.0/12.0)
    #define FXAA_SEARCH_STEPS        32
    #define FXAA_SEARCH_THRESHOLD    (1.0/4.0)
    #define FXAA_SUBPIX_CAP          (7.0/8.0)
    #define FXAA_SUBPIX_TRIM         (1.0/8.0)
#endif

#define FXAA_SUBPIX_TRIM_SCALE (1.0/(1.0 - FXAA_SUBPIX_TRIM))
 
#define FXAA_SUBPIX_TRIM_SCALE (1.0/(1.0 - FXAA_SUBPIX_TRIM))

// Return the luma, the estimation of luminance from rgb inputs.
// This approximates luma using one FMA instruction,
// skipping normalization and tossing out blue.
// FxaaLuma() will range 0.0 to 2.963210702.

float FxaaLuma(vec3 rgb) {
    return rgb.y * (0.587/0.299) + rgb.x;
}

vec3 FxaaLerp3(vec3 a, vec3 b, float amountOfA) {
    return (vec3(-amountOfA) * b) + ((a * vec3(amountOfA)) + b);
}

vec4 FxaaTexOff(sampler2D tex, vec2 pos, ivec2 off, vec2 rcpFrame) {
    float x = pos.x + float(off.x) * rcpFrame.x;
    float y = pos.y + float(off.y) * rcpFrame.y;
    return texture2D(tex, vec2(x, y));
}

// pos is the output of FxaaVertexShader interpolated across screen.
// xy -> actual texture position {0.0 to 1.0}
// rcpFrame should be a uniform equal to  {1.0/frameWidth, 1.0/frameHeight}

vec3 FxaaPixelShader(vec2 pos, sampler2D tex, vec2 rcpFrame)
{
    vec3 rgbN = FxaaTexOff(tex, pos.xy, ivec2( 0,-1), rcpFrame).xyz;
    vec3 rgbW = FxaaTexOff(tex, pos.xy, ivec2(-1, 0), rcpFrame).xyz;
    vec3 rgbM = FxaaTexOff(tex, pos.xy, ivec2( 0, 0), rcpFrame).xyz;
    vec3 rgbE = FxaaTexOff(tex, pos.xy, ivec2( 1, 0), rcpFrame).xyz;
    vec3 rgbS = FxaaTexOff(tex, pos.xy, ivec2( 0, 1), rcpFrame).xyz;
    
    float lumaN = FxaaLuma(rgbN);
    float lumaW = FxaaLuma(rgbW);
    float lumaM = FxaaLuma(rgbM);
    float lumaE = FxaaLuma(rgbE);
    float lumaS = FxaaLuma(rgbS);
    float rangeMin = min(lumaM, min(min(lumaN, lumaW), min(lumaS, lumaE)));
    float rangeMax = max(lumaM, max(max(lumaN, lumaW), max(lumaS, lumaE)));
    
    float range = rangeMax - rangeMin;
    if(range < max(FXAA_EDGE_THRESHOLD_MIN, rangeMax * FXAA_EDGE_THRESHOLD))
    {
        return rgbM;
    }
    
    vec3 rgbL = rgbN + rgbW + rgbM + rgbE + rgbS;
    
    float lumaL = (lumaN + lumaW + lumaE + lumaS) * 0.25;
    float rangeL = abs(lumaL - lumaM);
    float blendL = max(0.0, (rangeL / range) - FXAA_SUBPIX_TRIM) * FXAA_SUBPIX_TRIM_SCALE; 
    blendL = min(FXAA_SUBPIX_CAP, blendL);
    
    vec3 rgbNW = FxaaTexOff(tex, pos.xy, ivec2(-1,-1), rcpFrame).xyz;
    vec3 rgbNE = FxaaTexOff(tex, pos.xy, ivec2( 1,-1), rcpFrame).xyz;
    vec3 rgbSW = FxaaTexOff(tex, pos.xy, ivec2(-1, 1), rcpFrame).xyz;
    vec3 rgbSE = FxaaTexOff(tex, pos.xy, ivec2( 1, 1), rcpFrame).xyz;
    rgbL += (rgbNW + rgbNE + rgbSW + rgbSE);
    rgbL *= vec3(1.0/9.0);
    
    float lumaNW = FxaaLuma(rgbNW);
    float lumaNE = FxaaLuma(rgbNE);
    float lumaSW = FxaaLuma(rgbSW);
    float lumaSE = FxaaLuma(rgbSE);
    
    float edgeVert = 
        abs((0.25 * lumaNW) + (-0.5 * lumaN) + (0.25 * lumaNE)) +
        abs((0.50 * lumaW ) + (-1.0 * lumaM) + (0.50 * lumaE )) +
        abs((0.25 * lumaSW) + (-0.5 * lumaS) + (0.25 * lumaSE));
    float edgeHorz = 
        abs((0.25 * lumaNW) + (-0.5 * lumaW) + (0.25 * lumaSW)) +
        abs((0.50 * lumaN ) + (-1.0 * lumaM) + (0.50 * lumaS )) +
        abs((0.25 * lumaNE) + (-0.5 * lumaE) + (0.25 * lumaSE));
        
    bool horzSpan = edgeHorz >= edgeVert;
    float lengthSign = horzSpan ? -rcpFrame.y : -rcpFrame.x;
    
    if(!horzSpan)
    {
        lumaN = lumaW;
        lumaS = lumaE;
    }
    
    float gradientN = abs(lumaN - lumaM);
    float gradientS = abs(lumaS - lumaM);
    lumaN = (lumaN + lumaM) * 0.5;
    lumaS = (lumaS + lumaM) * 0.5;
    
    if (gradientN < gradientS)
    {
        lumaN = lumaS;
        lumaN = lumaS;
        gradientN = gradientS;
        lengthSign *= -1.0;
    }
    
    vec2 posN;
    posN.x = pos.x + (horzSpan ? 0.0 : lengthSign * 0.5);
    posN.y = pos.y + (horzSpan ? lengthSign * 0.5 : 0.0);
    
    gradientN *= FXAA_SEARCH_THRESHOLD;
    
    vec2 posP = posN;
    vec2 offNP = horzSpan ? vec2(rcpFrame.x, 0.0) : vec2(0.0, rcpFrame.y); 
    float lumaEndN = lumaN;
    float lumaEndP = lumaN;
    bool doneN = false;
    bool doneP = false;
    posN += offNP * vec2(-1.0, -1.0);
    posP += offNP * vec2( 1.0,  1.0);
    
    for(int i = 0; i < FXAA_SEARCH_STEPS; i++) {
        if(!doneN)
        {
            lumaEndN = FxaaLuma(texture2D(tex, posN.xy).xyz);
        }
        if(!doneP)
        {
            lumaEndP = FxaaLuma(texture2D(tex, posP.xy).xyz);
        }
        
        doneN = doneN || (abs(lumaEndN - lumaN) >= gradientN);
        doneP = doneP || (abs(lumaEndP - lumaN) >= gradientN);
        
        if(doneN && doneP)
        {
            break;
        }
        if(!doneN)
        {
            posN -= offNP;
        }
        if(!doneP)
        {
            posP += offNP;
        }
    }
    
    float dstN = horzSpan ? pos.x - posN.x : pos.y - posN.y;
    float dstP = horzSpan ? posP.x - pos.x : posP.y - pos.y;
    bool directionN = dstN < dstP;
    lumaEndN = directionN ? lumaEndN : lumaEndP;
    
    if(((lumaM - lumaN) < 0.0) == ((lumaEndN - lumaN) < 0.0))
    {
        lengthSign = 0.0;
    }
 

    float spanLength = (dstP + dstN);
    dstN = directionN ? dstN : dstP;
    float subPixelOffset = (0.5 + (dstN * (-1.0/spanLength))) * lengthSign;
    vec3 rgbF = texture2D(tex, vec2(
        pos.x + (horzSpan ? 0.0 : subPixelOffset),
        pos.y + (horzSpan ? subPixelOffset : 0.0))).xyz;
    return FxaaLerp3(rgbL, rgbF, blendL); 
}
 
 
void main()
{	
	
	vec3 fxaa_hq = FxaaPixelShader(gl_TexCoord[0].xy, rubyTexture, InvSize.xy);
	gl_FragColor = vec4(fxaa_hq, 1.0); 
}	
]]></fragment>



/* 4xSoft shader
   
   Copyright (C) 2007 guest(r) - guest.r@gmail.com

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

<vertex><![CDATA[
uniform vec2 rubyTextureSize;

void main(void) {
    gl_Position = ftransform();
    gl_TexCoord[0] = gl_MultiTexCoord0;
	
	vec2 ps = 1.0/rubyTextureSize;
	
	float dx = ps.x*1.0;
	float dy = ps.y*1.0;
	float sx = ps.x*0.5;
	float sy = ps.y*0.5;
 
	gl_TexCoord[1] = gl_TexCoord[0].xyxy + vec4(-dx, -dy,  dx, -dy);
	gl_TexCoord[2] = gl_TexCoord[0].xyxy + vec4( dx,  dy, -dx,  dy);
	gl_TexCoord[3] = gl_TexCoord[0].xyxy + vec4(-sx, -sy,  sx, -sy);
	gl_TexCoord[4] = gl_TexCoord[0].xyxy + vec4( sx,  sy, -sx,  sy);
	gl_TexCoord[5] = gl_TexCoord[0].xyxy + vec4(-dx,   0,  dx,   0);
	gl_TexCoord[6] = gl_TexCoord[0].xyxy + vec4(  0, -dy,   0,  dy);	
}
]]></vertex>


<fragment scale="2.0" filter="linear"><![CDATA[
uniform sampler2D rubyTexture;

void main()
{	
	vec3 c11 = texture2D(rubyTexture, gl_TexCoord[0].xy).xyz;
	vec3 c00 = texture2D(rubyTexture, gl_TexCoord[1].xy).xyz;
	vec3 c20 = texture2D(rubyTexture, gl_TexCoord[1].zw).xyz;
	vec3 c22 = texture2D(rubyTexture, gl_TexCoord[2].xy).xyz;
	vec3 c02 = texture2D(rubyTexture, gl_TexCoord[2].zw).xyz;
	vec3 s00 = texture2D(rubyTexture, gl_TexCoord[3].xy).xyz;
	vec3 s20 = texture2D(rubyTexture, gl_TexCoord[3].zw).xyz;
	vec3 s22 = texture2D(rubyTexture, gl_TexCoord[4].xy).xyz;
	vec3 s02 = texture2D(rubyTexture, gl_TexCoord[4].zw).xyz;
	vec3 c01 = texture2D(rubyTexture, gl_TexCoord[5].xy).xyz;
	vec3 c21 = texture2D(rubyTexture, gl_TexCoord[5].zw).xyz;
	vec3 c10 = texture2D(rubyTexture, gl_TexCoord[6].xy).xyz;
	vec3 c12 = texture2D(rubyTexture, gl_TexCoord[6].zw).xyz;

	vec3 dt = vec3(1.0, 1.0, 1.0);
	
	float d1=dot(abs(c00-c22),dt)+0.0001;
	float d2=dot(abs(c20-c02),dt)+0.0001;
	float hl=dot(abs(c01-c21),dt)+0.0001;
	float vl=dot(abs(c10-c12),dt)+0.0001;
	float m1=dot(abs(s00-s22),dt)+0.0001;
	float m2=dot(abs(s02-s20),dt)+0.0001;

	vec3 t1=(hl*(c10+c12)+vl*(c01+c21)+(hl+vl)*c11)/(3.0*(hl+vl));
	vec3 t2=(d1*(c20+c02)+d2*(c00+c22)+(d1+d2)*c11)/(3.0*(d1+d2));

	c11 = 0.25*(t1+t2+(m2*(s00+s22)+m1*(s02+s20))/(m1+m2));

	gl_FragColor = vec4(c11,1.0);	
}	
]]></fragment>

<vertex><![CDATA[

void main(void) {
    gl_Position = ftransform();
    gl_TexCoord[0] = gl_MultiTexCoord0;
}
]]></vertex>

/*
   Fast Sharpen shader
   
   Copyright (C) 2019 guest(r) - guest.r@gmail.com

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

<fragment scale="1.0" filter="linear"><![CDATA[
uniform sampler2D rubyTexture;
uniform vec2 rubyTextureSize;

#define SHARPEN  1.20
#define CONTRAST 0.15
#define DETAILS  1.00

vec2 g10 = vec2( 0.3333,-1.0)/rubyTextureSize;
vec2 g01 = vec2(-1.0,-0.3333)/rubyTextureSize;
vec2 g12 = vec2(-0.3333, 1.0)/rubyTextureSize;
vec2 g21 = vec2( 1.0, 0.3333)/rubyTextureSize; 

void main()
{	
	vec3 c10 = texture2D(rubyTexture, gl_TexCoord[0].xy + g10).rgb;
	vec3 c01 = texture2D(rubyTexture, gl_TexCoord[0].xy + g01).rgb;
	vec3 c21 = texture2D(rubyTexture, gl_TexCoord[0].xy + g21).rgb;
	vec3 c12 = texture2D(rubyTexture, gl_TexCoord[0].xy + g12).rgb;
	vec3 c11 = texture2D(rubyTexture, gl_TexCoord[0].xy      ).rgb;	
	vec3 b11 = (c10+c01+c12+c21)*0.25; 	
	
	float contrast = max(max(c11.r,c11.g),c11.b);
	contrast = mix(2.0*CONTRAST, CONTRAST, contrast);
	
	vec3 mn1 = min(min(c10,c01),min(c12,c21)); mn1 = min(mn1,c11*(1.0-contrast));
	vec3 mx1 = max(max(c10,c01),max(c12,c21)); mx1 = max(mx1,c11*(1.0+contrast));
	
	vec3 dif = pow(mx1-mn1, vec3(0.75,0.75,0.75));
	vec3 sharpen = mix(vec3(SHARPEN*DETAILS), vec3(SHARPEN), dif);
	
	c11 = clamp(mix(c11,b11,-sharpen), mn1,mx1); 
	
	gl_FragColor = vec4(c11,1.0);	
}	
]]></fragment>


/* Deblur shader
   
   Copyright (C) 2006 - 2018 guest(r) - guest.r@gmail.com

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

<vertex><![CDATA[
uniform vec2 rubyTextureSize;

void main(void) {
    gl_Position = ftransform();
    gl_TexCoord[0] = gl_MultiTexCoord0;
	
	vec2 ps = 1.5/rubyTextureSize;
	
	float dx = ps.x*1.0;
	float dy = ps.y*1.0;
 
	gl_TexCoord[1] = gl_TexCoord[0].xyxy + vec4(-dx, -dy,  dx, -dy);
	gl_TexCoord[2] = gl_TexCoord[0].xyxy + vec4( dx,  dy, -dx,  dy);
	gl_TexCoord[5] = gl_TexCoord[0].xyxy + vec4(-dx,   0,  dx,   0);
	gl_TexCoord[6] = gl_TexCoord[0].xyxy + vec4(  0, -dy,   0,  dy);	
}
]]></vertex>


<fragment scale="1.0" filter="linear"><![CDATA[
uniform sampler2D rubyTexture;

#define DEBLUR 4.5
#define SMART  0.4

const vec3 dtt = vec3(0.001,0.001,0.001);

void main()
{	
	vec3 c11 = texture2D(rubyTexture, gl_TexCoord[0].xy).xyz;
	vec3 c00 = texture2D(rubyTexture, gl_TexCoord[1].xy).xyz;
	vec3 c20 = texture2D(rubyTexture, gl_TexCoord[1].zw).xyz;
	vec3 c22 = texture2D(rubyTexture, gl_TexCoord[2].xy).xyz;
	vec3 c02 = texture2D(rubyTexture, gl_TexCoord[2].zw).xyz;
	vec3 c01 = texture2D(rubyTexture, gl_TexCoord[5].xy).xyz;
	vec3 c21 = texture2D(rubyTexture, gl_TexCoord[5].zw).xyz;
	vec3 c10 = texture2D(rubyTexture, gl_TexCoord[6].xy).xyz;
	vec3 c12 = texture2D(rubyTexture, gl_TexCoord[6].zw).xyz;

	vec3 dt = vec3(1.0, 1.0, 1.0);

	vec3 mn1 = min (min (c00,c01),c02);
	vec3 mn2 = min (min (c10,c11),c12);
	vec3 mn3 = min (min (c20,c21),c22);
	vec3 mx1 = max (max (c00,c01),c02);
	vec3 mx2 = max (max (c10,c11),c12);
	vec3 mx3 = max (max (c20,c21),c22);

	mn1 = min(min(mn1,mn2),mn3);
	mx1 = max(max(mx1,mx2),mx3); 	
	
	vec3 contrast = mx1 - mn1;
	
	vec3 dif1 = abs(c11-mn1) + dtt;
	vec3 dif2 = abs(c11-mx1) + dtt;

	float DB1 = DEBLUR;
   
	//float dif = 1.5*max(length(dif1),length(dif2));
	//dif = min(dif, 1.0);
	//DB1 = max(mix(0.8, DB1, dif), 1.0);
   
	dif1=vec3(pow(dif1.x,DB1),pow(dif1.y,DB1),pow(dif1.z,DB1));
	dif2=vec3(pow(dif2.x,DB1),pow(dif2.y,DB1),pow(dif2.z,DB1)); 

	vec3 d11 = vec3((dif1.x*mx1.x + dif2.x*mn1.x)/(dif1.x + dif2.x),
               (dif1.y*mx1.y + dif2.y*mn1.y)/(dif1.y + dif2.y),
               (dif1.z*mx1.z + dif2.z*mn1.z)/(dif1.z + dif2.z));
			   
	float k10 = 1.0/(dot(abs(c10-d11),dt)+0.0001);
	float k01 = 1.0/(dot(abs(c01-d11),dt)+0.0001);
	float k11 = 1.0/(dot(abs(c11-d11),dt)+0.0001);  
	float k21 = 1.0/(dot(abs(c21-d11),dt)+0.0001);
	float k12 = 1.0/(dot(abs(c12-d11),dt)+0.0001);   

	float avg = 0.05*(k10+k01+k11+k21+k12);
   
	k10 = max(k10-avg, 0.0);
	k01 = max(k01-avg, 0.0);
	k11 = max(k11-avg, 0.0);   
	k21 = max(k21-avg, 0.0);
	k12 = max(k12-avg, 0.0);

	d11 = (k10*c10 + k01*c01 + k11*c11 + k21*c21 + k12*c12 + 0.001*c11)/(k10+k01+k11+k21+k12+0.001); 
	
	c11 = mix(c11, d11, clamp(1.75*contrast-0.125, 0.0, 1.0));
	c11 = mix(d11, c11, SMART);
	
	gl_FragColor = vec4(c11,1.0);	
}	
]]></fragment>
</shader>
