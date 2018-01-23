#version 300 es

/*----------  Shader Uniforms  ----------*/
uniform mat4 u_Model;
uniform mat4 u_ModelInvTr;
uniform mat4 u_ViewProj;
uniform int u_Time;

/*----------  Shader UI Controls  ----------*/
uniform vec3 u_ControlsWaterColor;
uniform float u_ControlsWaterOpacity;
uniform float u_ControlsWaterLevel;
uniform float u_ControlsElevation;
uniform float u_ControlsNoiseScale;

/*----------  Shader Input  ----------*/
in vec4 vs_Pos;
in vec4 vs_Nor;
in vec4 vs_Col;

/*----------  Shader Output  ----------*/
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

// FBM with Analytical Derivative
vec4 fbmad(in vec3 x, int octaves) {
  float f = 1.98;  // could be 2.0
  float s = 0.49;  // could be 0.5
  float a = 0.0;
  float b = 0.5;
  vec3 d = vec3(0.0);
  mat3 m = mat3(1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0);
  for (int i = 0; i < octaves; i++) {
    vec4 n = noised(x);
    a += b * n.x;        // accumulate values
    d += b * m * n.yzw;  // accumulate derivatives
    b *= s;
    x = f * m3 * x;
    m = f * m3i * m;
  }
  return vec4(a, d);
}
/*=====  End of FMB with Analytical Derivative  ======*/

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
  vec4 waterColor = vec4(u_ControlsWaterColor, u_ControlsWaterOpacity);
  float noiseScale = (u_ControlsNoiseScale / 0.5) * 3.0;

  vertexColor = waterColor;

  fs_Valid = 1.0;

  vec4 originalPosition = vertexPosition;
  vec4 originalNormal = vertexNormal;

  fs_SphereNor = originalNormal;

  vec3 noiseInput = vertexPosition.xyz * noiseScale;

  float waterThreshold = u_ControlsWaterLevel - 0.5;

  vec4 noiseAd = fbmad(noiseInput, 8);
  float noise = noiseAd.x;

  bool isWater = noise < waterThreshold ? true : false;

  if (isWater) {
    fs_Spec = 256.0;

    fs_Valid = 0.0;

    float elevation = (0.5 / u_ControlsElevation) * 4.0;

    float landHeight = waterThreshold / elevation;
    vertexPosition = originalPosition + (originalNormal * landHeight);

    noiseInput = vertexPosition.xyz * 3.0 + vec3(float(u_Time) * 0.0008);
    vec4 noiseWaves = fbmad(noiseInput, 8);

    vertexNormal =
        vec4(normalize(vertexNormal.xyz - (noiseWaves.yzw * 0.3)), 0);
  }
}

void main() {
  vec4 vertexColor;
  vec4 lightPos = vec4(0, 0, 15, 1);

  vec4 vertexPosition = vs_Pos;
  vec4 vertexNormal = vs_Nor;
  fs_useMatcap = 0.0;

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
  fs_SphereNor = vec4(invTranspose * vec3(fs_SphereNor), 0);

  vec4 modelposition = u_Model * vertexPosition;

  fs_Pos = modelposition;

  fs_LightVec = lightPos - modelposition;

  gl_Position = u_ViewProj * modelposition;
}
