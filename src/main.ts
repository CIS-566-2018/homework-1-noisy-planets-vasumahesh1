import { vec3, vec4, mat4 } from 'gl-matrix';
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
import { ShaderControls, WaterControls } from './rendering/gl/ShaderControls';
import ShaderProgram, { Shader } from './rendering/gl/ShaderProgram';

// Define an object with application parameters and button callbacks
// This will be referred to by dat.GUI's functions that add GUI elements.
let controls = {
  tesselations: 9,
  loadPlanetSceneButton: loadPlanetScene,
  loadRedPlanetSceneButton: loadRedPlanetScene,
  saveImage: saveImage,
  geometryColor: [255, 0, 0],

  waterControls: {
    opacity: 0.65
  }
};

let prevTime: number;
let degreePerMS: number = -5.0 / 1000.0;

let icosphere: Icosphere;
let square: Square;
let cube: Cube;
let sky: Sky;

let shaderControls: ShaderControls;

let activeShader: ShaderProgram;
let planetShader: ShaderProgram;
let testShader: ShaderProgram;
let skyShader: ShaderProgram;
let waterShader: ShaderProgram;

let shaderMode: number = 0;
let frameCount: number = 0;

let shouldCapture: boolean = false;

let grassTexture: Texture;
let grassDarkTexture: Texture;
let mountainTexture: Texture;
let snowTexture: Texture;

/**
 * @brief      Loads the pokeball scene.
 */
function loadPlanetScene() {
  activeShader = planetShader;
  shaderMode = 0;
  frameCount = 0;

  shaderControls.reset();

  grassTexture = new Texture('./src/textures/planet1/foliage.png');
  grassDarkTexture = new Texture('./src/textures/planet1/foliage_dark.png');
  mountainTexture = new Texture('./src/textures/planet1/mountain.jpg');
  snowTexture = new Texture('./src/textures/planet1/snow.png');

  mat4.identity(icosphere.modelMatrix);
}

function loadRedPlanetScene() {
  shaderControls.reset();
  grassTexture = new Texture('./src/textures/planet2/soil.png');
  grassDarkTexture = new Texture('./src/textures/planet2/soil.png');
  mountainTexture = new Texture('./src/textures/planet2/mountain.jpg');
  snowTexture = new Texture('./src/textures/planet2/snow.jpg');

  shaderControls.waterControls.opacity = 0.95;
  shaderControls.waterControls.level = 0.42;
  shaderControls.waterControls.color = [193.0, 0.0, 1.0];
  shaderControls.sandColor = [64.0, 33.0, 16.0];
  shaderControls.elevation = 1.23;
  shaderControls.shoreLevel = 0.37;
  shaderControls.noiseScale = 0.81;

  mat4.identity(icosphere.modelMatrix);
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

function constructGUI() {
  // Add controls to the gui
  const gui = new DAT.GUI();
  gui.add(controls, 'loadPlanetSceneButton').name('Load Planet Scene');
  gui.add(controls, 'loadRedPlanetSceneButton').name('Load Red Planet Scene');
  gui.add(controls, 'saveImage').name('Save Image');

  let group = gui.addFolder('Water Controls');
  group.add(shaderControls.waterControls, 'opacity', 0, 1).step(0.05).name('Water Opacity').listen();
  group.add(shaderControls.waterControls, 'level', 0, 1).step(0.01).name('Water Level').listen();
  group.addColor(shaderControls.waterControls, 'color').name('Water Color').listen();
  group.addColor(shaderControls, 'bedrock1Color').name('Water Bedrock 1 Color').listen();
  group.addColor(shaderControls, 'bedrock2Color').name('Water Bedrock 2 Color').listen();

  group = gui.addFolder('Terrain Controls');
  group.addColor(shaderControls, 'sandColor').name('Shore Color').listen();
  group.add(shaderControls, 'shoreLevel', 0, 1).step(0.01).name('Shore Level').listen();
  group.add(shaderControls, 'elevation', 0.1, 2.0).step(0.01).name('Terrain Elevation').listen();
  group.add(shaderControls, 'noiseScale', 0.1, 2.0).step(0.01).name('Terrain Noise Scale').listen();
}

/**
 * @brief      Main execution code
 *
 * @memberof   Main
 */
function main() {
  shaderControls = new ShaderControls();

  // Initial display for framerate
  const stats = Stats();
  stats.setMode(0);
  stats.domElement.style.position = 'absolute';
  stats.domElement.style.left = '0px';
  stats.domElement.style.top = '0px';
  document.body.appendChild(stats.domElement);

  constructGUI();

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

  loadAssets();
  loadPlanetScene();

  // This function will be called every frame
  function tick() {
    let deltaTime = (new Date()).getTime() - prevTime;

    let degrees = deltaTime * degreePerMS;

    let rotDelta = mat4.create();

    mat4.fromRotation(rotDelta, degrees * 0.0174533, vec3.fromValues(0, 1, 0));
    mat4.multiply(icosphere.modelMatrix, icosphere.modelMatrix, rotDelta);

    camera.update();
    let position = camera.getPosition();
    stats.begin();
    gl.viewport(0, 0, window.innerWidth, window.innerHeight);
    renderer.clear();

    // shaderControls.waterControls.opacity = controls.waterControls.opacity;

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

    activeShader.setControlValues(shaderControls);
    waterShader.setControlValues(shaderControls);

    grassTexture.bind(0);
    activeShader.setTexture(0);

    mountainTexture.bind(1);
    activeShader.setTexture(1);

    snowTexture.bind(2);
    activeShader.setTexture(2);

    grassDarkTexture.bind(3);
    activeShader.setTexture(3);

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

    prevTime = (new Date()).getTime();

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
  prevTime = (new Date()).getTime();
  tick();
}

main();
