class WebGLRenderer {
    meshes = [];
    shadowMeshes = [];
    lights = [];

    constructor(gl, camera) {
        this.gl = gl;
        this.camera = camera;
    }

    addLight(light) {
        this.lights.push({
            entity: light,
            meshRender: new MeshRender(this.gl, light.mesh, light.mat)
        });
    }
    addMeshRender(mesh) { this.meshes.push(mesh); }
    addShadowMeshRender(mesh) { this.shadowMeshes.push(mesh); }

    render() {
        const gl = this.gl;

        gl.clearColor(0.0, 0.0, 0.0, 1.0); // Clear to black, fully opaque
        gl.clearDepth(1.0); // Clear everything
        gl.enable(gl.DEPTH_TEST); // Enable depth testing
        gl.depthFunc(gl.LEQUAL); // Near things obscure far things

        console.assert(this.lights.length != 0, "No light");
        console.assert(this.lights.length == 1, "Multiple lights");

        // const timer = Date.now() * 0.00005;
        // let lightPos = [ Math.sin(timer * 6) * 30, 
        //                  (Math.cos(timer * 4) + 1.0) * 50, 
        //                  (Math.cos(timer * 2) + 1.0) * 20 ];


        for (let l = 0; l < this.lights.length; l++) {
            // Draw light
            // TODO: Support all kinds of transform
            // this.lights[l].entity.lightPos = lightPos;
            this.lights[l].meshRender.mesh.transform.translate = this.lights[l].entity.lightPos;
            this.lights[l].meshRender.draw(this.camera);

            // clear render target
            for (let i = 0; i < this.shadowMeshes.length; i++) {
                this.shadowMeshes[i].clear();
                break;
            }

            // Shadow pass
            if (this.lights[l].entity.hasShadowMap == true) {
                for (let i = 0; i < this.shadowMeshes.length; i++) {
                    let mesh = this.shadowMeshes[i];
                    mesh.material.uniforms.uLightVP.value = this.lights[l].entity.CalcLightVP();
                    mesh.draw(this.camera);
                }
            }

            // Camera pass
            for (let i = 0; i < this.meshes.length; i++) {
                let mesh = this.meshes[i];
                mesh.material.uniforms.uLightVP.value = this.lights[l].entity.CalcLightVP();
                this.gl.useProgram(this.meshes[i].shader.program.glShaderProgram);
                this.gl.uniform3fv(this.meshes[i].shader.program.uniforms.uLightPos, this.lights[l].entity.lightPos);
                this.meshes[i].draw(this.camera);
            }
        }
    }
}