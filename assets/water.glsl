#version 330

//
// psrdnoise2.glsl
//
// Authors: Stefan Gustavson (stefan.gustavson@gmail.com)
// and Ian McEwan (ijm567@gmail.com)
// Version 2021-12-02, published under the MIT license (see below)
//
// Copyright (c) 2021 Stefan Gustavson and Ian McEwan.
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the "Software"),
// to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
// THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
// DEALINGS IN THE SOFTWARE.
//

//
// Periodic (tiling) 2-D simplex noise (hexagonal lattice gradient noise)
// with rotating gradients and analytic derivatives.
//
// This is (yet) another variation on simplex noise. Unlike previous
// implementations, the grid is axis-aligned and slightly stretched in
// the y direction to permit rectangular tiling.
// The noise pattern can be made to tile seamlessly to any integer period
// in x and any even integer period in y. Odd periods may be specified
// for y, but then the actual tiling period will be twice that number.
//
// The rotating gradients give the appearance of a swirling motion, and
// can serve a similar purpose for animation as motion along z in 3-D
// noise. The rotating gradients in conjunction with the analytic
// derivatives allow for "flow noise" effects as presented by Ken
// Perlin and Fabrice Neyret.
//


// Permutation polynomials for the hash value
vec3 permute1(vec3 i) {
  vec3 im = mod(i, 289.0);
  return mod((im*34.0+10.0)*im, 289.0);
}

vec3 permute2(vec3 i) {
	vec3 im = mod(i, 289.0);
	return mod((im*51.0+2.0)*im, 289.0);
}

//
// 2-D tiling simplex noise with rotating gradients and analytical derivative.
// "vec2 x" is the point (x,y) to evaluate,
// "vec2 period" is the desired periods along x and y, and
// "float alpha" is the rotation (in radians) for the swirling gradients.
// The "float" return value is the noise value, and
// the "out vec2 gradient" argument returns the x,y partial derivatives.
//
// Setting either period to 0.0 or a negative value will skip the wrapping
// along that dimension. Setting both periods to 0.0 makes the function
// execute about 15% faster.
//
// Not using the return value for the gradient will make the compiler
// eliminate the code for computing it. This speeds up the function
// by 10-15%.
//
// The rotation by alpha uses one single addition. Unlike the 3-D version
// of psrdnoise(), setting alpha == 0.0 gives no speedup.
//
float psrdnoise(vec2 x, vec2 period, float alpha, out vec2 gradient) {

  // Transform to simplex space (axis-aligned hexagonal grid)
  vec2 uv = vec2(x.x + x.y*0.5, x.y);
  
  // Determine which simplex we're in, with i0 being the "base"
  vec2 i0 = floor(uv);
  vec2 f0 = fract(uv);
  // o1 is the offset in simplex space to the second corner
  float cmp = step(f0.y, f0.x);
  vec2 o1 = vec2(cmp, 1.0-cmp);

  // Enumerate the remaining simplex corners
  vec2 i1 = i0 + o1;
  vec2 i2 = i0 + vec2(1.0, 1.0);

  // Transform corners back to texture space
  vec2 v0 = vec2(i0.x - i0.y * 0.5, i0.y);
  vec2 v1 = vec2(v0.x + o1.x - o1.y * 0.5, v0.y + o1.y);
  vec2 v2 = vec2(v0.x + 0.5, v0.y + 1.0);

  // Compute vectors from v to each of the simplex corners
  vec2 x0 = x - v0;
  vec2 x1 = x - v1;
  vec2 x2 = x - v2;

  vec3 iu, iv;
  vec3 xw, yw;

  // Wrap to periods, if desired
  if(any(greaterThan(period, vec2(0.0)))) {
	xw = vec3(v0.x, v1.x, v2.x);
	yw = vec3(v0.y, v1.y, v2.y);
    if(period.x > 0.0)
		xw = mod(vec3(v0.x, v1.x, v2.x), period.x);
	if(period.y > 0.0)
		yw = mod(vec3(v0.y, v1.y, v2.y), period.y);
    // Transform back to simplex space and fix rounding errors
    iu = floor(xw + 0.5*yw + 0.5);
	iv = floor(yw + 0.5);
  } else { // Shortcut if neither x nor y periods are specified
    iu = vec3(i0.x, i1.x, i2.x);
	iv = vec3(i0.y, i1.y, i2.y);
  }

  // Compute one pseudo-random hash value for each corner
  vec3 hash = permute1(permute2(iu) + iv);

  // Pick a pseudo-random angle and add the desired rotation
  vec3 psi = hash * 0.07482 + alpha;
  vec3 gx = cos(psi);
  vec3 gy = sin(psi);

  // Reorganize for dot products below
  vec2 g0 = vec2(gx.x,gy.x);
  vec2 g1 = vec2(gx.y,gy.y);
  vec2 g2 = vec2(gx.z,gy.z);

  // Radial decay with distance from each simplex corner
  vec3 w = 0.8 - vec3(dot(x0, x0), dot(x1, x1), dot(x2, x2));
  w = max(w, 0.0);
  vec3 w2 = w * w;
  vec3 w4 = w2 * w2;
  
  // The value of the linear ramp from each of the corners
  vec3 gdotx = vec3(dot(g0, x0), dot(g1, x1), dot(g2, x2));
  
  // Multiply by the radial decay and sum up the noise value
  float n = dot(w4, gdotx);

  // Compute the first order partial derivatives
  vec3 w3 = w2 * w;
  vec3 dw = -8.0 * w3 * gdotx;
  vec2 dn0 = w4.x * g0 + dw.x * x0;
  vec2 dn1 = w4.y * g1 + dw.y * x1;
  vec2 dn2 = w4.z * g2 + dw.z * x2;
  gradient = 10.9 * (dn0 + dn1 + dn2);

  // Scale the return value to fit nicely into the range [-1,1]
  return 10.9 * n;
}

// Source: https://github.com/glslify/glsl-aastep/blob/master/index.glsl
float aastep(float threshold, float value) {
    float afwidth = length(vec2(dFdx(value), dFdy(value))) * 0.70710678118654757;
    return smoothstep(threshold-afwidth, threshold+afwidth, value);
}

float gridlines(vec2 v, vec2 p, float width) {
  float distx = 0.0;
  if(p.x > 0.0) {
    distx = abs(mod(v.x+0.5*p.x,p.x)-0.5*p.x); // unsigned distance to nearest x line
  }
  float disty = 0.0;
  if(p.y > 0.0) {
    disty = abs(mod(v.y+0.5*p.y,p.y)-0.5*p.y);
  }
  float gridx = 1.0 - aastep(width, distx);
  float gridy = 1.0 - aastep(width, disty);
  return max(gridx, gridy);
}

in vec2 fragTexCoord;
out vec4 fragColor;
uniform float time;

void main(void)
{
    vec2 uv = fragTexCoord;
    const vec2 nscale = 4.0*vec2(1.0,2.0); // Waves
    const float tscale = 2.0; // Tiles
    vec2 v = nscale*(uv-0.5)+vec2(time*0.2,time);
    const vec2 p = vec2(0.0, 0.0);
    float alpha = 4.0*time;
    vec2 g;
     
    float n = psrdnoise(v, p, alpha, g);
    float w = clamp(0.6-uv.t + 0.01*n, 0.0, 1.0);
    w += 0.2*smoothstep(0.0, 0.1, w);
    float mask = aastep(0.01,w); // "This is water"
    vec2 vwarp = (uv-0.5)*tscale + 0.05*w*g*vec2(1.0,2.0);
 
    float tiles = gridlines(vwarp, vec2(1.0, 1.0), 0.05);
    vec3 tilecol = vec3(0.3,0.7,1.0);
    vec3 groutcol = vec3(0.3,0.3,0.8);
    vec4 watercol = vec4(1.0,1.0,1.0,0.3);
    vec3 mixcol = mix(tilecol, groutcol, tiles);
    mixcol = mix(mixcol, watercol.rgb, mask*watercol.a);
 
    fragColor = vec4(mixcol, 1.0);
}