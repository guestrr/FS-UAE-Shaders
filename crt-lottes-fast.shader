<?xml version="1.0" encoding="UTF-8"?>
<!--
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

#define hardPix -3.1

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
	
	
<fragment outscale="1.0" filter="nearest"><![CDATA[

uniform sampler2D rubyTexture;
uniform vec2 rubyInputSize;
uniform vec2 rubyOutputSize;
uniform vec2 rubyTextureSize;


vec2 dy = vec2(0.0, 1.0/rubyTextureSize.y);

// CRT-Lottes settings (editable)

#define shadowMask 1              // 1, 2, 3 or 4 (CRT style)
#define maskDark 0.5             
#define maskLight 1.5           
#define hardScan -8.0
#define brightboost 1.0
#define BLOOM  0.05
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
   return pow(c, vec3(GAMMA));
}


// Distance in emulated pixels to nearest texel.
vec2 Dist(vec2 pos){pos=pos*rubyTextureSize.xy;return -((pos-floor(pos))-vec2(0.5));}
    
// 1D Gaussian.
float Gaus(float pos,float scale){return exp2(scale*pos*pos);}
  
  
// Return scanline weight.
float Scan(vec2 pos,float off){
  float dst=Dist(pos).y;
  return Gaus(dst+off,hardScan);}
  

// Allow nearest three lines to effect pixel.
vec3 Tri(vec2 pos, vec2 crd){
  vec3 a=ToLinear(texture2D(rubyTexture,crd - dy).xyz);;
  vec3 b=ToLinear(texture2D(rubyTexture,crd     ).xyz);
  vec3 c=ToLinear(texture2D(rubyTexture,crd + dy).xyz);;
  float wa=Scan(pos,-1.0);
  float wb=Scan(pos, 0.0);
  float wc=Scan(pos, 1.0);
  return a*wa+b*wb+c*wc;}
  

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
	color+= BLOOM*color;
	gl_FragColor.rgb = color;
	gl_FragColor.a= 1.0;
}
]]></fragment>
	
	
</shader>
