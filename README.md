# Unity-Post-Process-Compute-VR
A ***W.I.P*** template for a compute shader based post processing effect designed for VR *(and non-vr) using the Unity Post Processing Stack.

This is a basic template effect that is a single pass, and works with the 3 built-in camera textures *(Depth, DepthNormals, MotionVector)* all calculated and sampled correctly. No other additional things are done, it's just a simple template for a compute based post process shader.

![post-process](GithubContent/post-process.png)

#### Original Scene: 
![original-scene](GithubContent/original-scene.png)

#### UVs (Default)
![1-uv-default](GithubContent/1-uv-default.png)

#### Raw "_CameraDepthTexture"
![2-raw-depth-texture](GithubContent/2-raw-depth-texture.png)

#### Raw "_CameraDepthNormalsTexture"
![3-raw-depth-normals-texture](GithubContent/3-raw-depth-normals-texture.png)

#### Raw "_CameraMotionVectorsTexture"
![4-raw-motion-vectors-texture](GithubContent/4-raw-motion-vectors-texture.png)

#### Linear Eye Depth
![5-linear-eye-depth](GithubContent/5-linear-eye-depth.png)

#### Linear 01 Depth
![6-linear-01-depth](GithubContent/6-linear-01-depth.png)

#### View Normals
![7-view-normals](GithubContent/7-view-normals.png)

#### World Normals
![8-world-normals](GithubContent/8-world-normals.png)

#### View Position
![9-view-position](GithubContent/9-view-position.png)

#### World Position
![10-world-position](GithubContent/10-world-position.png)