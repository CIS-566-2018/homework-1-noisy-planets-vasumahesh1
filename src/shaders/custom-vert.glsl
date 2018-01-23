#version 300 es

/*----------  Shader Uniforms  ----------*/
uniform mat4 u_Model;
uniform mat4 u_ModelInvTr;
uniform mat4 u_ViewProj;
uniform int u_Time;
uniform vec4 u_Eye;

/*----------  Shader UI Controls  ----------*/
uniform vec3 u_ControlsWaterBedrock1Color;
uniform vec3 u_ControlsWaterBedrock2Color;
uniform vec3 u_ControlsSandColor;
uniform float u_ControlsWaterLevel;
uniform float u_ControlsShoreLevel;
uniform float u_ControlsElevation;
uniform float u_ControlsNoiseScale;

/*----------  Shader Inputs  ----------*/
in vec4 vs_Pos;
in vec4 vs_Nor;
in vec4 vs_Col;

/*----------  Shader Outputs  ----------*/
out vec4 fs_Nor;
out vec4 fs_LightVec;
out vec4 fs_Col;
out vec4 fs_Pos;
out vec4 fs_SphereNor;
out float fs_Spec;
out float fs_Valid;
out float fs_useMatcap;

/*----------  Shader Constants  ----------*/
const float DEGREE_TO_RAD = 0.0174533;
const float RAD_TO_DEGREE = 57.2958;
const float NO_MATCAP = 0.0;
const float NO_SPEC = 0.0;

const float ROCK_MATCAP = 2.0;
const float SNOW_MATCAP = 3.0;
const float GRASS_1_MATCAP = 1.0;
const float GRASS_2_MATCAP = 4.0;

const float SAND_SPECULARITY = 2.0;
const float SNOW_SPECULARITY = 128.0;

/*======================================================
=            FMB with Analytical Derivative            =
======================================================*/
float hash1(float n) { return fract(n * 17.0 * fract(n * 0.3183099)); }

vec4 noised(in vec3 x) {
  vec3 p = floor(x);
  vec3 w = fract(x);

  vec3 u = w * w * w * (w * (w * 6.0 - 15.0) + 10.0);
  vec3 du = 30.0 * w * w * (w * (w - 2.0) + 1.0);

  float n = p.x + 317.0 * p.y + 157.0 * p.z;

  float a = hash1(n + 0.0);
  float b = hash1(n + 1.0);
  float c = hash1(n + 317.0);
  float d = hash1(n + 318.0);
  float e = hash1(n + 157.0);
  float f = hash1(n + 158.0);
  float g = hash1(n + 474.0);
  float h = hash1(n + 475.0);

  float k0 = a;
  float k1 = b - a;
  float k2 = c - a;
  float k3 = e - a;
  float k4 = a - b - c + d;
  float k5 = a - c - e + g;
  float k6 = a - b - e + f;
  float k7 = -a + b + c - d + e - f - g + h;

  return vec4(
      -1.0 + 2.0 * (k0 + k1 * u.x + k2 * u.y + k3 * u.z + k4 * u.x * u.y +
                    k5 * u.y * u.z + k6 * u.z * u.x + k7 * u.x * u.y * u.z),
      2.0 * du *
          vec3(k1 + k4 * u.y + k6 * u.z + k7 * u.y * u.z,
               k2 + k5 * u.z + k4 * u.x + k7 * u.z * u.x,
               k3 + k6 * u.x + k5 * u.y + k7 * u.x * u.y));
}

const mat3 m3 = mat3(0.00, 0.80, 0.60, -0.80, 0.36, -0.48, -0.60, -0.48, 0.64);
const mat3 m3i = mat3(0.00, -0.80, -0.60, 0.80, 0.36, -0.48, 0.60, -0.48, 0.64);

vec4 fbmad(in vec3 x, int octaves) {
  float f = 1.98;
  float s = 0.49;
  float a = 0.0;
  float b = 0.5;
  vec3 d = vec3(0.0);
  mat3 m = mat3(1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0);
  for (int i = 0; i < octaves; i++) {
    vec4 n = noised(x);
    a += b * n.x;
    d += b * m * n.yzw;
    b *= s;
    x = f * m3 * x;
    m = f * m3i * m;
  }
  return vec4(a, d);
}
/*=====  End of FMB with Analytical Derivative  ======*/

/**
 * @brief      Render the Planet's Water
 *
 * @memberof   Custom-water-vert
 *
 * @param[in]  vec4     Vertex Position
 * @param[in]  vec4     Vertex Normal
 * @param[in]  vec4     Vertex Color
 * @param[in]  isNight  Indicates if on night side
 */
void renderPlanet(inout vec4 vertexPosition, inout vec4 vertexNormal,
                  inout vec4 vertexColor, bool isNight) {
  fs_Valid = 0.0;

  /*----------  Uniform Control Variables  ----------*/
  float waterThreshold = u_ControlsWaterLevel - 0.5;
  vec4 bedrockColor1 = vec4(u_ControlsWaterBedrock1Color, 1.0);
  vec4 bedrockColor2 = vec4(u_ControlsWaterBedrock2Color, 1.0);
  vec4 sandColor = vec4(u_ControlsSandColor, 1.0);
  float shoreLevel = (u_ControlsShoreLevel / 0.5) * 0.04;
  float elevation = (0.5 / u_ControlsElevation) * 4.0;
  float noiseScale = (u_ControlsNoiseScale / 0.5) * 3.0;
  /*----------  End  ----------*/

  vec4 originalPosition = vertexPosition;
  vec4 originalNormal = vertexNormal;

  fs_SphereNor = originalNormal;

  vec3 noiseInput = vertexPosition.xyz * noiseScale;
  float deepWaterThreshold = waterThreshold - 0.15;
  float maxScale = 1.0;

  float dist = length(vertexPosition.xyz - u_Eye.xyz);
  int LOD = int(8.0 * (1.0 - smoothstep(0.0, 2.5, log(dist)))) + 4;
  vec4 noiseAd = fbmad(noiseInput, LOD);
  float noise = noiseAd.x;
  vec3 derivative = noiseAd.yzw;

  float originalNoise = noise;

  bool isWater = noise < waterThreshold ? true : false;
  bool isGrass = noise > waterThreshold ? true : false;
  bool isMountains = false;
  bool isCoast = false;

  if (isWater) {
    vertexColor = bedrockColor1;
    vertexNormal = vec4(normalize(vertexNormal.xyz - (noiseAd.yzw * 0.5)), 0);

    if (noise < deepWaterThreshold) {
      vertexColor = bedrockColor2;
    }
  } else {
    fs_Spec = NO_SPEC;
    // Grass 1
    fs_useMatcap = GRASS_1_MATCAP;

    if (noise < waterThreshold + shoreLevel) {
      // Sand
      vertexColor = sandColor;
      fs_Spec = SAND_SPECULARITY;
      isCoast = true;
      fs_useMatcap = NO_MATCAP;
    } else if (noise > waterThreshold + 0.15) {
      // Grass 2
      fs_useMatcap = GRASS_2_MATCAP;
    }
  }

  float landNoise = noise;
  float landHeight = landNoise / elevation;
  vertexPosition = originalPosition + (originalNormal * landHeight);

  vec4 landPosition = vertexPosition;

  if (isGrass) {
    vertexNormal = vec4(normalize(vertexNormal.xyz - (noiseAd.yzw * 0.36)), 0);

    if (landNoise > waterThreshold + 0.3) {
      fs_useMatcap = ROCK_MATCAP;

      float snowAppearance = dot(normalize(derivative), vec3(0, 1, 0));

      vertexNormal =
          vec4(normalize(originalNormal.xyz - (noiseAd.yzw * 0.45)), 0);

      if (landNoise > waterThreshold + 0.4 && snowAppearance > 0.5) {
        fs_useMatcap = SNOW_MATCAP;
        fs_Spec = SNOW_SPECULARITY;
      }
    }
  }
}

void main() {
  vec4 vertexColor;
  vec4 lightPos = vec4(0, 0, 0, 1);
  vec4 vertexPosition = vs_Pos;
  vec4 vertexNormal = vs_Nor;

  fs_useMatcap = NO_MATCAP;

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

  fs_Col = vertexColor;

  mat3 invTranspose = mat3(u_ModelInvTr);
  fs_Nor = vec4(invTranspose * vec3(vertexNormal), 0);

  vec4 modelposition = u_Model * vertexPosition;

  fs_Pos = modelposition;

  fs_LightVec = lightPos - modelposition;

  gl_Position = u_ViewProj * modelposition;
}
