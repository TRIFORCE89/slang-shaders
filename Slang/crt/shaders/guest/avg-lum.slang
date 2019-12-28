#version 450

/*
   Average Luminance Shader, Smart Smoothing Difference Shader
   
   Copyright (C) 2018-2019 guest(r) - guest.r@gmail.com

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
   
   Thanks to HunterK for the mipmap hint. :D  
*/

layout(push_constant) uniform Push
{
	vec4 SourceSize;
   float STH;
} params;

#pragma parameter STH "Smart Smoothing Threshold" 0.7 0.4 1.2 0.05

#define STH params.STH
#define COMPAT_TEXTURE(c,d) texture(c,d)
#define SourceSize params.SourceSize
#define InputSize SourceSize
#define TEX0 vTexCoord

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord * 1.0001;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D WhitePointPass;

#define PassPrev2Texture WhitePointPass

float df (vec3 A, vec3 B)
{
	float diff = length(A-B);
	float luma = clamp(length(0.5*min(A,B) + 0.25*(A+B) + 1e-8), 0.0001, 1.0);
	float diff1 = diff/luma;
	return 1.0 - clamp(7.0*(max(1.5*diff,diff1)-STH), 0.0, 0.9999);
}

void main()
{
	float xtotal = floor(InputSize.x/64.0);
	float ytotal = floor(InputSize.y/64.0);
	
	float ltotal = 0.0;
	
	vec2 dx  = vec2(SourceSize.z, 0.0)*64.0;
	vec2 dy  = vec2(0.0, SourceSize.w)*64.0;
	vec2 offset = 0.25*(dx+dy);
	
	for (float i = 0.0; i <= xtotal; i++)
	{
		for (float j = 0.0; j <= ytotal; j++)
			{
				ltotal+= max(0.25, length(textureLod(Source, i*dx + j*dy + offset, 6.0).rgb));
			}
	}
   
	ltotal = 0.577350269 * ltotal / ((xtotal+1.0)*(ytotal+1.0));

	dx  = vec2(SourceSize.z, 0.0);	
	dy  = vec2(0.0, SourceSize.w);	

	vec3 l1 = COMPAT_TEXTURE(PassPrev2Texture, TEX0.xy -dx).xyz;
	vec3 ct = COMPAT_TEXTURE(PassPrev2Texture, TEX0.xy    ).xyz;
	vec3 r1 = COMPAT_TEXTURE(PassPrev2Texture, TEX0.xy +dx).xyz;
	vec3 t1 = COMPAT_TEXTURE(PassPrev2Texture, TEX0.xy -dy).xyz;
	vec3 b1 = COMPAT_TEXTURE(PassPrev2Texture, TEX0.xy +dy).xyz;	
	
	float dl = df(ct, l1);
	float dr = df(ct, r1);
	float dt = df(ct, t1);
	float db = df(ct, b1);
	
	float resx = dl; float resy = dr; float resz = floor(9.0*dt)/10.0 + floor(9.0*db)/100.0;
	
	FragColor = vec4(resx,resy,resz,pow(ltotal, 0.65));
}