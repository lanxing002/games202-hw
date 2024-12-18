class DirectionalLight {

    constructor(lightIntensity, lightColor, lightPos, focalPoint, lightUp, hasShadowMap, gl) {
        this.mesh = Mesh.cube(setTransform(0, 0, 0, 0.2, 0.2, 0.2, 0));
        this.mat = new EmissiveMaterial(lightIntensity, lightColor);
        this.lightPos = lightPos;
        this.focalPoint = focalPoint;
        this.lightUp = lightUp

        this.hasShadowMap = hasShadowMap;
        this.fbo = new FBO(gl);
        if (!this.fbo) {
            console.log("无法设置帧缓冲区对象");
            return;
        }
    }


    CalcLightVP() {
        let vpMat = mat4.create();
        let viewMatrix = mat4.create();
        let projectionMatrix = mat4.create();

        // View transform
        let c = new THREE.PerspectiveCamera(80.0, 1.0, 1.0, 800.0)
        c.updateProjectionMatrix();
        mat4.copy(projectionMatrix, c.projectionMatrix.elements);
        mat4.ortho(projectionMatrix, -150, 150, -150, 150, 1, 1200);

        mat4.lookAt(viewMatrix, this.lightPos, this.focalPoint, this.lightUp);
        mat4.multiply(vpMat, projectionMatrix, viewMatrix);

        return vpMat;
    }

    CalcLightMVP(translate, scale) {
        let lightMVP = mat4.create();
        let modelMatrix = mat4.create();
        let vp = this.CalcLightVP();

        mat4.translate(modelMatrix, modelMatrix, translate);
        mat4.scale(modelMatrix, modelMatrix, scale);
        mat4.multiply(lightMVP, vp, modelMatrix);
        return lightMVP;
    }
}
