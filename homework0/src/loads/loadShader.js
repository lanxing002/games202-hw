
function loadShaderFile(filename) {

    return new Promise((resolve, reject) => {
        console.log('=================================================')
        const loader = new THREE.FileLoader();
        loader.load(filename, (data) => {
            resolve(data);
            console.log(data);
        });
    });
}
