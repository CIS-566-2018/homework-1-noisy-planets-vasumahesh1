#version 300 es

// This is a fragment shader. If you've opened this file first, please
// open and read lambert.vert.glsl before reading on.
// Unlike the vertex shader, the fragment shader actually does compute
// the shading of geometry. For every pixel in your program's output
// screen, the fragment shader is run for every bit of geometry that
// particular pixel overlaps. By implicitly interpolating the position
// data passed into the fragment shader by the vertex shader, the fragment shader
// can compute what color to apply to its pixel based on things like vertex
// position, light position, and vertex color.
precision highp float;

uniform vec4 u_Color; // The color with which to render this instance of geometry.
uniform vec4 u_Eye;
// These are the interpolated values out of the rasterizer, so you can't know
// their specific values without knowing the vertices that contributed to them
in vec4 fs_Nor;
in vec4 fs_LightVec;
in vec4 fs_Col;
in vec4 fs_SphereNor;
in vec4 fs_Pos;
in float fs_Spec;
in float fs_Valid;

out vec4 out_Col; // This is the final output color that you will see on your
                  // screen for the pixel that is currently being processed.


void main()
{
  if (fs_Valid != 0.0) {
    discard;
    return;
  }

  // Debug Normals
  // out_Col = vec4((fs_Nor.xyz + vec3(1.0,1.0,1.0))/2.0, 1.0);

  float lightFactor = dot(normalize(fs_SphereNor.xyz), normalize(fs_LightVec.xyz));

  if (lightFactor < 0.0) {
    lightFactor = 0.0;
  }

  // Material base color (before shading)
  vec4 diffuseColor = fs_Col;

  /*----------  Ambient  ----------*/
  float ambientTerm = 0.2;

  /*----------  Lambertian  ----------*/
  float diffuseTerm = dot(normalize(fs_Nor), normalize(fs_LightVec));
  diffuseTerm = clamp(diffuseTerm, 0.0, 1.0);

  float specularTerm = 0.0;

  if (diffuseTerm > 0.0 && fs_Spec > 0.0) {
    /*----------  Blinn Phong  ----------*/
    vec4 viewVec = u_Eye - fs_Pos;
    vec4 lightVec = fs_LightVec - fs_Pos;

    vec4 H = normalize((viewVec + lightVec) / 2.0f);
    specularTerm = pow(max(0.0, dot(normalize(viewVec), reflect(normalize(fs_LightVec), normalize(fs_Nor)))), fs_Spec);
    // specularTerm = max(pow(dot(H, normalize(fs_Nor)), 128.0), 0.0);
  }

  float lightIntensity = ambientTerm + (diffuseTerm + specularTerm) * lightFactor;
  // lightIntensity = clamp(lightIntensity, 0.0, 1.0);

  vec4 finalColor = vec4(diffuseColor.rgb * lightIntensity, diffuseColor.a);
  finalColor.x = clamp(finalColor.x, 0.0, 1.0);
  finalColor.y = clamp(finalColor.y, 0.0, 1.0);
  finalColor.z = clamp(finalColor.z, 0.0, 1.0);

  out_Col = finalColor;
}
