import { vec4, mat4, vec2 } from 'gl-matrix';
import Drawable from './Drawable';
import { gl } from '../../globals';

var activeProgram: WebGLProgram = null;

export class Shader {
  shader: WebGLShader;

  constructor(type: number, source: string) {
    this.shader = gl.createShader(type);
    gl.shaderSource(this.shader, source);
    gl.compileShader(this.shader);

    if (!gl.getShaderParameter(this.shader, gl.COMPILE_STATUS)) {
      throw gl.getShaderInfoLog(this.shader);
    }
  }
};

class ShaderProgram {
  prog: WebGLProgram;

  attrPos: number;
  attrNor: number;
  attrCol: number;

  unifModel: WebGLUniformLocation;
  unifModelInvTr: WebGLUniformLocation;
  unifViewProj: WebGLUniformLocation;
  unifColor: WebGLUniformLocation;
  unifEye: WebGLUniformLocation;
  unifTime: WebGLUniformLocation;
  unifTexture: WebGLUniformLocation;
  unifTexture1: WebGLUniformLocation;
  unifTexture2: WebGLUniformLocation;
  unifDimensions: WebGLUniformLocation;
  unifInvViewProj: WebGLUniformLocation;

  constructor(shaders: Array<Shader>) {
    this.prog = gl.createProgram();

    for (let shader of shaders) {
      gl.attachShader(this.prog, shader.shader);
    }
    gl.linkProgram(this.prog);
    if (!gl.getProgramParameter(this.prog, gl.LINK_STATUS)) {
      throw gl.getProgramInfoLog(this.prog);
    }

    this.attrPos = gl.getAttribLocation(this.prog, "vs_Pos");
    this.attrNor = gl.getAttribLocation(this.prog, "vs_Nor");
    this.attrCol = gl.getAttribLocation(this.prog, "vs_Col");
    this.unifModel = gl.getUniformLocation(this.prog, "u_Model");
    this.unifModelInvTr = gl.getUniformLocation(this.prog, "u_ModelInvTr");
    this.unifViewProj = gl.getUniformLocation(this.prog, "u_ViewProj");
    this.unifInvViewProj = gl.getUniformLocation(this.prog, "u_InvViewProj");
    this.unifColor = gl.getUniformLocation(this.prog, "u_Color");
    this.unifEye = gl.getUniformLocation(this.prog, "u_Eye");
    this.unifTime = gl.getUniformLocation(this.prog, "u_Time");
    this.unifTexture = gl.getUniformLocation(this.prog, "u_Texture");
    this.unifTexture1 = gl.getUniformLocation(this.prog, "u_Texture1");
    this.unifTexture2 = gl.getUniformLocation(this.prog, "u_Texture2");
    this.unifDimensions = gl.getUniformLocation(this.prog, "u_Dimensions");
  }

  use() {
    if (activeProgram !== this.prog) {
      gl.useProgram(this.prog);
      activeProgram = this.prog;
    }
  }

  /**
   * @brief      Sets the model matrix.
   *
   * @memberof   ShaderProgram
   *
   * @param      model  The model matrix
   *
   */
  setModelMatrix(model: mat4) {
    this.use();
    if (this.unifModel !== -1) {
      gl.uniformMatrix4fv(this.unifModel, false, model);
    }

    if (this.unifModelInvTr !== -1) {
      let modelinvtr: mat4 = mat4.create();
      mat4.transpose(modelinvtr, model);
      mat4.invert(modelinvtr, modelinvtr);
      gl.uniformMatrix4fv(this.unifModelInvTr, false, modelinvtr);
    }
  }

  /**
   * @brief      Sets the view projection matrix.
   *
   * @memberof   ShaderProgram
   *
   * @param      vp    view projection matrix
   *
   */
  setViewProjMatrix(vp: mat4) {
    this.use();
    if (this.unifViewProj !== -1) {
      gl.uniformMatrix4fv(this.unifViewProj, false, vp);
    }
  }

  /**
   * @brief      Sets the inverse view projection matrix.
   *
   * @memberof   ShaderProgram
   *
   * @param      ivp    view projection matrix
   *
   */
  setInvViewProjMatrix(ivp: mat4) {
    this.use();
    if (this.unifInvViewProj !== -1) {
      gl.uniformMatrix4fv(this.unifInvViewProj, false, ivp);
    }
  }

  /**
   * @brief      Sets the inverse view projection matrix.
   *
   * @memberof   ShaderProgram
   *
   * @param      ivp    view projection matrix
   *
   */
  setScreenDimensions(dimensions: vec2) {
    this.use();
    if (this.unifDimensions !== -1) {
      gl.uniform2i(this.unifDimensions, dimensions[0], dimensions[1]);
    }
  }

  /**
   * @brief      Sets the uniform geometry color.
   *
   * @memberof   ShaderProgram
   *
   * @param      color  The color
   *
   */
  setGeometryColor(color: vec4) {
    this.use();
    if (this.unifColor !== -1) {
      gl.uniform4fv(this.unifColor, color);
    }
  }

  /**
   * @brief      Sets the camera eye position.
   *
   * @memberof   ShaderProgram
   *
   * @param      pos   The position
   *
   */
  setEyePosition(pos: vec4) {
    this.use();
    if (this.unifEye !== -1) {
      gl.uniform4fv(this.unifEye, pos);
    }
  }

  /**
   * @brief      Sets the time (actually frame counter).
   *
   * @memberof   ShaderProgram
   *
   * @param      time  The time
   *
   */
  setTime(time: number) {
    this.use();
    if (this.unifTime !== -1) {
      gl.uniform1i(this.unifTime, time);
    }
  }

  /**
   * @brief      Sets the texture slot 0 to the uniform variable.
   *
   * @memberof   ShaderProgram
   *
   */
  setTexture(slot: number) {
    this.use();
    if (this.unifTexture !== -1 && slot == 0) {
      gl.uniform1i(this.unifTexture, 0);
    } else if (this.unifTexture1 !== -1 && slot == 1) {
      gl.uniform1i(this.unifTexture1, 1);
    }  else if (this.unifTexture2 !== -1 && slot == 2) {
      gl.uniform1i(this.unifTexture2, 2);
    }
  }

  /**
   * @brief      Draw the sent drawable
   *
   * @memberof   ShaderProgram
   *
   * @param      d     Drawable
   *
   */
  draw(d: Drawable) {
    this.use();

    if (this.attrPos != -1 && d.bindPos()) {
      gl.enableVertexAttribArray(this.attrPos);
      gl.vertexAttribPointer(this.attrPos, 4, gl.FLOAT, false, 0, 0);
    }

    if (this.attrNor != -1 && d.bindNor()) {
      gl.enableVertexAttribArray(this.attrNor);
      gl.vertexAttribPointer(this.attrNor, 4, gl.FLOAT, false, 0, 0);
    }

    d.bindIdx();
    gl.drawElements(d.drawMode(), d.elemCount(), gl.UNSIGNED_INT, 0);

    if (this.attrPos != -1) gl.disableVertexAttribArray(this.attrPos);
    if (this.attrNor != -1) gl.disableVertexAttribArray(this.attrNor);
  }
};

export default ShaderProgram;
