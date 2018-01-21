#version 300 es

uniform mat4 u_Model;

uniform mat4 u_ModelInvTr;

uniform mat4 u_ViewProj;

uniform int u_Time;

in vec4 vs_Pos;

in vec4 vs_Nor;

in vec4 vs_Col;

out vec4 fs_Nor;
out vec4 fs_LightVec;
out vec4 fs_Col;
out vec4 fs_Pos;
out vec4 fs_SphereNor;
out float fs_Spec;
out float fs_Valid;

vec4 lightPos = vec4(5, 0, 3, 1);

const float DEGREE_TO_RAD = 0.0174533;
const float RAD_TO_DEGREE = 57.2958;

//  Classic Perlin 3D Noise
//  by Stefan Gustavson
//
vec4 permute(vec4 x) { return mod(((x * 34.0) + 1.0) * x, 289.0); }
vec4 taylorInvSqrt(vec4 r) { return 1.79284291400159 - 0.85373472095314 * r; }
vec3 fade(vec3 t) { return t * t * t * (t * (t * 6.0 - 15.0) + 10.0); }

float cnoise(vec3 P) {
  vec3 Pi0 = floor(P);         // Integer part for indexing
  vec3 Pi1 = Pi0 + vec3(1.0);  // Integer part + 1
  Pi0 = mod(Pi0, 289.0);
  Pi1 = mod(Pi1, 289.0);
  vec3 Pf0 = fract(P);         // Fractional part for interpolation
  vec3 Pf1 = Pf0 - vec3(1.0);  // Fractional part - 1.0
  vec4 ix = vec4(Pi0.x, Pi1.x, Pi0.x, Pi1.x);
  vec4 iy = vec4(Pi0.yy, Pi1.yy);
  vec4 iz0 = Pi0.zzzz;
  vec4 iz1 = Pi1.zzzz;

  vec4 ixy = permute(permute(ix) + iy);
  vec4 ixy0 = permute(ixy + iz0);
  vec4 ixy1 = permute(ixy + iz1);

  vec4 gx0 = ixy0 / 7.0;
  vec4 gy0 = fract(floor(gx0) / 7.0) - 0.5;
  gx0 = fract(gx0);
  vec4 gz0 = vec4(0.5) - abs(gx0) - abs(gy0);
  vec4 sz0 = step(gz0, vec4(0.0));
  gx0 -= sz0 * (step(0.0, gx0) - 0.5);
  gy0 -= sz0 * (step(0.0, gy0) - 0.5);

  vec4 gx1 = ixy1 / 7.0;
  vec4 gy1 = fract(floor(gx1) / 7.0) - 0.5;
  gx1 = fract(gx1);
  vec4 gz1 = vec4(0.5) - abs(gx1) - abs(gy1);
  vec4 sz1 = step(gz1, vec4(0.0));
  gx1 -= sz1 * (step(0.0, gx1) - 0.5);
  gy1 -= sz1 * (step(0.0, gy1) - 0.5);

  vec3 g000 = vec3(gx0.x, gy0.x, gz0.x);
  vec3 g100 = vec3(gx0.y, gy0.y, gz0.y);
  vec3 g010 = vec3(gx0.z, gy0.z, gz0.z);
  vec3 g110 = vec3(gx0.w, gy0.w, gz0.w);
  vec3 g001 = vec3(gx1.x, gy1.x, gz1.x);
  vec3 g101 = vec3(gx1.y, gy1.y, gz1.y);
  vec3 g011 = vec3(gx1.z, gy1.z, gz1.z);
  vec3 g111 = vec3(gx1.w, gy1.w, gz1.w);

  vec4 norm0 = taylorInvSqrt(
      vec4(dot(g000, g000), dot(g010, g010), dot(g100, g100), dot(g110, g110)));
  g000 *= norm0.x;
  g010 *= norm0.y;
  g100 *= norm0.z;
  g110 *= norm0.w;
  vec4 norm1 = taylorInvSqrt(
      vec4(dot(g001, g001), dot(g011, g011), dot(g101, g101), dot(g111, g111)));
  g001 *= norm1.x;
  g011 *= norm1.y;
  g101 *= norm1.z;
  g111 *= norm1.w;

  float n000 = dot(g000, Pf0);
  float n100 = dot(g100, vec3(Pf1.x, Pf0.yz));
  float n010 = dot(g010, vec3(Pf0.x, Pf1.y, Pf0.z));
  float n110 = dot(g110, vec3(Pf1.xy, Pf0.z));
  float n001 = dot(g001, vec3(Pf0.xy, Pf1.z));
  float n101 = dot(g101, vec3(Pf1.x, Pf0.y, Pf1.z));
  float n011 = dot(g011, vec3(Pf0.x, Pf1.yz));
  float n111 = dot(g111, Pf1);

  vec3 fade_xyz = fade(Pf0);
  vec4 n_z = mix(vec4(n000, n100, n010, n110), vec4(n001, n101, n011, n111),
                 fade_xyz.z);
  vec2 n_yz = mix(n_z.xy, n_z.zw, fade_xyz.y);
  float n_xyz = mix(n_yz.x, n_yz.y, fade_xyz.x);
  return 2.2 * n_xyz;
}

float snoise(vec3 v) {
  const vec2 C = vec2(1.0 / 6.0, 1.0 / 3.0);
  const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);

  // First corner
  vec3 i = floor(v + dot(v, C.yyy));
  vec3 x0 = v - i + dot(i, C.xxx);

  // Other corners
  vec3 g = step(x0.yzx, x0.xyz);
  vec3 l = 1.0 - g;
  vec3 i1 = min(g.xyz, l.zxy);
  vec3 i2 = max(g.xyz, l.zxy);

  //  x0 = x0 - 0. + 0.0 * C
  vec3 x1 = x0 - i1 + 1.0 * C.xxx;
  vec3 x2 = x0 - i2 + 2.0 * C.xxx;
  vec3 x3 = x0 - 1. + 3.0 * C.xxx;

  // Permutations
  i = mod(i, 289.0);
  vec4 p = permute(permute(permute(i.z + vec4(0.0, i1.z, i2.z, 1.0)) + i.y +
                           vec4(0.0, i1.y, i2.y, 1.0)) +
                   i.x + vec4(0.0, i1.x, i2.x, 1.0));

  // Gradients
  // ( N*N points uniformly over a square, mapped onto an octahedron.)
  float n_ = 1.0 / 7.0;  // N=7
  vec3 ns = n_ * D.wyz - D.xzx;

  vec4 j = p - 49.0 * floor(p * ns.z * ns.z);  //  mod(p,N*N)

  vec4 x_ = floor(j * ns.z);
  vec4 y_ = floor(j - 7.0 * x_);  // mod(j,N)

  vec4 x = x_ * ns.x + ns.yyyy;
  vec4 y = y_ * ns.x + ns.yyyy;
  vec4 h = 1.0 - abs(x) - abs(y);

  vec4 b0 = vec4(x.xy, y.xy);
  vec4 b1 = vec4(x.zw, y.zw);

  vec4 s0 = floor(b0) * 2.0 + 1.0;
  vec4 s1 = floor(b1) * 2.0 + 1.0;
  vec4 sh = -step(h, vec4(0.0));

  vec4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
  vec4 a1 = b1.xzyw + s1.xzyw * sh.zzww;

  vec3 p0 = vec3(a0.xy, h.x);
  vec3 p1 = vec3(a0.zw, h.y);
  vec3 p2 = vec3(a1.xy, h.z);
  vec3 p3 = vec3(a1.zw, h.w);

  // Normalise gradients
  vec4 norm =
      taylorInvSqrt(vec4(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3)));
  p0 *= norm.x;
  p1 *= norm.y;
  p2 *= norm.z;
  p3 *= norm.w;

  // Mix final noise value
  vec4 m =
      max(0.6 - vec4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
  m = m * m;
  return 42.0 *
         dot(m * m, vec4(dot(p0, x0), dot(p1, x1), dot(p2, x2), dot(p3, x3)));
}

float fbm(vec3 x) {
  float v = 0.0;
  float a = 0.5;
  vec3 shift = vec3(100);
  for (int i = 0; i < 8; ++i) {
    v += a * cnoise(x);
    x = x * 2.0 + shift;
    a *= 0.5;
  }
  return (v + 1.0) / 2.0;
}

vec3 calcNormal(in vec3 pos) {
  float eps = 0.5;
  float f0 = fbm(pos);
  float fx = fbm(pos + vec3(eps, 0, 0));
  float fy = fbm(pos + vec3(0, eps, 0));
  float fz = fbm(pos + vec3(0, 0, eps));
  return normalize(vec3((fx - f0) / eps, (fy - f0) / eps, (fz - f0) / eps));
}

float hash1( float n )
{
    return fract( n*17.0*fract( n*0.3183099 ) );
}

vec4 noised( in vec3 x )
{
    vec3 p = floor(x);
    vec3 w = fract(x);
    
    vec3 u = w*w*w*(w*(w*6.0-15.0)+10.0);
    vec3 du = 30.0*w*w*(w*(w-2.0)+1.0);

    float n = p.x + 317.0*p.y + 157.0*p.z;
    
    float a = hash1(n+0.0);
    float b = hash1(n+1.0);
    float c = hash1(n+317.0);
    float d = hash1(n+318.0);
    float e = hash1(n+157.0);
    float f = hash1(n+158.0);
    float g = hash1(n+474.0);
    float h = hash1(n+475.0);

    // float a = cnoise( p+vec3(0,0,0) );
    // float b = cnoise( p+vec3(1,0,0) );
    // float c = cnoise( p+vec3(0,1,0) );
    // float d = cnoise( p+vec3(1,1,0) );
    // float e = cnoise( p+vec3(0,0,1) );
    // float f = cnoise( p+vec3(1,0,1) );
    // float g = cnoise( p+vec3(0,1,1) );
    // float h = cnoise( p+vec3(1,1,1) );

    float k0 =   a;
    float k1 =   b - a;
    float k2 =   c - a;
    float k3 =   e - a;
    float k4 =   a - b - c + d;
    float k5 =   a - c - e + g;
    float k6 =   a - b - e + f;
    float k7 = - a + b + c - d + e - f - g + h;

    return vec4( -1.0+2.0*(k0 + k1*u.x + k2*u.y + k3*u.z + k4*u.x*u.y + k5*u.y*u.z + k6*u.z*u.x + k7*u.x*u.y*u.z), 
                      2.0* du * vec3( k1 + k4*u.y + k6*u.z + k7*u.y*u.z,
                                      k2 + k5*u.z + k4*u.x + k7*u.z*u.x,
                                      k3 + k6*u.x + k5*u.y + k7*u.x*u.y ) );
}


const mat3 m3  = mat3( 0.00,  0.80,  0.60,
                      -0.80,  0.36, -0.48,
                      -0.60, -0.48,  0.64 );
const mat3 m3i = mat3( 0.00, -0.80, -0.60,
                       0.80,  0.36, -0.48,
                       0.60, -0.48,  0.64 );

vec4 fbmad( in vec3 x, int octaves ) 
{
    float f = 1.98;  // could be 2.0
    float s = 0.49;  // could be 0.5
    float a = 0.0;
    float b = 0.5;
    vec3  d = vec3(0.0);
    mat3  m = mat3(1.0,0.0,0.0,
                   0.0,1.0,0.0,
                   0.0,0.0,1.0);
    for( int i=0; i < octaves; i++ )
    {
        vec4 n = noised(x);
        a += b*n.x;          // accumulate values   
        d += b*m*n.yzw;      // accumulate derivatives
        b *= s;
        x = f*m3*x;
        m = f*m3i*m;
    }
    return vec4( a, d );
}

const vec4 GRASS_COLOR_1 = vec4(vec3(112.0, 166.0, 3.0) / 255.0, 1.0);
const vec4 GRASS_COLOR_2 = vec4(vec3(56.0, 140.0, 28.0) / 255.0, 1.0);

const vec4 MARSH_COLOR_1 = vec4(vec3(50.0, 64.0, 1.0) / 255.0, 1.0);
const vec4 MARSH_COLOR_2 = vec4(vec3(70.0, 89.0, 2.0) / 255.0, 1.0);

const vec4 ROCK_COLOR_1 = vec4(vec3(103.0, 70.0, 49.0) / 255.0, 1.0);
const vec4 ROCK_COLOR_2 = vec4(vec3(94.0, 87.0, 82.0) / 255.0, 1.0);

const vec4 SAND_COLOR_1 = vec4(vec3(237.0, 209.0, 127.0) / 255.0, 1.0);
const vec4 SAND_COLOR_2 = vec4(vec3(255.0, 198.0, 57.0) / 255.0, 1.0);

const vec4 WATER_COLOR_1 = vec4(vec3(107.0, 137.0, 186.0) / 255.0, 1.0);
const vec4 WATER_COLOR_2 = vec4(vec3(87.0, 112.0, 163.0) / 255.0, 1.0);

const vec4 FIRE_COLOR_1 = vec4(vec3(217.0, 63.0, 7.0) / 255.0, 1.0);
const vec4 FIRE_COLOR_2 = vec4(vec3(242.0, 193.0, 102.0) / 255.0, 1.0);

const vec4 RAINFOREST_COLOR_1 = vec4(vec3(81.0, 89.0, 0.0) / 255.0, 1.0);

const vec4 SNOW_COLOR_1 = vec4(vec3(232.0, 232.0, 232.0) / 255.0, 1.0);

const vec4 BEDROCK_COLOR_1 = vec4(vec3(68.0, 85.0, 102.0) / 255.0, 1.0);
const vec4 BEDROCK_COLOR_2 = vec4(vec3(34.0, 43.0, 51.0) / 255.0, 1.0);

float mountainStartRange = 0.325;

// Was too lazy
// Taken From: http://www.neilmendoza.com/glsl-rotation-about-an-arbitrary-axis/
mat4 rotationMatrix(vec3 axis, float angle) {
  axis = normalize(axis);
  float s = sin(angle);
  float c = cos(angle);
  float oc = 1.0 - c;

  return mat4(
      oc * axis.x * axis.x + c, oc * axis.x * axis.y - axis.z * s,
      oc * axis.z * axis.x + axis.y * s, 0.0, oc * axis.x * axis.y + axis.z * s,
      oc * axis.y * axis.y + c, oc * axis.y * axis.z - axis.x * s, 0.0,
      oc * axis.z * axis.x - axis.y * s, oc * axis.y * axis.z + axis.x * s,
      oc * axis.z * axis.z + c, 0.0, 0.0, 0.0, 0.0, 1.0);
}

float rayConeIntersection(vec3 rayOrigin, vec3 rayDirection, vec3 coneTip,
                          vec3 coneAxisVector, float coneAngleInDegrees) {
  vec3 v = normalize(coneAxisVector);
  float rads = coneAngleInDegrees * DEGREE_TO_RAD;
  float cosAxisSq = cos(rads) * cos(rads);

  vec3 co = rayOrigin - coneTip;

  float dvDot = dot(rayDirection, v);
  float covDot = dot(co, v);

  float a = dvDot * dvDot - cosAxisSq;
  float b = 2.0 * (dvDot * covDot - (dot(rayDirection, co) * cosAxisSq));
  float c = covDot * covDot - (dot(co, co) * cosAxisSq);

  float disc = pow(b, 2.0) - (4.0 * a * c);

  if (disc < 0.0) {
    return 0.0;
  }

  float t0 = (-1.0 * b - sqrt(disc)) / (2.0 * a);
  float t1 = (-1.0 * b + sqrt(disc)) / (2.0 * a);

  if (t0 > 0.0) {
    return t0;
  }

  if (t1 > 0.0) {
    return t1;
  }

  return 0.0;
}

bool drawVolcano(vec3 target, inout vec4 vertexPosition,
                 inout vec4 vertexNormal, inout vec4 vertexColor) {
  bool result = false;
  vec3 vertexPositionVec3 = vertexPosition.xyz;
  float dist = distance(target, vertexPositionVec3);

  vec3 growthDir = normalize(target); // Icosphere at center

  if (dist < 0.4) {
    vec3 rayDirection = normalize(vertexPositionVec3 - target);
    vec3 rayOrigin = vertexPositionVec3;

    vec3 coneTip = target + (growthDir * 0.5);
    vec3 coneAxisVector = normalize(target - coneTip);

    float tValue = rayConeIntersection(rayOrigin, rayDirection, coneTip,
                                       coneAxisVector, 10.0);

    if (tValue > 0.1) {
      tValue = 0.1;
    }

    float coneCenter =
        dot(normalize(rayOrigin - coneTip), normalize(coneAxisVector));

    if (tValue > 0.0) {
      vec3 point = rayOrigin + (tValue * rayDirection);

      vertexPosition = vec4(point, 1);
      vertexNormal = vec4(normalize(point - target), 0);

      vertexColor = ROCK_COLOR_2;
      result = true;

      vec3 df = calcNormal(vertexPosition.xyz * 513.6) * 0.15;
      vertexNormal = normalize(vec4(df, 0) + vertexNormal);
    }

    if (coneCenter >= 1.0 - 0.001) {
      vertexPosition = vec4(vertexPosition.xyz + (coneAxisVector * 0.1), 1.0);

      float mixValue = mod(float(u_Time) * 0.05, 10.0);

      if (mixValue >= 5.0) {
        mixValue = (mixValue - 5.0) / 5.0;
        vertexColor = mix(FIRE_COLOR_1, FIRE_COLOR_2, mixValue);
      } else {
        mixValue = mixValue / 5.0;
        vertexColor = mix(FIRE_COLOR_2, FIRE_COLOR_1, mixValue);
      }
    }
  }

  return result;
}

void renderPlanet(inout vec4 vertexPosition, inout vec4 vertexNormal,
                  inout vec4 vertexColor, bool isNight) {
  vertexColor = WATER_COLOR_1;

  fs_Valid = 0.0;

  vec4 originalPosition = vertexPosition;
  vec4 originalNormal = vertexNormal;

  fs_SphereNor = originalNormal;

  vec3 noiseInput = vertexPosition.xyz * 3.0;

  float waterThreshold = 0.0;
  float deepWaterThreshold = waterThreshold - 0.15;
  float maxScale = 1.0;

  vec4 noiseAd = fbmad(noiseInput, 8);
  float noise = noiseAd.x;
  vec3 derivative = noiseAd.yzw;

  noiseInput = vertexPosition.xyz * 0.532;
  float rainfallNoise = fbm(noiseInput);

  float originalNoise = noise;

  bool isWater = noise < waterThreshold ? true : false;
  bool isGrass = noise > waterThreshold ? true : false;
  bool isMountains = false;
  bool isCoast = false;

  if (isWater) {
    vertexColor = BEDROCK_COLOR_1;
    vertexNormal = vec4(normalize(vertexNormal.xyz - (noiseAd.yzw * 0.5)), 0);

    if (noise < deepWaterThreshold) {
      vertexColor = BEDROCK_COLOR_2;
    }
  } else {
  
    vertexColor = GRASS_COLOR_1;

    fs_Spec = 0.0;

    if (noise < 0.04) {
      vertexColor = SAND_COLOR_1;
      fs_Spec = 2.0;
      isCoast = true;
    } else if (noise > 0.15) {
      vertexColor = GRASS_COLOR_2;
    }
  }

  float landNoise = noise;
  float landHeight = landNoise / 4.0;
  vertexPosition = originalPosition + (originalNormal * landHeight);

  vec4 landPosition = vertexPosition;

  if (isGrass) {
    vertexNormal = vec4(normalize(vertexNormal.xyz - (noiseAd.yzw * 0.36)), 0);

    if (landNoise > 0.3) {
      vertexColor = ROCK_COLOR_1;

      float snowAppearance = dot(normalize(derivative), vec3(0,1,0));

      vertexNormal = vec4(normalize(originalNormal.xyz - (noiseAd.yzw * 0.45)), 0);

      if (landNoise > 0.4 && snowAppearance > 0.5) {
        vertexColor = SNOW_COLOR_1;
        fs_Spec = 128.0;
      }
    }
    // else if (rainfallNoise > 0.2 && landNoise < 0.1) {
    //   vertexColor = MARSH_COLOR_1;

    //   noiseInput = vertexPosition.xyz * 23.7;
    //   float riverNoise = abs(fbm(noiseInput));

    //   if (riverNoise > 0.2) {
    //     float height = -0.02;
    //     vertexPosition = vertexPosition + (vertexNormal * height);
    //     vertexColor = WATER_COLOR_1;
    //   } else if (riverNoise > 0.25) {
    //     vertexColor = MARSH_COLOR_2;
    //   }
    // } else if (rainfallNoise > 0.2) {
    //   vertexColor = RAINFOREST_COLOR_1;
    // } else if (rainfallNoise < -0.4 && landNoise < 0.1) {
    //   vertexColor = SAND_COLOR_2;
    //   vec3 df = calcNormal(vertexPosition.xyz * 237.6) * 0.25;
    //   vertexNormal = normalize(vec4(df, 0) + vertexNormal);
    // } else {
    //   // Just grass
    //   vec3 df = calcNormal(vertexPosition.xyz * 137.6) * 0.05;
    //   vertexNormal = normalize(vec4(df, 0) + vertexNormal);
    // }

  }

  // vec4 pos = landPosition;
  // vec4 normal = originalNormal;
  // bool isDirty = false;
  // bool result = false;

  // vec4 volcanoCenter;

  // if (!isDirty) {
  //   volcanoCenter = rotationMatrix(vec3(1, 0, 0), -25.0 * DEGREE_TO_RAD) * vec4(0, 0.9, 0, 1);
  //   result = drawVolcano(vec3(volcanoCenter), pos, normal, vertexColor);
  // }

  // if (result && !isDirty) {
  //   vertexPosition = pos;
  //   vertexNormal = normal;
  //   isDirty = true;
  // }

  // if (!isDirty) {
  //   volcanoCenter = rotationMatrix(vec3(0, 1, 0), -80.0 * DEGREE_TO_RAD) * rotationMatrix(vec3(1, 0, 0), -100.0 * DEGREE_TO_RAD) * vec4(0, 0.9, 0, 1);
  //   result = drawVolcano(vec3(volcanoCenter), pos, normal, vertexColor);
  // }

  // if (result && !isDirty) {
  //   vertexPosition = pos;
  //   vertexNormal = normal;
  //   isDirty = true;
  // }

  // if (noise > 0.1) {
  //   vec3 df = calcNormal(vertexPosition.xyz);
  //   vertexNormal = vec4(normalize(vertexNormal.xyz - df), 0);
  // }
}

void main() {
  vec4 vertexColor;
  vec4 vertexPosition = vs_Pos;
  vec4 vertexNormal = vs_Nor;

  float lightRadius = 10.0;
  lightPos.x = lightRadius * cos(float(u_Time) * 0.003);
  lightPos.z = lightRadius * sin(float(u_Time) * 0.003);


  float rads = dot(normalize(vertexNormal.xyz),
                   normalize(vec3(vertexPosition - lightPos)));

  bool isNight = true;

  if (rads < 0.0) {
    isNight = false;
  }

  renderPlanet(vertexPosition, vertexNormal, vertexColor, isNight);

  float displacement = 0.0;

  vec3 p = vertexPosition.xyz * 4.0;
  vec3 diff = vec3(float(u_Time) * 0.0001);
  // p += diff;

  // Recursive FBM
  // vec3 q = vec3( fbm( p + vec3(0.0,0.0,0.0) ),
  //                fbm( p + vec3(5.2,1.3,5.7) ),
  //                fbm( p + vec3(2.2,0.7,2.5) ));

  // vec3 r = vec3( fbm( p + 4.0*q + vec3(1.7,9.2,1.4) ),
  //                fbm( p + 4.0*q + vec3(8.3,2.8,2.3) ),
  //                fbm( p + 4.0*q + vec3(7.2,11.8,9.9) ) );

  // float noise = 1.0f - abs(fbm( p + 4.0*r ));

  // float noise = fbm(p);
  // float noise = abs(fbm(p));

  float presM = fbm(vertexPosition.xyz);

  if (presM < 0.3) {
    presM = 0.0;
  } else if (presM > 0.5) {
    presM = 1.0;
  } else {
    presM = (presM - 0.3) / 0.2;
  }

  float noise = mix(0.0, abs(fbm(p)), presM);

  displacement = noise;

  fs_Col = vec4(noise, noise, noise, 1);
  fs_Col = vertexColor;

  vec3 df = calcNormal(vertexPosition.xyz);

  // vertexNormal = vec4(normalize(vertexNormal.xyz - df), 0);
  // vertexPosition += (vertexNormal * (displacement / 3.0));

  mat3 invTranspose = mat3(u_ModelInvTr);
  fs_Nor = vec4(invTranspose * vec3(vertexNormal), 0);

  vec4 modelposition = u_Model * vertexPosition;

  fs_Pos = modelposition;

  fs_LightVec = lightPos - modelposition;

  gl_Position = u_ViewProj * modelposition;
}
