# Unity Shader Templates
A ***W.I.P*** project containing various shader templates designed for VR *(and non-vr)*.

### Object Shader
***Work In Progress***

### Object "Post Process" Shader
An object-based shader that can be used to do post-processing without blitting to a render target *(VRChat-like case where functionality is limited)*.

This is a bit of a complex shader but it. It works with the 3 built-in camera textures *(Depth, DepthNormals, MotionVector)* 
- **Raw Camera Depth Texture**
- **Raw Camera Depth Normals Texture**
- **Raw Camera Motion Vectors**
- **Linear Eye Depth:** *(Depth from _CameraDepthTexture, or depth unpacked from _CameraDepthNormalsTexture)*
- **Linear 01 Depth:** *(Depth from _CameraDepthTexture, or depth unpacked from _CameraDepthNormalsTexture)*
- **View Normals:** *(Normals unpacked from _CameraDepthNormalsTexture, normals calculated from _CameraDepthTexture)*
- **World Normals:** *(Normals unpacked from _CameraDepthNormalsTexture, normals calculated from _CameraDepthTexture)*
- **View Position:** *(Calculated with depth from _CameraDepthTexture, or depth unpacked from _CameraDepthNormalsTexture)*
- **World Position:** *(Calculated with depth from _CameraDepthTexture, or depth unpacked from _CameraDepthNormalsTexture)*

### Post Processing Shader
*Based on the Unity Post Processing Stack.*

This is a single-pass effect. It works with the 3 built-in camera textures *(Depth, DepthNormals, MotionVector)* and uses them to calculate buffers you often might need: 
- **Raw Camera Depth Texture**
- **Raw Camera Depth Normals Texture**
- **Raw Camera Motion Vectors**
- **Linear Eye Depth:** *(Depth from _CameraDepthTexture, or depth unpacked from _CameraDepthNormalsTexture)*
- **Linear 01 Depth:** *(Depth from _CameraDepthTexture, or depth unpacked from _CameraDepthNormalsTexture)*
- **View Normals:** *(Normals unpacked from _CameraDepthNormalsTexture, normals calculated from _CameraDepthTexture)*
- **World Normals:** *(Normals unpacked from _CameraDepthNormalsTexture, normals calculated from _CameraDepthTexture)*
- **View Position:** *(Calculated with depth from _CameraDepthTexture, or depth unpacked from _CameraDepthNormalsTexture)*
- **World Position:** *(Calculated with depth from _CameraDepthTexture, or depth unpacked from _CameraDepthNormalsTexture)*

### Compute Based Post Processing Shader
*Based on the Unity Post Processing Stack.*

This is a single-pass effect, identical to the regular post-process variant. It works with the 3 built-in camera textures *(Depth, DepthNormals, MotionVector)* and uses them to calculate buffers you often might need: 
- **Raw Camera Depth Texture**
- **Raw Camera Depth Normals Texture**
- **Raw Camera Motion Vectors**
- **Linear Eye Depth:** *(Depth from _CameraDepthTexture, or depth unpacked from _CameraDepthNormalsTexture)*
- **Linear 01 Depth:** *(Depth from _CameraDepthTexture, or depth unpacked from _CameraDepthNormalsTexture)*
- **View Normals:** *(Normals unpacked from _CameraDepthNormalsTexture, normals calculated from _CameraDepthTexture)*
- **World Normals:** *(Normals unpacked from _CameraDepthNormalsTexture, normals calculated from _CameraDepthTexture)*
- **View Position:** *(Calculated with depth from _CameraDepthTexture, or depth unpacked from _CameraDepthNormalsTexture)*
- **World Position:** *(Calculated with depth from _CameraDepthTexture, or depth unpacked from _CameraDepthNormalsTexture)*

# Screenshots

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
