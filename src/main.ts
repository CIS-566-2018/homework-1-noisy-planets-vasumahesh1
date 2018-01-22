import { vec3, vec4 } from 'gl-matrix';
import * as Stats from 'stats-js';
import * as DAT from 'dat-gui';
import Icosphere from './geometry/Icosphere';
import Square from './geometry/Square';
import Cube from './geometry/Cube';
import Sky from './geometry/Sky';
import OpenGLRenderer from './rendering/gl/OpenGLRenderer';
import Texture from './rendering/gl/Texture';
import Camera from './Camera';
import { setGL } from './globals';
import ShaderProgram, { Shader } from './rendering/gl/ShaderProgram';

// Define an object with application parameters and button callbacks
// This will be referred to by dat.GUI's functions that add GUI elements.
let controls = {
  tesselations: 9,
  loadPlanetSceneButton: loadPlanetScene,
  loadTestSceneButton: loadTestScene,
  saveImage: saveImage,
  geometryColor: [255, 0, 0]
};

let icosphere: Icosphere;
let square: Square;
let cube: Cube;
let sky: Sky;

let activeShader: ShaderProgram;
let planetShader: ShaderProgram;
let testShader: ShaderProgram;
let skyShader: ShaderProgram;
let waterShader: ShaderProgram;

let shaderMode: number = 0;
let frameCount: number = 0;

let shouldCapture: boolean = false;

let masterBallTexture: Texture;

/**
 * @brief      Loads the pokeball scene.
 */
function loadPlanetScene() {
  activeShader = planetShader;
  shaderMode = 0;
  frameCount = 0;
}


function loadTestScene() {
  activeShader = testShader;
  shaderMode = 0;
  frameCount = 0;
}

/**
 * @brief      Loads the geometry assets
 */
function loadAssets() {
  icosphere = new Icosphere(vec3.fromValues(0, 0, 0), 1, controls.tesselations);
  icosphere.create();

  square = new Square(vec3.fromValues(0, 0, 0));
  square.create();

  cube = new Cube(vec3.fromValues(0, 0, 0));
  cube.create();

  sky = new Sky(vec3.fromValues(0, 0, 0));
  sky.create();
}

function saveImage() {
  shouldCapture = true;
};

function downloadImage() {
  // Dump the canvas contents to a file.
  var canvas = <HTMLCanvasElement>document.getElementById("canvas");
  canvas.toBlob(function(blob) {
    var link = document.createElement("a");
    link.download = "image.png";

    link.href = URL.createObjectURL(blob);
    console.log(blob);

    link.click();

  }, 'image/png');
}

/**
 * @brief      Main execution code
 *
 * @memberof   Main
 */
function main() {
  // Initial display for framerate
  const stats = Stats();
  stats.setMode(0);
  stats.domElement.style.position = 'absolute';
  stats.domElement.style.left = '0px';
  stats.domElement.style.top = '0px';
  document.body.appendChild(stats.domElement);

  // Add controls to the gui
  const gui = new DAT.GUI();
  gui.add(controls, 'tesselations', 0, 8).step(1);
  gui.add(controls, 'loadPlanetSceneButton').name('Load Planet Scene');
  gui.add(controls, 'loadTestSceneButton').name('Load Test Scene');
  gui.add(controls, 'saveImage').name('Save Image');
  gui.addColor(controls, 'geometryColor');

  // get canvas and webgl context
  const canvas = <HTMLCanvasElement>document.getElementById('canvas');
  const gl = <WebGL2RenderingContext>canvas.getContext('webgl2');
  if (!gl) {
    alert('WebGL 2 not supported!');
  }
  // `setGL` is a function imported above which sets the value of `gl` in the `globals.ts` module.
  // Later, we can import `gl` from `globals.ts` to access it
  setGL(gl);

  // Initial call to load scene

  const camera = new Camera(vec3.fromValues(0, 0, 5), vec3.fromValues(0, 0, 0));

  const renderer = new OpenGLRenderer(canvas);
  renderer.setClearColor(0.05, 0.05, 0.05, 1);
  gl.enable(gl.DEPTH_TEST);

  planetShader = new ShaderProgram([
    new Shader(gl.VERTEX_SHADER, require('./shaders/custom-vert.glsl')),
    new Shader(gl.FRAGMENT_SHADER, require('./shaders/custom-frag.glsl')),
  ]);

  testShader = new ShaderProgram([
    new Shader(gl.VERTEX_SHADER, require('./shaders/test-vert.glsl')),
    new Shader(gl.FRAGMENT_SHADER, require('./shaders/custom-frag.glsl')),
  ]);

  skyShader = new ShaderProgram([
    new Shader(gl.VERTEX_SHADER, require('./shaders/sky-vert.glsl')),
    new Shader(gl.FRAGMENT_SHADER, require('./shaders/sky-frag.glsl')),
  ]);

  waterShader = new ShaderProgram([
    new Shader(gl.VERTEX_SHADER, require('./shaders/custom-water-vert.glsl')),
    new Shader(gl.FRAGMENT_SHADER, require('./shaders/custom-frag.glsl')),
  ]);

  gl.enable(gl.BLEND);
  gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

  masterBallTexture = new Texture('./src/textures/masterball_m.png');

  loadAssets();
  loadPlanetScene();

  // This function will be called every frame
  function tick() {
    camera.update();
    let position = camera.getPosition();
    stats.begin();
    gl.viewport(0, 0, window.innerWidth, window.innerHeight);
    renderer.clear();

    gl.disable(gl.DEPTH_TEST);

    skyShader.setTime(frameCount);
    skyShader.setEyePosition(vec4.fromValues(position[0], position[1], position[2], 1));
    renderer.render(camera, skyShader, [sky]);

    gl.enable(gl.DEPTH_TEST);

    activeShader.setTime(frameCount);
    activeShader.setEyePosition(vec4.fromValues(position[0], position[1], position[2], 1));
    renderer.setGeometryColor(
      vec4.fromValues(
        controls.geometryColor[0] / 255,
        controls.geometryColor[1] / 255,
        controls.geometryColor[2] / 255,
        1.0
      )
    );

    waterShader.setTime(frameCount);
    waterShader.setEyePosition(vec4.fromValues(position[0], position[1], position[2], 1));

    switch (shaderMode) {
      case 0:
        activeShader.setEyePosition(vec4.fromValues(position[0], position[1], position[2], 1));
        renderer.render(camera, activeShader, [icosphere]);
        renderer.render(camera, waterShader, [icosphere]);
        break;

      default:
        renderer.render(camera, activeShader, [cube]);
        break;
    }

    frameCount++;

    stats.end();

    if (shouldCapture) {
      downloadImage();
      shouldCapture = false;
    }

    // Tell the browser to call `tick` again whenever it renders a new frame
    requestAnimationFrame(tick);
  }

  window.addEventListener('resize', function() {
    renderer.setSize(window.innerWidth, window.innerHeight);
    camera.setAspectRatio(window.innerWidth / window.innerHeight);
    camera.updateProjectionMatrix();
  }, false);

  renderer.setSize(window.innerWidth, window.innerHeight);
  camera.setAspectRatio(window.innerWidth / window.innerHeight);
  camera.updateProjectionMatrix();

  // Start the render loop
  tick();
}

main();
