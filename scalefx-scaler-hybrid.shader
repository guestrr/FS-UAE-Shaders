<?xml version="1.0" encoding="UTF-8"?>
<shader language="GLSL">

/*
	ScaleFX - 4 Passes
	by Sp00kyFox, 2016-03-30

ScaleFX is an edge interpolation algorithm specialized in pixel art. It was
originally intended as an improvement upon Scale3x but became a new filter in
its own right.
ScaleFX interpolates edges up to level 6 and makes smooth transitions between
different slopes. The filtered picture will only consist of colours present
in the original.

Pass 0 prepares metric data for the next pass.
Pass 1 resolves ambiguous configurations of corner candidates at pixel junctions.
Pass 2 determines which edge level is present and prepares tags for subpixel output in the final pass.
Pass 3 outputs subpixels based on previously calculated tags.

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

ported to GLSL by guest.r
*/

// ScaleFX pass 0
<vertex><![CDATA[
uniform vec2 rubyTextureSize;

void main(void) {
    gl_Position = ftransform();
    gl_TexCoord[0] = gl_MultiTexCoord0;
	
	vec2 ps = 1.0/rubyTextureSize;
	float dx = ps.x, dy = ps.y;

	gl_TexCoord[1] = gl_TexCoord[0].xxxy + vec4(  -dx,   0.0, dx,  -dy);	// A, B, C
	gl_TexCoord[2] = gl_TexCoord[0].xxxy + vec4(  -dx,   0.0, dx,  0.0);	// D, E, F
}
]]></vertex>

<fragment scale="1.0" filter="nearest"><![CDATA[
	uniform sampler2D rubyTexture;

	float eq(vec3 A, vec3 B)
	{
		float  r = 0.5 * (A.r + B.r);
		vec3 d = A - B;
		vec3 c = vec3(2.0 + r, 4.0, 3.0 - r);

		return 1.0 - sqrt(dot(c*d, d)) / 3.0;
	}
void main()
{
	/*	grid		metric

		A B C		x y z
		  E F		  o w
	*/
	
	// read texels
	vec3 A = texture2D(rubyTexture, gl_TexCoord[1].xw).rgb;
	vec3 B = texture2D(rubyTexture, gl_TexCoord[1].yw).rgb;
	vec3 C = texture2D(rubyTexture, gl_TexCoord[1].zw).rgb;
	vec3 E = texture2D(rubyTexture, gl_TexCoord[2].yw).rgb;
	vec3 F = texture2D(rubyTexture, gl_TexCoord[2].zw).rgb;

	// output
	gl_FragColor = vec4(eq(E,A), eq(E,B), eq(E,C), eq(E,F));	
}	
]]></fragment>



// ScaleFX pass 1
<vertex><![CDATA[

uniform vec2 rubyTextureSize;

void main(void) {
    gl_Position = ftransform();
    gl_TexCoord[0] = gl_MultiTexCoord0;

	vec2 ps = 1.0/rubyTextureSize;
	float dx = ps.x, dy = ps.y;

	gl_TexCoord[1] = gl_TexCoord[0].xxxy + vec4(  -dx, 0.0, dx,  -dy);	// A, B, C
	gl_TexCoord[2] = gl_TexCoord[0].xxxy + vec4(  -dx, 0.0, dx,  0.0);	// D, E, F
	gl_TexCoord[3] = gl_TexCoord[0].xxxy + vec4(  -dx, 0.0, dx,   dy);	// G, H, I
	gl_TexCoord[4] = gl_TexCoord[0].xxxy + vec4(  -dx, 0.0, dx, 2.0*dy);	// J, K, L
	gl_TexCoord[5] = gl_TexCoord[0].xyyy + vec4(-2.0*dx, -dy,0.0,   dy);	// M, N, O
	gl_TexCoord[6] = gl_TexCoord[0].xyyy + vec4( 2.0*dx, -dy,0.0,   dy);	// P, Q, R
}
]]></vertex>


<fragment scale="1.0" filter="nearest"><![CDATA[
uniform sampler2D rubyTexture;
uniform vec2 rubyTextureSize;

#define SFX_CLR   0.57
float THR = 1.0 - SFX_CLR;

#define LE(x, y) (1.0 - step(y, x))
#define GE(x, y) (1.0 - step(x, y))
#define LEQ(x, y) step(x, y)
#define GEQ(x, y) step(y, x)
#define NOT(x) (1.0 - (x))


// corner strength
vec4 str(vec4 crn, vec4 ort){
	//return (crn > THR) ? max(2.0*crn - (ort + ort.wxyz), 0.0) : 0.0;
	return GE(crn, vec4(THR)) * max(2.0*crn - (ort + ort.wxyz), vec4(0.0));
}

// corner dominance at junctions
vec4 dom(vec3 strx, vec3 stry, vec3 strz, vec3 strw){
	vec4 res;
	res.x = max(2.0*strx.y - (strx.x + strx.z), 0.0);
	res.y = max(2.0*stry.y - (stry.x + stry.z), 0.0);
	res.z = max(2.0*strz.y - (strz.x + strz.z), 0.0);
	res.w = max(2.0*strw.y - (strw.x + strw.z), 0.0);
	return res;
}

// necessary but not sufficient junction condition for orthogonal edges
float clear(vec2 crn, vec4 ort){
	//return all(crn.xyxy <= THR || crn.xyxy <= ort || crn.xyxy <= ort.wxyz);
	vec4 res = LEQ(crn.xyxy, vec4(THR)) + LEQ(crn.xyxy, ort) + LEQ(crn.xyxy, ort.wxyz);
	return min(res.x * res.y * res.z * res.w, 1.0);
}

void main()
{
	/*	grid		metric		pattern

		M A B C P	x y z		x y
		N D E F Q	  o w		w z
		O G H I R
		  J K L
	*/


	// metric data
	vec4 A = texture2D(rubyTexture, gl_TexCoord[1].xw), B = texture2D(rubyTexture, gl_TexCoord[1].yw), C = texture2D(rubyTexture, gl_TexCoord[1].zw);
	vec4 D = texture2D(rubyTexture, gl_TexCoord[2].xw), E = texture2D(rubyTexture, gl_TexCoord[2].yw), F = texture2D(rubyTexture, gl_TexCoord[2].zw);
	vec4 G = texture2D(rubyTexture, gl_TexCoord[3].xw), H = texture2D(rubyTexture, gl_TexCoord[3].yw), I = texture2D(rubyTexture, gl_TexCoord[3].zw);
	vec4 J = texture2D(rubyTexture, gl_TexCoord[4].xw), K = texture2D(rubyTexture, gl_TexCoord[4].yw), L = texture2D(rubyTexture, gl_TexCoord[4].zw);
	vec4 M = texture2D(rubyTexture, gl_TexCoord[5].xy), N = texture2D(rubyTexture, gl_TexCoord[5].xz), O = texture2D(rubyTexture, gl_TexCoord[5].xw);
	vec4 P = texture2D(rubyTexture, gl_TexCoord[6].xy), Q = texture2D(rubyTexture, gl_TexCoord[6].xz), R = texture2D(rubyTexture, gl_TexCoord[6].xw);
	
	// corner strength
	vec4 As = str(vec4(M.z, B.x, D.zx), vec4(A.yw, D.y, M.w));
	vec4 Bs = str(vec4(A.z, C.x, E.zx), vec4(B.yw, E.y, A.w));
	vec4 Cs = str(vec4(B.z, P.x, F.zx), vec4(C.yw, F.y, B.w));
	vec4 Ds = str(vec4(N.z, E.x, G.zx), vec4(D.yw, G.y, N.w));
	vec4 Es = str(vec4(D.z, F.x, H.zx), vec4(E.yw, H.y, D.w));
	vec4 Fs = str(vec4(E.z, Q.x, I.zx), vec4(F.yw, I.y, E.w));
	vec4 Gs = str(vec4(O.z, H.x, J.zx), vec4(G.yw, J.y, O.w));
	vec4 Hs = str(vec4(G.z, I.x, K.zx), vec4(H.yw, K.y, G.w));
	vec4 Is = str(vec4(H.z, R.x, L.zx), vec4(I.yw, L.y, H.w));

	// strength & dominance junctions
	vec4 jSx = vec4(As.z, Bs.w, Es.x, Ds.y), jDx = dom(As.yzw, Bs.zwx, Es.wxy, Ds.xyz);
	vec4 jSy = vec4(Bs.z, Cs.w, Fs.x, Es.y), jDy = dom(Bs.yzw, Cs.zwx, Fs.wxy, Es.xyz);
	vec4 jSz = vec4(Es.z, Fs.w, Is.x, Hs.y), jDz = dom(Es.yzw, Fs.zwx, Is.wxy, Hs.xyz);
	vec4 jSw = vec4(Ds.z, Es.w, Hs.x, Gs.y), jDw = dom(Ds.yzw, Es.zwx, Hs.wxy, Gs.xyz);


	// majority vote for ambiguous dominance junctions
	//bvec4 jx = jDx != 0.0 && jDx + jDx.zwxy > jDx.yzwx + jDx.wxyz;
	//bvec4 jy = jDy != 0.0 && jDy + jDy.zwxy > jDy.yzwx + jDy.wxyz;
	//bvec4 jz = jDz != 0.0 && jDz + jDz.zwxy > jDz.yzwx + jDz.wxyz;
	//bvec4 jw = jDw != 0.0 && jDw + jDw.zwxy > jDw.yzwx + jDw.wxyz;

	vec4 jx = GE(jDx, vec4(0.0)) * GE(jDx + jDx.zwxy, jDx.yzwx + jDx.wxyz);
	vec4 jy = GE(jDy, vec4(0.0)) * GE(jDy + jDy.zwxy, jDy.yzwx + jDy.wxyz);
	vec4 jz = GE(jDz, vec4(0.0)) * GE(jDz + jDz.zwxy, jDz.yzwx + jDz.wxyz);
	vec4 jw = GE(jDw, vec4(0.0)) * GE(jDw + jDw.zwxy, jDw.yzwx + jDw.wxyz);

	// inject strength without creating new contradictions
	//bvec4 res;
	//res.x = jx.z || !(jx.y || jx.w) && (jSx.z != 0.0 && (jx.x || jSx.x + jSx.z > jSx.y + jSx.w));
	//res.y = jy.w || !(jy.z || jy.x) && (jSy.w != 0.0 && (jy.y || jSy.y + jSy.w > jSy.x + jSy.z));
	//res.z = jz.x || !(jz.w || jz.y) && (jSz.x != 0.0 && (jz.z || jSz.x + jSz.z > jSz.y + jSz.w));
	//res.w = jw.y || !(jw.x || jw.z) && (jSw.y != 0.0 && (jw.w || jSw.y + jSw.w > jSw.x + jSw.z));

	vec4 res;
	res.x = min(jx.z + (NOT(jx.y) * NOT(jx.w)) * (GE(jSx.z, 0.0) * (jx.x + GE(jSx.x + jSx.z, jSx.y + jSx.w))), 1.0);
	res.y = min(jy.w + (NOT(jy.z) * NOT(jy.x)) * (GE(jSy.w, 0.0) * (jy.y + GE(jSy.y + jSy.w, jSy.x + jSy.z))), 1.0);
	res.z = min(jz.x + (NOT(jz.w) * NOT(jz.y)) * (GE(jSz.x, 0.0) * (jz.z + GE(jSz.x + jSz.z, jSz.y + jSz.w))), 1.0);
	res.w = min(jw.y + (NOT(jw.x) * NOT(jw.z)) * (GE(jSw.y, 0.0) * (jw.w + GE(jSw.y + jSw.w, jSw.x + jSw.z))), 1.0);	


	// single pixel & end of line detection
	//res = res && (bvec4(jx.z, jy.w, jz.x, jw.y) || !(res.wxyz && res.yzwx));	
	res = min(res * (vec4(jx.z, jy.w, jz.x, jw.y) + NOT(res.wxyz * res.yzwx)), vec4(1.0));


	// output

	vec4 clr;
	clr.x = clear(vec2(D.z, E.x), vec4(A.w, E.y, D.wy));
	clr.y = clear(vec2(E.z, F.x), vec4(B.w, F.y, E.wy));
	clr.z = clear(vec2(H.z, I.x), vec4(E.w, I.y, H.wy));
	clr.w = clear(vec2(G.z, H.x), vec4(D.w, H.y, G.wy));

	vec4 low = max(vec4(E.yw, H.y, D.w), vec4(THR));
	
	vec4 hori = vec4(low.x < max(D.w, A.w), low.x < max(E.w, B.w), low.z < max(E.w, H.w), low.z < max(D.w, G.w)) * clr;	// horizontal edges
	vec4 vert = vec4(low.w < max(E.y, D.y), low.y < max(E.y, F.y), low.y < max(H.y, I.y), low.w < max(H.y, G.y)) * clr;	// vertical edges
	vec4 or   = vec4(A.w < D.y, B.w <= F.y, H.w < I.y, G.w <= G.y);								// orientation

	gl_FragColor = (res + 2.0 * hori + 4.0 * vert + 8.0 * or) / 15.0; 
}	
]]></fragment>



// ScaleFX pass 2
<vertex><![CDATA[
uniform vec2 rubyTextureSize;

void main(void) {
    gl_Position = ftransform();
    gl_TexCoord[0] = gl_MultiTexCoord0;
	
	vec2 ps = 1.0/rubyTextureSize;
	float dx = ps.x, dy = ps.y;

	gl_TexCoord[1] = gl_TexCoord[0].xxxy + vec4(-dx, -2.0*dx, -3.0*dx,     0.0);	// D, D0, D1
	gl_TexCoord[2] = gl_TexCoord[0].xxxy + vec4( dx,  2.0*dx,  3.0*dx,     0.0);	// F, F0, F1
	gl_TexCoord[3] = gl_TexCoord[0].xyyy + vec4(  0.0,   -dy, -2.0*dy, -3.0*dy);	// B, B0, B1
	gl_TexCoord[4] = gl_TexCoord[0].xyyy + vec4(  0.0,    dy,  2.0*dy,  3.0*dy);	// H, H0, H1	
}
]]></vertex>


<fragment scale="1.0" filter="nearest"><![CDATA[
uniform sampler2D rubyTexture;

vec4 fmod(vec4 a, float b)
{
    vec4 c = fract(abs(a/b))*abs(b);
    return sign(a)*c;
}

// extract first bool4 from vec4 - corners
bvec4 loadCorn(vec4 x){
	return bvec4(floor(fmod(x*15.0 + 0.5, 2.0)));
}

// extract second bool4 from vec4 - horizontal edges
bvec4 loadHori(vec4 x){
	return bvec4(floor(fmod(x*7.5 + 0.25, 2.0)));
}

// extract third bool4 from vec4 - vertical edges
bvec4 loadVert(vec4 x){
	return bvec4(floor(fmod(x*3.75 + 0.125, 2.0)));
}

// extract fourth bool4 from vec4 - orientation
bvec4 loadOr(vec4 x){
	return bvec4(floor(fmod(x*1.875 + 0.0625, 2.0)));
}


void main()
{	
	/*	grid		corners		mids		

		  B		x   y	  	  x
		D E F				w   y
		  H		w   z	  	  z
	*/


	// read data
	vec4 E = texture2D(rubyTexture, gl_TexCoord[0].xy);
	vec4 D = texture2D(rubyTexture, gl_TexCoord[1].xw), D0 = texture2D(rubyTexture, gl_TexCoord[1].yw), D1 = texture2D(rubyTexture, gl_TexCoord[1].zw);
	vec4 F = texture2D(rubyTexture, gl_TexCoord[2].xw), F0 = texture2D(rubyTexture, gl_TexCoord[2].yw), F1 = texture2D(rubyTexture, gl_TexCoord[2].zw);
	vec4 B = texture2D(rubyTexture, gl_TexCoord[3].xy), B0 = texture2D(rubyTexture, gl_TexCoord[3].xz), B1 = texture2D(rubyTexture, gl_TexCoord[3].xw);
	vec4 H = texture2D(rubyTexture, gl_TexCoord[4].xy), H0 = texture2D(rubyTexture, gl_TexCoord[4].xz), H1 = texture2D(rubyTexture, gl_TexCoord[4].xw);

	// extract data
	bvec4 Ec = loadCorn(E), Eh = loadHori(E), Ev = loadVert(E), Eo = loadOr(E);
	bvec4 Dc = loadCorn(D),	Dh = loadHori(D), Do = loadOr(D), D0c = loadCorn(D0), D0h = loadHori(D0), D1h = loadHori(D1);
	bvec4 Fc = loadCorn(F),	Fh = loadHori(F), Fo = loadOr(F), F0c = loadCorn(F0), F0h = loadHori(F0), F1h = loadHori(F1);
	bvec4 Bc = loadCorn(B),	Bv = loadVert(B), Bo = loadOr(B), B0c = loadCorn(B0), B0v = loadVert(B0), B1v = loadVert(B1);
	bvec4 Hc = loadCorn(H),	Hv = loadVert(H), Ho = loadOr(H), H0c = loadCorn(H0), H0v = loadVert(H0), H1v = loadVert(H1);


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
	
	vec4 crn;
	crn.x = (Ec.x && Eo.x || lvl3x.x && Eo.y || lvl4x.x && Do.x || lvl6x.x && Fo.y) ? 5.0 : (Ec.x || lvl3x.y && !Eo.w || lvl4x.y && !Bo.x || lvl6x.y && !Ho.w) ? 1.0 : lvl3x.x ? 3.0 : lvl3x.y ? 7.0 : lvl4x.x ? 2.0 : lvl4x.y ? 6.0 : lvl6x.x ? 4.0 : lvl6x.y ? 8.0 : 0.0;
	crn.y = (Ec.y && Eo.y || lvl3y.x && Eo.x || lvl4y.x && Fo.y || lvl6y.x && Do.x) ? 5.0 : (Ec.y || lvl3y.y && !Eo.z || lvl4y.y && !Bo.y || lvl6y.y && !Ho.z) ? 3.0 : lvl3y.x ? 1.0 : lvl3y.y ? 7.0 : lvl4y.x ? 4.0 : lvl4y.y ? 6.0 : lvl6y.x ? 2.0 : lvl6y.y ? 8.0 : 0.0;
	crn.z = (Ec.z && Eo.z || lvl3z.x && Eo.w || lvl4z.x && Fo.z || lvl6z.x && Do.w) ? 7.0 : (Ec.z || lvl3z.y && !Eo.y || lvl4z.y && !Ho.z || lvl6z.y && !Bo.y) ? 3.0 : lvl3z.x ? 1.0 : lvl3z.y ? 5.0 : lvl4z.x ? 4.0 : lvl4z.y ? 8.0 : lvl6z.x ? 2.0 : lvl6z.y ? 6.0 : 0.0;
	crn.w = (Ec.w && Eo.w || lvl3w.x && Eo.z || lvl4w.x && Do.w || lvl6w.x && Fo.z) ? 7.0 : (Ec.w || lvl3w.y && !Eo.x || lvl4w.y && !Ho.w || lvl6w.y && !Bo.x) ? 1.0 : lvl3w.x ? 3.0 : lvl3w.y ? 5.0 : lvl4w.x ? 2.0 : lvl4w.y ? 8.0 : lvl6w.x ? 4.0 : lvl6w.y ? 6.0 : 0.0;

	vec4 mid;
	mid.x = (lvl2x.x &&  Eo.x || lvl2x.y &&  Eo.y || lvl5x.x &&  Do.x || lvl5x.y &&  Fo.y) ? 5.0 : lvl2x.x ? 1.0 : lvl2x.y ? 3.0 : lvl5x.x ? 2.0 : lvl5x.y ? 4.0 : (Ec.x && Dc.z && Ec.y && Fc.w) ? ( Eo.x ?  Eo.y ? 5.0 : 3.0 : 1.0) : 0.0;
	mid.y = (lvl2y.x && !Eo.y || lvl2y.y && !Eo.z || lvl5y.x && !Bo.y || lvl5y.y && !Ho.z) ? 3.0 : lvl2y.x ? 5.0 : lvl2y.y ? 7.0 : lvl5y.x ? 6.0 : lvl5y.y ? 8.0 : (Ec.y && Bc.w && Ec.z && Hc.x) ? (!Eo.y ? !Eo.z ? 3.0 : 7.0 : 5.0) : 0.0;
	mid.z = (lvl2z.x &&  Eo.w || lvl2z.y &&  Eo.z || lvl5z.x &&  Do.w || lvl5z.y &&  Fo.z) ? 7.0 : lvl2z.x ? 1.0 : lvl2z.y ? 3.0 : lvl5z.x ? 2.0 : lvl5z.y ? 4.0 : (Ec.z && Fc.x && Ec.w && Dc.y) ? ( Eo.z ?  Eo.w ? 7.0 : 1.0 : 3.0) : 0.0;
	mid.w = (lvl2w.x && !Eo.x || lvl2w.y && !Eo.w || lvl5w.x && !Bo.x || lvl5w.y && !Ho.w) ? 1.0 : lvl2w.x ? 5.0 : lvl2w.y ? 7.0 : lvl5w.x ? 6.0 : lvl5w.y ? 8.0 : (Ec.w && Hc.y && Ec.x && Bc.z) ? (!Eo.w ? !Eo.x ? 1.0 : 5.0 : 7.0) : 0.0;
	
	gl_FragColor = (crn + 9.0 * mid) / 80.0;	
}	
]]></fragment>



// ScaleFX pass 3
<vertex><![CDATA[
uniform vec2 rubyOrigTextureSize;

void main(void) {

    gl_Position = ftransform();
    gl_TexCoord[0] = gl_MultiTexCoord0;

	vec2 ps = 1.0/rubyOrigTextureSize;
	float dx = ps.x, dy = ps.y;

	gl_TexCoord[1] = gl_TexCoord[0].xxxy + vec4( 0.0, -dx, -2.0*dx,     0.0);	// E, D, D0
	gl_TexCoord[2] = gl_TexCoord[0].xyxy + vec4(dx,   0.0,  2.0*dx,     0.0);	// F, F0
	gl_TexCoord[3] = gl_TexCoord[0].xyxy + vec4( 0.0, -dy,     0.0, -2.0*dy);	// B, B0
	gl_TexCoord[4] = gl_TexCoord[0].xyxy + vec4( 0.0,  dy,     0.0,  2.0*dy);	// H, H0	
}
]]></vertex>


<fragment scale="3.0" filter="nearest"><![CDATA[
uniform sampler2D rubyTexture;
uniform sampler2D rubyOrigTexture;
uniform vec2 rubyTextureSize;

vec4 fmod(vec4 a, float b)
{
    vec4 c = fract(abs(a/b))*abs(b);
    return sign(a)*c;
}

// extract corners
vec4 loadCrn(vec4 x){
	return floor(fmod(x*80.0 + 0.5, 9.0));
}

// extract mids
vec4 loadMid(vec4 x){
	return floor(fmod(x*8.888888 + 0.055555, 9.0));
}


void main()
{	

	/*	grid		corners		mids

		  B		x   y	  	  x
		D E F				w   y
		  H		w   z	  	  z
	*/

	// read data
	vec4 E = texture2D(rubyTexture, gl_TexCoord[0].xy);

	// extract data
	vec4 crn = loadCrn(E);
	vec4 mid = loadMid(E);

	// determine subpixel
	vec2 fp = floor(3.0 * fract(gl_TexCoord[0].xy*rubyTextureSize));
	float  sp = fp.y == 0.0 ? (fp.x == 0.0 ? crn.x : fp.x == 1.0 ? mid.x : crn.y) : (fp.y == 1.0 ? (fp.x == 0.0 ? mid.w : fp.x == 1.0 ? 0.0 : mid.y) : (fp.x == 0.0 ? crn.w : fp.x == 1.0 ? mid.z : crn.z));

	// output coordinate - 0 = E, 1 = D, 2 = D0, 3 = F, 4 = F0, 5 = B, 6 = B0, 7 = H, 8 = H0
	vec2 res = sp == 0.0 ? gl_TexCoord[1].xw : sp == 1.0 ? gl_TexCoord[1].yw : sp == 2.0 ? gl_TexCoord[1].zw : sp == 3.0 ? gl_TexCoord[2].xy : sp == 4.0 ? gl_TexCoord[2].zw : sp == 5.0 ? gl_TexCoord[3].xy : sp == 6.0 ? gl_TexCoord[3].zw : sp == 7.0 ? gl_TexCoord[4].xy : gl_TexCoord[4].zw;

	// ouput	
	gl_FragColor = vec4(texture2D(rubyOrigTexture, res).rgb,1.0);	
}	
]]></fragment>



/*
	rAA post-3x - Pass 0
	by Sp00kyFox, 2018-10-20

Filter:	Nearest
Scale:	1x

This is a generalized continuation of the reverse antialiasing filter by
Christoph Feck. Unlike the original filter this is supposed to be used on an
already upscaled image. Which makes it possible to combine rAA with other filters
just as ScaleFX, xBR or others.

Pass 0 does the horizontal filtering.



Copyright (c) 2018 Sp00kyFox - ScaleFX@web.de

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

<vertex><![CDATA[

void main(void) {
    gl_Position = ftransform();
    gl_TexCoord[0] = gl_MultiTexCoord0;
}
]]></vertex>


<fragment scale="1.0" filter="nearest"><![CDATA[
uniform sampler2D rubyTexture;
uniform vec2 rubyTextureSize;


#define RAA_SHR0 2.0
#define RAA_SMT0 0.5
#define RAA_DVT0 1.0

const int scl = 3; // scale factor
const int rad = 7; // search radius


// core function of rAA - tilt of a pixel
vec3 res2x(vec3 pre2, vec3 pre1, vec3 px, vec3 pos1, vec3 pos2)
{
    float d1, d2, w;
	vec3 a, m, t, t1, t2;
    mat4x3 pre = mat4x3(pre2, pre1,   px, pos1);
    mat4x3 pos = mat4x3(pre1,   px, pos1, pos2);
    mat4x3  df = pos - pre;

    m.x = (px.x < 0.5) ? px.x : (1.0-px.x);
    m.y = (px.y < 0.5) ? px.y : (1.0-px.y);
    m.z = (px.z < 0.5) ? px.z : (1.0-px.z);
	
	m = RAA_SHR0 * min(m, min(abs(df[1]), abs(df[2])));   // magnitude
	t = (7. * (df[1] + df[2]) - 3. * (df[0] + df[3])) / 16.; // tilt
	
	a.x = t.x == 0.0 ? 1.0 : m.x/abs(t.x);
	a.y = t.y == 0.0 ? 1.0 : m.y/abs(t.y);
	a.z = t.z == 0.0 ? 1.0 : m.z/abs(t.z);	
	
	t1 = clamp(t, -m, m);                       // limit channels
	t2 = min(1.0, min(min(a.x, a.y), a.z)) * t; // limit length
	
	d1 = length(df[1]); d2 = length(df[2]);
	d1 = d1 == 0.0 ? 0.0 : length(cross(df[1], t1))/d1; // distance between line (px, pre1) and point px-t1
	d2 = d2 == 0.0 ? 0.0 : length(cross(df[2], t1))/d2; // distance between line (px, pos1) and point px+t1

	w = min(1.0, max(d1,d2)/0.8125); // color deviation from optimal value
	
	return mix(t1, t2, pow(w, RAA_DVT0));
}



void main()
{	
	// read texels

	vec3 tx[2*rad+1];

	#define TX(n) tx[(n)+rad]
	
	TX(0) = texture2D(rubyTexture, gl_TexCoord[0].xy        ).rgb;
	
	for(int i=1; i<=rad; i++){
		TX(-i) = texture2D(rubyTexture, gl_TexCoord[0].xy + vec2(float(-i),0.0)/rubyTextureSize).rgb;
		TX( i) = texture2D(rubyTexture, gl_TexCoord[0].xy + vec2(float( i),0.0)/rubyTextureSize).rgb;
	}
	
	
	// prepare variables for candidate search
	
	ivec2 i1, i2;
	vec3 df1, df2;
	vec2 d1, d2, d3;
	bvec2 cn;
	
	df1 = TX(1)-TX(0); df2 = TX(0)-TX(-1);
	
	d2 = vec2(length(df1), length(df2));
	d3 = d2.yx;
	
	
	// smoothness weight, protects smooth gradients
	float sw = d2.x + d2.y;
	sw = sw == 0.0 ? 1.0 : pow(length(df1-df2)/sw, RAA_SMT0);
	
	
	// look for proper candidates
	for(int i=1; i<rad; i++){
		d1 = d2;
		d2 = d3;
		d3 = vec2(distance(TX(-i-1), TX(-i)), distance(TX(i), TX(i+1)));

		cn.x = max(d1.x,d3.x)<d2.x;
		cn.y = max(d1.y,d3.y)<d2.y;
		
		i2.x = cn.x && i2.x==0 && i1.x!=0 ? i : i2.x;
		i2.y = cn.y && i2.y==0 && i1.y!=0 ? i : i2.y;
		
		i1.x = cn.x && i1.x==0 ? i : i1.x;
		i1.y = cn.y && i1.y==0 ? i : i1.y;
		
	}

	i2.x = i2.x == 0 ? i1.x+1 : i2.x;
	i2.y = i2.y == 0 ? i1.y+1 : i2.y;
	
	// rAA core with the candidates found above
	vec3 t = res2x(TX(-i2.x), TX(-i1.x), TX(0), TX(i1.y), TX(i2.y));

	// distance weight
	float dw = ((i1.x == 0)||(i1.y == 0)) ? 0.0 : 2.0 * ((i1.x-1.0)/(i1.x+i1.y-2.0)) - 1.0;	
	
	// result
	vec3 res = TX(0) + (scl-1.0)/scl * sw*dw * t;
	
	// prevent ringing	
	vec3 lo  = min(min(TX(-1),TX(0)),TX(1));
	vec3 hi  = max(max(TX(-1),TX(0)),TX(1));
	
	gl_FragColor = vec4(clamp(res, lo, hi), 1.0);	
}	
]]></fragment>


/*
	rAA post-3x - Pass 1
	by Sp00kyFox, 2018-10-20

Filter:	Nearest
Scale:	1x

This is a generalized continuation of the reverse antialiasing filter by
Christoph Feck. Unlike the original filter this is supposed to be used on an
already upscaled image. Which makes it possible to combine rAA with other filters
just as ScaleFX, xBR or others.

Pass 1 does the vertical filtering.



Copyright (c) 2018 Sp00kyFox - ScaleFX@web.de

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

<vertex><![CDATA[

void main(void) {
    gl_Position = ftransform();
    gl_TexCoord[0] = gl_MultiTexCoord0;
}
]]></vertex>


<fragment scale="1.0" filter="nearest"><![CDATA[
uniform sampler2D rubyTexture;
uniform vec2 rubyTextureSize;


#define RAA_SHR0 2.0
#define RAA_SMT0 0.5
#define RAA_DVT0 1.0

const int scl = 3; // scale factor
const int rad = 7; // search radius


// core function of rAA - tilt of a pixel
vec3 res2x(vec3 pre2, vec3 pre1, vec3 px, vec3 pos1, vec3 pos2)
{
    float d1, d2, w;
	vec3 a, m, t, t1, t2;
    mat4x3 pre = mat4x3(pre2, pre1,   px, pos1);
    mat4x3 pos = mat4x3(pre1,   px, pos1, pos2);
    mat4x3  df = pos - pre;

    m.x = (px.x < 0.5) ? px.x : (1.0-px.x);
    m.y = (px.y < 0.5) ? px.y : (1.0-px.y);
    m.z = (px.z < 0.5) ? px.z : (1.0-px.z);
	
	m = RAA_SHR0 * min(m, min(abs(df[1]), abs(df[2])));   // magnitude
	t = (7. * (df[1] + df[2]) - 3. * (df[0] + df[3])) / 16.; // tilt
	
	a.x = t.x == 0.0 ? 1.0 : m.x/abs(t.x);
	a.y = t.y == 0.0 ? 1.0 : m.y/abs(t.y);
	a.z = t.z == 0.0 ? 1.0 : m.z/abs(t.z);	
	
	t1 = clamp(t, -m, m);                       // limit channels
	t2 = min(1.0, min(min(a.x, a.y), a.z)) * t; // limit length
	
	d1 = length(df[1]); d2 = length(df[2]);
	d1 = d1 == 0.0 ? 0.0 : length(cross(df[1], t1))/d1; // distance between line (px, pre1) and point px-t1
	d2 = d2 == 0.0 ? 0.0 : length(cross(df[2], t1))/d2; // distance between line (px, pos1) and point px+t1

	w = min(1.0, max(d1,d2)/0.8125); // color deviation from optimal value
	
	return mix(t1, t2, pow(w, RAA_DVT0));
}



void main()
{	
	// read texels

	vec3 tx[2*rad+1];

	#define TX(n) tx[(n)+rad]
	
	TX(0) = texture2D(rubyTexture, gl_TexCoord[0].xy        ).rgb;
	
	for(int i=1; i<=rad; i++){
		TX(-i) = texture2D(rubyTexture, gl_TexCoord[0].xy + vec2(0.0,float(-i))/rubyTextureSize).rgb;
		TX( i) = texture2D(rubyTexture, gl_TexCoord[0].xy + vec2(0.0,float( i))/rubyTextureSize).rgb;
	}
	
	
	// prepare variables for candidate search
	
	ivec2 i1, i2;
	vec3 df1, df2;
	vec2 d1, d2, d3;
	bvec2 cn;
	
	df1 = TX(1)-TX(0); df2 = TX(0)-TX(-1);
	
	d2 = vec2(length(df1), length(df2));
	d3 = d2.yx;
	
	
	// smoothness weight, protects smooth gradients
	float sw = d2.x + d2.y;
	sw = sw == 0.0 ? 1.0 : pow(length(df1-df2)/sw, RAA_SMT0);
	
	
	// look for proper candidates
	for(int i=1; i<rad; i++){
		d1 = d2;
		d2 = d3;
		d3 = vec2(distance(TX(-i-1), TX(-i)), distance(TX(i), TX(i+1)));

		cn.x = max(d1.x,d3.x)<d2.x;
		cn.y = max(d1.y,d3.y)<d2.y;
		
		i2.x = cn.x && i2.x==0 && i1.x!=0 ? i : i2.x;
		i2.y = cn.y && i2.y==0 && i1.y!=0 ? i : i2.y;
		
		i1.x = cn.x && i1.x==0 ? i : i1.x;
		i1.y = cn.y && i1.y==0 ? i : i1.y;
		
	}

	i2.x = i2.x == 0 ? i1.x+1 : i2.x;
	i2.y = i2.y == 0 ? i1.y+1 : i2.y;
	
	// rAA core with the candidates found above
	vec3 t = res2x(TX(-i2.x), TX(-i1.x), TX(0), TX(i1.y), TX(i2.y));

	// distance weight
	float dw = ((i1.x == 0)||(i1.y == 0)) ? 0.0 : 2.0 * ((i1.x-1.0)/(i1.x+i1.y-2.0)) - 1.0;	
	
	// result
	vec3 res = TX(0) + (scl-1.0)/scl * sw*dw * t;
	
	// prevent ringing	
	vec3 lo  = min(min(TX(-1),TX(0)),TX(1));
	vec3 hi  = max(max(TX(-1),TX(0)),TX(1));
	
	gl_FragColor = vec4(clamp(res, lo, hi), 1.0);
}	
]]></fragment>


<vertex><![CDATA[

void main(void) {
    gl_Position = ftransform();
    gl_TexCoord[0] = gl_MultiTexCoord0;
	gl_TexCoord[0].xy = gl_TexCoord[0].xy*vec2(2.0,1.0);	
}
]]></vertex>


<fragment scale_x="2.0" scale_y="1.0" filter="linear"><![CDATA[
uniform sampler2D rubyTexture;
uniform vec2 rubyTextureSize;
uniform vec2 rubyInputSize;

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
    #define FXAA_PRESET 4
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
    #define FXAA_SEARCH_STEPS        12
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

	if (gl_TexCoord[0].x >= rubyInputSize.x/rubyTextureSize.x) 
	    fxaa_hq = texture2D(rubyTexture, gl_TexCoord[0].xy - vec2(rubyInputSize.x/rubyTextureSize.x,0.0));

	gl_FragColor = vec4(fxaa_hq, 1.0); 
}	
]]></fragment>


<vertex><![CDATA[
uniform vec2 rubyTextureSize;

void main(void) {
    gl_Position = ftransform();
    gl_TexCoord[0] = gl_MultiTexCoord0;
}
]]></vertex>

/*
   AA Shader 4.o Level2 Pass2 shader
   
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

<fragment scale="2.0" filter="linear"><![CDATA[
uniform sampler2D rubyTexture;
uniform vec2 rubyTextureSize;
uniform vec2 rubyInputSize;

const vec3 dt = vec3(1.0,1.0,1.0);

vec4 yx = vec4(0.5,0.5,-0.5,-0.5)/rubyTextureSize.xyxy;

void main()
{	
	vec2 tex = floor(gl_TexCoord[0].xy*rubyTextureSize)/rubyTextureSize + 0.5/rubyTextureSize; 
	if (gl_TexCoord[0].x >= 0.5*rubyInputSize.x/rubyTextureSize.x) gl_FragColor = texture2D(rubyTexture, tex); else
	
	{
	vec3 s00 = texture2D(rubyTexture, gl_TexCoord[0].xy + yx.zw).xyz; 
	vec3 s20 = texture2D(rubyTexture, gl_TexCoord[0].xy + yx.xw).xyz; 
	vec3 s22 = texture2D(rubyTexture, gl_TexCoord[0].xy + yx.xy).xyz; 
	vec3 s02 = texture2D(rubyTexture, gl_TexCoord[0].xy + yx.zy).xyz; 

	float m1=(dot(abs(s00-s22),dt)+0.0001);
	float m2=(dot(abs(s02-s20),dt)+0.0001);

	vec3 t1 = 0.5*(m2*(s00+s22)+m1*(s02+s20))/(m1+m2);

	gl_FragColor = vec4(t1,1.0); 
	}
}	
]]></fragment>


/* Deblur2 shader - Scalefx version
   
   Copyright (C) 2006 - 2020 guest(r) - guest.r@gmail.com

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
    gl_TexCoord[0] = gl_MultiTexCoord0 * 1.00001;
}
]]></vertex>


<fragment outscale="1.0" filter="linear"><![CDATA[

uniform sampler2D rubyTexture;
uniform sampler2D rubyOrigTexture;
uniform vec2 rubyInputSize;
uniform vec2 rubyOutputSize;
uniform vec2 rubyTextureSize;
uniform vec2 rubyOrigTextureSize;
uniform int rubyFrameCount;


#define SFXSHARP  0.35    // sharpness, from 0.0 to 1.0
#define SFXCRISP  1.50    // crispness, from 1.0 to 7.0

const vec3 dtt = vec3(0.0001,0.0001,0.0001);

void main()
{	
		vec2 texcoord0  = gl_TexCoord[0].xy*vec2(0.5,1.0);
		vec2 PIXEL_SIZE = 1.0/rubyTextureSize;
		vec2 texcoord = texcoord0;
		vec2 texp = texcoord0 + vec2(0.5*rubyInputSize.x/rubyTextureSize.x,0.0);

		vec3 color = texture2D(rubyTexture, texcoord).rgb;
		
		vec3 pixel, pixel1;
		float x;
		float LOOPSIZE = 1.0;

		vec2 tex = floor(texp*rubyTextureSize)/rubyTextureSize + 0.5/rubyTextureSize; 

		vec2 dx = vec2(1.0/rubyTextureSize.x, 0.0);
		vec2 dy = vec2(0.0, 1.0/rubyTextureSize.y);

		float w;
		float wsum = 0.0;
		vec3 ref = 0.0.xxx;
		vec3 dif;
		float y = -LOOPSIZE;
		
		do
		{
			x = -LOOPSIZE;
	
			do
			{
				pixel  = texture2D(rubyTexture, tex + x*dx + y*dy).rgb;
				dif = color - pixel;
				w = dot(dif, dif);
				w = 1.0/(pow(10.0*w + 0.0001, SFXCRISP));
				ref = ref + w*pixel;
				wsum = wsum + w;
				x = x + 1.0;
			
			} while (x <= LOOPSIZE);
		
			y = y + 1.0;
		
		} while (y <= LOOPSIZE);

		ref = ref/wsum;
		
		vec3 color1 = mix(color*color, ref*ref, SFXSHARP); color1 = sqrt(color1);
		vec3 color2 = mix(sqrt(color), sqrt(ref), SFXSHARP); color2 = color2*color2; 

		float k1 = dot(ref-color1,ref-color1) + 0.000001;
		float k2 = dot(ref-color2,ref-color2) + 0.000001;
		
		color = (color1*k2 + color2*k1)/(k1+k2); 

		gl_FragColor = vec4(color,1.0);	
}	
]]></fragment>


</shader>
