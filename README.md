# Unity Shader Templates
A ***W.I.P*** project containing various shader templates designed for VR *(and non-vr)*.

## Object Shader
***Work In Progress***

## Object "Post Process" Shader
An object-based shader that can be used to do post-processing without blitting to a render target *(VRChat-like case where functionality is limited)*.

This is a bit of a complex shader but it. It works with the 3 built-in camera textures *(Depth, DepthNormals, MotionVector)* 
- **Raw Camera Depth Texture**
- **Raw Camera Depth Normals Texture**
- **Raw Camera Motion Vectors**
- **Linear Eye Depth**
- **Linear 01 Depth**
- **View Normals**
- **World Normals**
- **View Position**
- **World Position**

## Post Processing Shader
*Based on the Unity Post Processing Stack.*

This is a single-pass effect. It works with the 3 built-in camera textures *(Depth, DepthNormals, MotionVector)* and uses them to calculate buffers you often might need: 
- **Raw Camera Depth Texture**
- **Raw Camera Depth Normals Texture**
- **Raw Camera Motion Vectors**
- **Linear Eye Depth**
- **Linear 01 Depth**
- **View Normals**
- **World Normals**
- **View Position**
- **World Position**

## Compute Based Post Processing Shader
*Based on the Unity Post Processing Stack.*

This is a single-pass effect, identical to the regular post-process variant. It works with the 3 built-in camera textures *(Depth, DepthNormals, MotionVector)* and uses them to calculate buffers you often might need: 
- **Raw Camera Depth Texture**
- **Raw Camera Depth Normals Texture**
- **Raw Camera Motion Vectors**
- **Linear Eye Depth**
- **Linear 01 Depth**
- **View Normals**
- **World Normals**
- **View Position**
- **World Position**

### Additional Notes

### Linear Eye Depth 
This is calculated by using depth from _CameraDepthTexture. It can also be calculated by using depth unpacked from _CameraDepthNormalsTexture.

### Linear 01 Depth
This is calculated by using depth from _CameraDepthTexture. It can also be calculated by using depth unpacked from _CameraDepthNormalsTexture.

### View Normals
This is calculated by unpacking view normals from _CameraDepthNormalsTexture. It can also be calculated by generating normals from depth, although there is a caveat to that. 

Generating normals from depth will not retain any normal information on meshes, and therefore polygons that are supposed to appear "smooth" will not appear as such because we are essentially only working with position. With that said it's still a viable solution. 

Depth is sampled either from the _CameraDepthTexture, or unpacked from _CameraDepthNormalsTexture *(Although this has issues at the moment for normals due to lack of precision)*. With the given depth, normals can be generated with different techniques that are implemented. 
- **"1 Tap Quad Intrinsics"** which calculates normals by sampling one depth texture, and using quad intrinsics to read the difference in depth values within a 2x2 pixel block to generate normals.
- **"3 Tap"** which calculates normals by sampling three depth textures to generate normals.
- **"4 Tap"** which calculates normals by sampling four depth textures to generate normals.
- **"Improved"** which calculates normals by sampling four depth textures to generate normals.
- **"Accurate"** which calculates normals by sampling 14 depth textures to generate normals.

### World Normals
Does the same as View Normals except transforms them into world space.

### View Position
Is calculated with depth from _CameraDepthTexture, or depth unpacked from _CameraDepthNormalsTexture.

### World Position
Is calculated with depth from _CameraDepthTexture, or depth unpacked from _CameraDepthNormalsTexture.

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
