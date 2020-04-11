<?xml version="1.0" encoding="UTF-8"?>
<!--
// xBRZ freescale multipass - by aliaspider
// based on :

// 4xBRZ shader - Copyright (C) 2014-2016 DeSmuME team
//
// This file is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 2 of the License, or
// (at your option) any later version.
//
// This file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with the this software.  If not, see <http://www.gnu.org/licenses/>.

// ported to XML format by guest.r
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
	

<fragment scale="1.0" filter="nearest"><![CDATA[
	
uniform sampler2D rubyTexture;
uniform vec2 rubyTextureSize;

#define SourceSize 1.0/rubyTextureSize

#define BLEND_NONE 0
#define BLEND_NORMAL 1
#define BLEND_DOMINANT 2
#define LUMINANCE_WEIGHT 1.0
#define EQUAL_COLOR_TOLERANCE 30.0/255.0
#define STEEP_DIRECTION_THRESHOLD 2.2
#define DOMINANT_DIRECTION_THRESHOLD 3.6

const vec3 dtt = vec3(65536.0,255.0,1.0);

float DistYCbCr(vec3 pixA, vec3 pixB)
{
  const vec3 w = vec3(0.2627, 0.6780, 0.0593);
  const float scaleB = 0.5 / (1.0 - w.b);
  const float scaleR = 0.5 / (1.0 - w.r);
  vec3 diff = pixA - pixB;
  float Y = dot(diff.rgb, w);
  float Cb = scaleB * (diff.b - Y);
  float Cr = scaleR * (diff.r - Y);

  return sqrt(((LUMINANCE_WEIGHT * Y) * (LUMINANCE_WEIGHT * Y)) + (Cb * Cb) + (Cr * Cr));
}
	
bool IsPixEqual(const vec3 pixA, const vec3 pixB)
{
  return (DistYCbCr(pixA, pixB) < EQUAL_COLOR_TOLERANCE);
}

float get_left_ratio(vec2 center, vec2 origin, vec2 direction, vec2 scale)
{
  vec2 P0 = center - origin;
  vec2 proj = direction * (dot(P0, direction) / dot(direction, direction));
  vec2 distv = P0 - proj;
  vec2 orth = vec2(-direction.y, direction.x);
  float side = sign(dot(P0, orth));
  float v = side * length(distv * scale);

//  return step(0, v);
  return smoothstep(-sqrt(2.0)/2.0, sqrt(2.0)/2.0, v);
}

#define eq(a,b)  (a == b)
#define neq(a,b) (a != b)

#define P(x,y) texture2D(rubyTexture, coord + SourceSize * vec2(x, y)).rgb

void main()
{
		
	vec2 OGLInvSize = vec2(1.0)/rubyTextureSize;	
    vec2 f = fract(gl_TexCoord[0].xy*rubyTextureSize);
    vec2 TexCoord_0 = gl_TexCoord[0].xy-f*OGLInvSize + 0.5*OGLInvSize;

  //---------------------------------------
  // Input Pixel Mapping:  -|x|x|x|-
  //                       x|A|B|C|x
  //                       x|D|E|F|x
  //                       x|G|H|I|x
  //                       -|x|x|x|-

  vec2 pos = fract(gl_TexCoord[0].xy * rubyTextureSize) - vec2(0.5, 0.5);
  vec2 coord = gl_TexCoord[0].xy - pos * SourceSize;

  vec3 A = P(-1.,-1.);
  vec3 B = P( 0.,-1.);
  vec3 C = P( 1.,-1.);
  vec3 D = P(-1., 0.);
  vec3 E = P( 0., 0.);
  vec3 F = P( 1., 0.);
  vec3 G = P(-1., 1.);
  vec3 H = P( 0., 1.);
  vec3 I = P( 1., 1.);

  // blendResult Mapping: x|y|
  //                      w|z|
  ivec4 blendResult = ivec4(BLEND_NONE,BLEND_NONE,BLEND_NONE,BLEND_NONE);

  // Preprocess corners
  // Pixel Tap Mapping: -|-|-|-|-
  //                    -|-|B|C|-
  //                    -|D|E|F|x
  //                    -|G|H|I|x
  //                    -|-|x|x|-
  if (!((eq(E,F) && eq(H,I)) || (eq(E,H) && eq(F,I))))
  {
    float dist_H_F = DistYCbCr(G, E) + DistYCbCr(E, C) + DistYCbCr(P(0.,2.), I) + DistYCbCr(I, P(2.,0.)) + (4.0 * DistYCbCr(H, F));
    float dist_E_I = DistYCbCr(D, H) + DistYCbCr(H, P(1.,2.)) + DistYCbCr(B, F) + DistYCbCr(F, P(2.,1.)) + (4.0 * DistYCbCr(E, I));
    bool dominantGradient = (DOMINANT_DIRECTION_THRESHOLD * dist_H_F) < dist_E_I;
    blendResult.z = ((dist_H_F < dist_E_I) && neq(E,F) && neq(E,H)) ? ((dominantGradient) ? BLEND_DOMINANT : BLEND_NORMAL) : BLEND_NONE;
  }


  // Pixel Tap Mapping: -|-|-|-|-
  //                    -|A|B|-|-
  //                    x|D|E|F|-
  //                    x|G|H|I|-
  //                    -|x|x|-|-
  if (!((eq(D,E) && eq(G,H)) || (eq(D,G) && eq(E,H))))
  {
    float dist_G_E = DistYCbCr(P(-2.,1.)  , D) + DistYCbCr(D, B) + DistYCbCr(P(-1.,2.), H) + DistYCbCr(H, F) + (4.0 * DistYCbCr(G, E));
    float dist_D_H = DistYCbCr(P(-2.,0.)  , G) + DistYCbCr(G, P(0.,2.)) + DistYCbCr(A, E) + DistYCbCr(E, I) + (4.0 * DistYCbCr(D, H));
    bool dominantGradient = (DOMINANT_DIRECTION_THRESHOLD * dist_D_H) < dist_G_E;
    blendResult.w = ((dist_G_E > dist_D_H) && neq(E,D) && neq(E,H)) ? ((dominantGradient) ? BLEND_DOMINANT : BLEND_NORMAL) : BLEND_NONE;
  }

  // Pixel Tap Mapping: -|-|x|x|-
  //                    -|A|B|C|x
  //                    -|D|E|F|x
  //                    -|-|H|I|-
  //                    -|-|-|-|-
  if (!((eq(B,C) && eq(E,F)) || (eq(B,E) && eq(C,F))))
  {
    float dist_E_C = DistYCbCr(D, B) + DistYCbCr(B, P(1,-2)) + DistYCbCr(H, F) + DistYCbCr(F, P(2.,-1.)) + (4.0 * DistYCbCr(E, C));
    float dist_B_F = DistYCbCr(A, E) + DistYCbCr(E, I) + DistYCbCr(P(0.,-2.), C) + DistYCbCr(C, P(2.,0.)) + (4.0 * DistYCbCr(B, F));
    bool dominantGradient = (DOMINANT_DIRECTION_THRESHOLD * dist_B_F) < dist_E_C;
    blendResult.y = ((dist_E_C > dist_B_F) && neq(E,B) && neq(E,F)) ? ((dominantGradient) ? BLEND_DOMINANT : BLEND_NORMAL) : BLEND_NONE;
  }

  // Pixel Tap Mapping: -|x|x|-|-
  //                    x|A|B|C|-
  //                    x|D|E|F|-
  //                    -|G|H|-|-
  //                    -|-|-|-|-
  if (!((eq(A,B) && eq(D,E)) || (eq(A,D) && eq(B,E))))
  {
    float dist_D_B = DistYCbCr(P(-2.,0.), A) + DistYCbCr(A, P(0.,-2.)) + DistYCbCr(G, E) + DistYCbCr(E, C) + (4.0 * DistYCbCr(D, B));
    float dist_A_E = DistYCbCr(P(-2.,-1.), D) + DistYCbCr(D, H) + DistYCbCr(P(-1.,-2.), B) + DistYCbCr(B, F) + (4.0 * DistYCbCr(A, E));
    bool dominantGradient = (DOMINANT_DIRECTION_THRESHOLD * dist_D_B) < dist_A_E;
    blendResult.x = ((dist_D_B < dist_A_E) && neq(E,D) && neq(E,B)) ? ((dominantGradient) ? BLEND_DOMINANT : BLEND_NORMAL) : BLEND_NONE;
  }

  gl_FragColor = vec4(blendResult);

  // Pixel Tap Mapping: -|-|-|-|-
  //                    -|-|B|C|-
  //                    -|D|E|F|x
  //                    -|G|H|I|x
  //                    -|-|x|x|-
  if(blendResult.z == BLEND_DOMINANT || (blendResult.z == BLEND_NORMAL &&
    !((blendResult.y != BLEND_NONE && !IsPixEqual(E, G)) || (blendResult.w != BLEND_NONE && !IsPixEqual(E, C)) ||
     (IsPixEqual(G, H) && IsPixEqual(H, I) && IsPixEqual(I, F) && IsPixEqual(F, C) && !IsPixEqual(E, I)))))
 {
   gl_FragColor.z += 4.0;

   float dist_F_G = DistYCbCr(F, G);
   float dist_H_C = DistYCbCr(H, C);

   if((STEEP_DIRECTION_THRESHOLD * dist_F_G <= dist_H_C) && neq(E,G) && neq(D,G))
      gl_FragColor.z += 16.0;

   if((STEEP_DIRECTION_THRESHOLD * dist_H_C <= dist_F_G) && neq(E,C) && neq(B,C))
      gl_FragColor.z += 64.0;
 }

  // Pixel Tap Mapping: -|-|-|-|-
  //                    -|A|B|-|-
  //                    x|D|E|F|-
  //                    x|G|H|I|-
  //                    -|x|x|-|-
  if(blendResult.w == BLEND_DOMINANT || (blendResult.w == BLEND_NORMAL &&
      !((blendResult.z != BLEND_NONE && !IsPixEqual(E, A)) || (blendResult.x != BLEND_NONE && !IsPixEqual(E, I)) ||
       (IsPixEqual(A, D) && IsPixEqual(D, G) && IsPixEqual(G, H) && IsPixEqual(H, I) && !IsPixEqual(E, G)))))
 {
   gl_FragColor.w += 4.0;

   float dist_H_A = DistYCbCr(H, A);
   float dist_D_I = DistYCbCr(D, I);

   if((STEEP_DIRECTION_THRESHOLD * dist_H_A <= dist_D_I) && neq(E,A) && neq(B,A))
      gl_FragColor.w += 16.0;

   if((STEEP_DIRECTION_THRESHOLD * dist_D_I <= dist_H_A) && neq(E,I) && neq(F,I))
      gl_FragColor.w += 64.0;
 }

  // Pixel Tap Mapping: -|-|x|x|-
  //                    -|A|B|C|x
  //                    -|D|E|F|x
  //                    -|-|H|I|-
  //                    -|-|-|-|-
  if(blendResult.y == BLEND_DOMINANT || (blendResult.y == BLEND_NORMAL &&
     !((blendResult.x != BLEND_NONE && !IsPixEqual(E, I)) || (blendResult.z != BLEND_NONE && !IsPixEqual(E, A)) ||
      (IsPixEqual(I, F) && IsPixEqual(F, C) && IsPixEqual(C, B) && IsPixEqual(B, A) && !IsPixEqual(E, C)))))
 {
   gl_FragColor.y += 4.0;

   float dist_B_I = DistYCbCr(B, I);
   float dist_F_A = DistYCbCr(F, A);

   if((STEEP_DIRECTION_THRESHOLD * dist_B_I <= dist_F_A) && neq(E,I) && neq(H,I))
      gl_FragColor.y += 16.0;

   if((STEEP_DIRECTION_THRESHOLD * dist_F_A <= dist_B_I) && neq(E,A) && neq(D,A))
      gl_FragColor.y += 64.0;
 }

  // Pixel Tap Mapping: -|x|x|-|-
  //                    x|A|B|C|-
  //                    x|D|E|F|-
  //                    -|G|H|-|-
  //                    -|-|-|-|-
  if(blendResult.x == BLEND_DOMINANT || (blendResult.x == BLEND_NORMAL &&
   !((blendResult.w != BLEND_NONE && !IsPixEqual(E, C)) || (blendResult.y != BLEND_NONE && !IsPixEqual(E, G)) ||
     (IsPixEqual(C, B) && IsPixEqual(B, A) && IsPixEqual(A, D) && IsPixEqual(D, G) && !IsPixEqual(E, A)))))
 {
   gl_FragColor.x += 4.0;

   float dist_D_C = DistYCbCr(D, C);
   float dist_B_G = DistYCbCr(B, G);

   if((STEEP_DIRECTION_THRESHOLD * dist_D_C <= dist_B_G) && neq(E,C) && neq(F,C))
      gl_FragColor.x += 16.0;

   if((STEEP_DIRECTION_THRESHOLD * dist_B_G <= dist_D_C) && neq(E,G) && neq(H,G))
      gl_FragColor.x += 64.0;
 }
 gl_FragColor /= 255.0;
 }
 
 ]]></fragment>

// Pass 2 
 
<vertex><![CDATA[

void main(void) {
    gl_Position = ftransform();
    gl_TexCoord[0] = gl_MultiTexCoord0;
}
]]></vertex>


<fragment scale_x="3.0"  scale_y="3.0" filter="nearest"><![CDATA[
uniform sampler2D rubyTexture;
uniform sampler2D rubyOrigTexture;
uniform vec2 rubyOrigTextureSize;
uniform vec2 rubyInputSize;
uniform vec2 rubyOutputSize;
uniform vec2 rubyTextureSize;

#define SourceSize vec4(rubyTextureSize, 1.0 / rubyTextureSize)
#define OutSize vec4(rubyOutputSize, 1.0 / rubyOutputSize)
#define OriginalSize vec4(rubyOrigTextureSize, 1.0 / rubyOrigTextureSize)

#define BLEND_NONE 0.
#define BLEND_NORMAL 1.
#define BLEND_DOMINANT 2.
#define LUMINANCE_WEIGHT 1.0
#define EQUAL_COLOR_TOLERANCE 30.0/255.0
#define STEEP_DIRECTION_THRESHOLD 2.2
#define DOMINANT_DIRECTION_THRESHOLD 3.6

float DistYCbCr(vec3 pixA, vec3 pixB)
{
  const vec3 w = vec3(0.2627, 0.6780, 0.0593);
  const float scaleB = 0.5 / (1.0 - w.b);
  const float scaleR = 0.5 / (1.0 - w.r);
  vec3 diff = pixA - pixB;
  float Y = dot(diff.rgb, w);
  float Cb = scaleB * (diff.b - Y);
  float Cr = scaleR * (diff.r - Y);

  return sqrt(((LUMINANCE_WEIGHT * Y) * (LUMINANCE_WEIGHT * Y)) + (Cb * Cb) + (Cr * Cr));
}

bool IsPixEqual(const vec3 pixA, const vec3 pixB)
{
  return (DistYCbCr(pixA, pixB) < EQUAL_COLOR_TOLERANCE);
}

float get_left_ratio(vec2 center, vec2 origin, vec2 direction, vec2 scale)
{
  vec2 P0 = center - origin;
  vec2 proj = direction * (dot(P0, direction) / dot(direction, direction));
  vec2 distv = P0 - proj;
  vec2 orth = vec2(-direction.y, direction.x);
  float side = sign(dot(P0, orth));
  float v = side * length(distv * scale);

//  return step(0, v);
  return smoothstep(-sqrt(2.0)/2.0, sqrt(2.0)/2.0, v);
}

#define eq(a,b)  (a == b)
#define neq(a,b) (a != b)

#define P(x,y) texture2D(rubyOrigTexture, coord + OriginalSize.zw * vec2(x, y)).rgb 


void main()
{	
  //---------------------------------------
  // Input Pixel Mapping: -|B|-
  //                      D|E|F
  //                      -|H|-

  vec2 tex = gl_TexCoord[0].xy * 1.00001;
  vec2 scale = OutSize.xy / rubyInputSize;
  vec2 pos = fract(tex * OriginalSize.xy) - vec2(0.5, 0.5);
  vec2 coord = tex - pos * OriginalSize.zw;

  vec3 B = P( 0.,-1.);
  vec3 D = P(-1., 0.);
  vec3 E = P( 0., 0.);
  vec3 F = P( 1., 0.);
  vec3 H = P( 0., 1.);

  vec4 info = floor(texture2D(rubyTexture, coord) * 255.0 + 0.5);

  // info Mapping: x|y|
  //               w|z|

  vec4 blendResult = floor(mod(info, 4.0));
  vec4 doLineBlend = floor(mod(info / 4.0, 4.0));
  vec4 haveShallowLine = floor(mod(info / 16.0, 4.0));
  vec4 haveSteepLine = floor(mod(info / 64.0, 4.0));

  vec3 res = E;

  // Pixel Tap Mapping: -|-|-
  //                    -|E|F
  //                    -|H|-

  if(blendResult.z > BLEND_NONE)
  {
    vec2 origin = vec2(0.0, 1.0 / sqrt(2.0));
    vec2 direction = vec2(1.0, -1.0);
    if(doLineBlend.z > 0.0)
    {
      origin = haveShallowLine.z > 0.0? vec2(0.0, 0.25) : vec2(0.0, 0.5);
      direction.x += haveShallowLine.z;
      direction.y -= haveSteepLine.z;
    }

    vec3 blendPix = mix(H,F, step(DistYCbCr(E, F), DistYCbCr(E, H)));
    res = mix(res, blendPix, get_left_ratio(pos, origin, direction, scale));
  }

  // Pixel Tap Mapping: -|-|-
  //                    D|E|-
  //                    -|H|-
  if(blendResult.w > BLEND_NONE)
  {
    vec2 origin = vec2(-1.0 / sqrt(2.0), 0.0);
    vec2 direction = vec2(1.0, 1.0);
    if(doLineBlend.w > 0.0)
    {
      origin = haveShallowLine.w > 0.0? vec2(-0.25, 0.0) : vec2(-0.5, 0.0);
      direction.y += haveShallowLine.w;
      direction.x += haveSteepLine.w;
    }

    vec3 blendPix = mix(H,D, step(DistYCbCr(E, D), DistYCbCr(E, H)));
    res = mix(res, blendPix, get_left_ratio(pos, origin, direction, scale));
  }

  // Pixel Tap Mapping: -|B|-
  //                    -|E|F
  //                    -|-|-
   if(blendResult.y > BLEND_NONE)
  {
    vec2 origin = vec2(1.0 / sqrt(2.0), 0.0);
    vec2 direction = vec2(-1.0, -1.0);

    if(doLineBlend.y > 0.0)
    {
      origin = haveShallowLine.y > 0.0? vec2(0.25, 0.0) : vec2(0.5, 0.0);
      direction.y -= haveShallowLine.y;
      direction.x -= haveSteepLine.y;
    }

    vec3 blendPix = mix(F,B, step(DistYCbCr(E, B), DistYCbCr(E, F)));
    res = mix(res, blendPix, get_left_ratio(pos, origin, direction, scale));
  }

  // Pixel Tap Mapping: -|B|-
  //                    D|E|-
  //                    -|-|-
  if(blendResult.x > BLEND_NONE)
  {
    vec2 origin = vec2(0.0, -1.0 / sqrt(2.0));
    vec2 direction = vec2(-1.0, 1.0);
    if(doLineBlend.x > 0.0)
    {
      origin = haveShallowLine.x > 0.0? vec2(0.0, -0.25) : vec2(0.0, -0.5);
      direction.x -= haveShallowLine.x;
      direction.y += haveSteepLine.x;
    }

    vec3 blendPix = mix(D,B, step(DistYCbCr(E, B), DistYCbCr(E, D)));
    res = mix(res, blendPix, get_left_ratio(pos, origin, direction, scale));
  }

  gl_FragColor = vec4(res, 1.0);
}	
]]></fragment>


/*
   2x Res-Crt-Fast Shader
   
   Copyright (C) 2020 guest(r) - guest.r@gmail.com

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

        void main()
        {
				gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
				gl_TexCoord[0] = gl_MultiTexCoord0;
        }
]]></vertex>
	
	
<fragment outscale_x="1.0"  outscale_y="1.0" filter="linear"><![CDATA[

uniform sampler2D rubyTexture;
uniform vec2 rubyInputSize;
uniform vec2 rubyOutputSize;
uniform vec2 rubyTextureSize;


#define bloom        0.40     // bloom intensity (from 0.0 to 1.0)        

#define masksize     1.00     // Mask Size (1.0 or 2.0 (2.0 for 4k))
#define slotmask     0.70     // Slot Mask Strength (from 0.0 to 1.0)
#define slotwidth    2.00     // Slot Mask Width  (from 1.0 to 4.0)
#define double_slot  1.00     // Slot Mask Height  (1.0 or 2.0)
#define slotms       1.00     // Slot Mask Size  (1.0 or 2.0)
#define mcut         0.20     // Mask 5&6 cutoff (0.0 to 0.5)
#define maskDark     0.20     // Dark "Phosphor"  (0.0 to 1.0)
#define maskLight    1.00     // Light "Phosphor"  (1.0 to 2.0)

#define brightboost1  1.25    // adjust brightness dark pixels
#define brightboost2  0.85     // adjust brightness bright pixels


vec3 Mask(vec2 pos, vec3 c)
{
	pos = floor(pos/masksize);
	vec3 mask = vec3(maskDark, maskDark, maskDark);
	
	float mx = max(max(c.r,c.g),c.b);
	vec3 maskTmp = vec3( min( 1.25*max(mx-mcut,0.0)/(1.0-mcut) ,maskDark + 0.2*(1.0-maskDark)*mx));
	float adj = 0.80*maskLight - 0.5*(0.80*maskLight - 1.0)*mx + 0.75*(1.0-mx);	
	mask = maskTmp;
	pos.x = fract(pos.x/2.0);
	if  (pos.x < 0.5)
	{	mask.r  = adj;
		mask.b  = adj;
	}
	else     mask.g = adj;
	return mask;
} 
 

float SlotMask(vec2 pos, vec3 c)
{
	if (slotmask == 0.0) return 1.0;
	
	pos = floor(pos/slotms);
	float mx = pow(max(max(c.r,c.g),c.b),1.33);
	float mlen = slotwidth*2.0;
	float px = fract(pos.x/mlen);
	float py = floor(fract(pos.y/(2.0*double_slot))*2.0*double_slot);
	float slot_dark = mix(1.0-slotmask, 1.0-0.80*slotmask, mx);
	float slot = 1.0 + 0.7*slotmask*(1.0-mx);
	if (py == 0.0 && px <  0.5) slot = slot_dark; else
	if (py == double_slot && px >= 0.5) slot = slot_dark;		
	
	return slot;
}    


void main()
{
	vec2 tex = gl_TexCoord[0].xy * 1.00001;

	vec2 size     = rubyTextureSize;
	vec2 inv_size = 1.0/size;

	vec2 OGL2Pos = tex * size;
	vec2 OGL2bPos = (gl_FragCoord.xy * 1.000001);
	vec2 fp = fract(OGL2Pos);
	vec2 dx = vec2(inv_size.x,0.0); vec2 x2 = dx + dx;
	vec2 dy = vec2(0.0, inv_size.y);
	float fpx = 1.0-fp.x;
	float f = fp.y;

	vec2 pC4 = floor(OGL2Pos) * inv_size + 0.5*inv_size;	

	pC4 -= dy;
	
	vec3 l1 = texture2D(rubyTexture, pC4 -dx).xyz; l1*=l1; 
	vec3 ct = texture2D(rubyTexture, pC4    ).xyz; ct*=ct;
	vec3 r1 = texture2D(rubyTexture, pC4 +dx).xyz; r1*=r1;
	
	vec3 color0 = mix( 0.5*(ct+r1), 0.5*(ct+l1), fpx);
	
	pC4 += dy;
	
	l1 = texture2D(rubyTexture, pC4 -dx).xyz; l1*=l1; 
	ct = texture2D(rubyTexture, pC4    ).xyz; ct*=ct;
	r1 = texture2D(rubyTexture, pC4 +dx).xyz; r1*=r1;
	
	vec3 color1 = mix( 0.5*(ct+r1), 0.5*(ct+l1), fpx);
	
	pC4 += dy;
	
	l1 = texture2D(rubyTexture, pC4 -dx).xyz; l1*=l1; 
	ct = texture2D(rubyTexture, pC4    ).xyz; ct*=ct;
	r1 = texture2D(rubyTexture, pC4 +dx).xyz; r1*=r1;
	
	vec3 color2 = mix( 0.5*(ct+r1), 0.5*(ct+l1), fpx);
	
	// calculate bloom color
	
	dx = x2; x2 = dx+dx; dy*=2.0; pC4 -= 1.5*dy;

	l1 = texture2D(rubyTexture, pC4 -dx).xyz; l1*=l1; 
	ct = texture2D(rubyTexture, pC4    ).xyz; ct*=ct;
	r1 = texture2D(rubyTexture, pC4 +dx).xyz; r1*=r1;
	
	vec3 bcolor0 = mix( 0.5*(ct+r1), 0.5*(ct+l1), fpx);
	
	pC4 += dy;
	
	l1 = texture2D(rubyTexture, pC4 -dx).xyz; l1*=l1; 
	ct = texture2D(rubyTexture, pC4    ).xyz; ct*=ct;
	r1 = texture2D(rubyTexture, pC4 +dx).xyz; r1*=r1;
	
	vec3 bcolor1 = mix( 0.5*(ct+r1), 0.5*(ct+l1), fpx);
	
	pC4 += dy;
	
	l1 = texture2D(rubyTexture, pC4 -dx).xyz; l1*=l1; 
	ct = texture2D(rubyTexture, pC4    ).xyz; ct*=ct;
	r1 = texture2D(rubyTexture, pC4 +dx).xyz; r1*=r1;
	
	vec3 bcolor2 = mix( 0.5*(ct+r1), 0.5*(ct+l1), fpx);

	vec3 icolor1 = mix(color1, color0, 0.5);
	vec3 icolor2 = mix(color1, color2, 0.5);
	vec3 color = mix(icolor1, icolor2, f);
	
	vec3 mcolor = pow(color, vec3(0.65));
	
	vec3 b1 = mix(bcolor1, bcolor0, 0.5);
	vec3 b2 = mix(bcolor1, bcolor2, 0.5);
	vec3 Bloom = mix(b1, b2, f);
	
	float pixbr = max(max(color.r, color.g), color.b);
	color*= mix(brightboost1, brightboost2, pixbr);
	color = min(color,1.0);

	vec3 cmask = vec3(1.0); vec3 cmask1 = cmask; vec3 one = vec3(1.0); vec3 orig1 = color;
	
	cmask*= Mask(OGL2bPos,mcolor);
	
	color = color*cmask;
	
	color = min(color,1.0);
	
	cmask1 *= SlotMask(OGL2bPos, mcolor);

	color = color*cmask1; cmask = cmask*cmask1; cmask = min(cmask, 1.0); 
	
	vec3 Bloom1 = 2.0*Bloom*Bloom;
	Bloom1 = min(Bloom1, 0.80);
	float bmax = max(max(Bloom1.r,Bloom1.g),Bloom1.b);
	float pmax = 0.825;
	Bloom1 = min(Bloom1, pmax*bmax)/pmax;
	
	Bloom1 = mix(min( Bloom1, color), Bloom1, 0.5*(orig1+color));
	
	Bloom1 = bloom*Bloom1;
	
	color = color + Bloom1; 	
	
	gl_FragColor.rgb = sqrt(color);
	gl_FragColor.a = 1.0;
}
]]></fragment>


 </shader>
