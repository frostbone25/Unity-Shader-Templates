Shader "Unlit/ObjectShaderTemplate"
{
    Properties
    {
        [Header(Rendering)]
        [Enum(UnityEngine.Rendering.CullMode)] _CullMode("Cull Mode", Int) = 2

        //https://docs.unity3d.com/Manual/SL-ZWrite.html
        //Sets whether the depth buffer contents are updated during rendering.
        //Normally, ZWrite is enabled for opaque objects and disabled for semi - transparent ones.
        [ToggleUI] _ZWrite("ZWrite", Float) = 1

        //https://docs.unity3d.com/Manual/SL-ZTest.html
        // 0 - Disabled:
        // 1 - Never:
        // 2 - Less: Draw geometry that is in front of existing geometry.Do not draw geometry that is at the same distance as or behind existing geometry.
        // 3 - LEqual: Draw geometry that is in front of or at the same distance as existing geometry.Do not draw geometry that is behind existing geometry. (This is the default value)
        // 4 - Equal: Draw geometry that is at the same distance as existing geometry.Do not draw geometry that is in front of or behind existing geometry.
        // 5 - GEqual: Draw geometry that is behind or at the same distance as existing geometry.Do not draw geometry that is in front of existing geometry.
        // 6 - Greater: Draw geometry that is behind existing geometry.Do not draw geometry that is at the same distance as or in front of existing geometry.
        // 7 - NotEqual: Draw geometry that is not at the same distance as existing geometry.Do not draw geometry that is at the same distance as existing geometry.
        // 8 - Always: No depth testing occurs. Draw all geometry, regardless of distance.
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("ZTest", Float) = 4

        [Header(Color)]
        [MainColor] _Color("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo", 2D) = "white" {}

        [Header(Normal)]
        [Toggle(_NORMALMAP)] _EnableBumpMap("Enable Bump Map", Float) = 1
        _NormalStrength("Normal Strength", Float) = 1
        [Normal] _BumpMap("Normal Map", 2D) = "bump" {}

        [Header(Reflections)]
        _Smoothness("Smoothness", Range(0, 1)) = 0.75
        _ReflectionIntensity("Reflection Intensity", Range(0, 1)) = 0.25
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
        }

        Cull[_CullMode]
        ZWrite[_ZWrite]
        ZTest[_ZTest]

        Pass
        {
            Name "ObjectShaderTemplate_ForwardBase"

            Tags
            {
                "LightMode" = "ForwardBase"
            }

            CGPROGRAM
            #pragma vertex vertex_forward_base
            #pragma fragment fragment_forward_base

            //||||||||||||||||||||||||||||| UNITY3D KEYWORDS |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| UNITY3D KEYWORDS |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| UNITY3D KEYWORDS |||||||||||||||||||||||||||||

            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog
            #pragma multi_compile_instancing

            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ UNITY_LIGHTMAP_FULL_HDR
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ UNITY_SPECCUBE_BOX_PROJECTION
            #pragma multi_compile _ UNITY_LIGHT_PROBE_PROXY_VOLUME 

            //||||||||||||||||||||||||||||| CUSTOM KEYWORDS |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| CUSTOM KEYWORDS |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| CUSTOM KEYWORDS |||||||||||||||||||||||||||||

            #pragma shader_feature_local _NORMALMAP

            //||||||||||||||||||||||||||||| UNITY3D INCLUDES |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| UNITY3D INCLUDES |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| UNITY3D INCLUDES |||||||||||||||||||||||||||||

            //BUILT IN RENDER PIPELINE
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            #include "UnityShadowLibrary.cginc"
            #include "UnityLightingCommon.cginc"
            #include "UnityStandardBRDF.cginc"

            //||||||||||||||||||||||||||||| SHADER PARAMETERS |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| SHADER PARAMETERS |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| SHADER PARAMETERS |||||||||||||||||||||||||||||

            float4 _Color;
            sampler2D _MainTex;
            float4 _MainTex_ST;         //(X = Tiling X | Y = Tiling Y | Z = Offset X | W = Offset Y)
            float4 _MainTex_TexelSize;  //(X = 1 / Width | Y = 1 / Height | Z = Width | W = Height)

            float _NormalStrength;
            sampler2D _BumpMap;
            float4 _BumpMap_ST;         //(X = Tiling X | Y = Tiling Y | Z = Offset X | W = Offset Y)
            float4 _BumpMap_TexelSize;  //(X = 1 / Width | Y = 1 / Height | Z = Width | W = Height)

            float _Smoothness;
            float _ReflectionIntensity;

            //||||||||||||||||||||||||||||| SPHERICAL HARMONICS |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| SPHERICAL HARMONICS |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| SPHERICAL HARMONICS |||||||||||||||||||||||||||||

            float3 GetDominantDirectionFromSH_Probe()
            {
                //add the first two orders (L0 and L1) from the spherical harmonics probe to get our direction.
                float3 dominantDirection = unity_SHAr.xyz + unity_SHAg.xyz + unity_SHAb.xyz;

                //Neitri proposed to use greyscale to get a better approximation of light direction from SH? (note it was only done on the L0 L1 bands)
                //https://github.com/netri/Neitri-Unity-Shaders/blob/master/Avatar%20Shaders/Core.cginc
                //float3 dominantDirection = unity_SHAr.xyz * 0.3 + unity_SHAg.xyz * 0.59 + unity_SHAb.xyz * 0.11;

                //custom version of what Neitri proposes, instead of using arbitrary luma color values, use what is given to us which is unity_ColorSpaceLuminance
                //float3 dominantDirection = unity_SHAr.xyz * unity_ColorSpaceLuminance.x + unity_SHAg.xyz * unity_ColorSpaceLuminance.y + unity_SHAb.xyz * unity_ColorSpaceLuminance.z;

                return dominantDirection;
            }

            float3 GetDominantDirectionFromSH_ProbeVolume(float3 vector_worldPosition)
            {
                const float transformToLocal = unity_ProbeVolumeParams.y;
                const float texelSizeX = unity_ProbeVolumeParams.z;

                //The SH coefficients textures and probe occlusion are packed into 1 atlas.
                //-------------------------
                //| ShR | ShG | ShB | Occ |
                //-------------------------

                float3 position = (transformToLocal == 1.0f) ? mul(unity_ProbeVolumeWorldToObject, float4(vector_worldPosition, 1.0)).xyz : vector_worldPosition;
                float3 texCoord = (position - unity_ProbeVolumeMin.xyz) * unity_ProbeVolumeSizeInv.xyz;
                texCoord.x = texCoord.x * 0.25f;

                // We need to compute proper X coordinate to sample.
                // Clamp the coordinate otherwize we'll have leaking between RGB coefficients
                float texCoordX = clamp(texCoord.x, 0.5f * texelSizeX, 0.25f - 0.5f * texelSizeX);

                // sampler state comes from SHr (all SH textures share the same sampler)
                texCoord.x = texCoordX;
                float4 SHAr = UNITY_SAMPLE_TEX3D_SAMPLER(unity_ProbeVolumeSH, unity_ProbeVolumeSH, texCoord);

                texCoord.x = texCoordX + 0.25f;
                float4 SHAg = UNITY_SAMPLE_TEX3D_SAMPLER(unity_ProbeVolumeSH, unity_ProbeVolumeSH, texCoord);

                texCoord.x = texCoordX + 0.5f;
                float4 SHAb = UNITY_SAMPLE_TEX3D_SAMPLER(unity_ProbeVolumeSH, unity_ProbeVolumeSH, texCoord);

                //add the L1 bands from the spherical harmonics probe to get our direction.
                float3 dominantDirection = SHAr.xyz + SHAg.xyz + SHAb.xyz;

                //Neitri proposed to use greyscale to get a better approximation of light direction from SH? (note it was only done on the L0 L1 bands)
                //https://github.com/netri/Neitri-Unity-Shaders/blob/master/Avatar%20Shaders/Core.cginc
                //float3 dominantDirection = SHAr.xyz * 0.3 + SHAg.xyz * 0.59 + SHAb.xyz * 0.11;

                //custom version of what Neitri proposes, instead of using arbitrary luma color values, use what is given to us which is unity_ColorSpaceLuminance
                //float3 dominantDirection = SHAr.xyz * unity_ColorSpaceLuminance.x + SHAg.xyz * unity_ColorSpaceLuminance.y + SHAb.xyz * unity_ColorSpaceLuminance.z;

                return dominantDirection;
            }

            struct meshData
            {
                float4 vertex : POSITION;   //Vertex Position (X = Position X | Y = Position Y | Z = Position Z | W = 1)
                float3 normal : NORMAL;     //Normal Direction [-1..1] (X = Direction X | Y = Direction Y | Z = Direction)
                float4 tangent : TANGENT;   //Tangent Direction [-1..1] (X = Direction X | Y = Direction Y | Z = Direction)
                float2 uv0 : TEXCOORD0;     //Mesh UVs [0..1] (X = U | Y = V)
                float2 uv1 : TEXCOORD1;     //Lightmap UVs [0..1] (X = U | Y = V)
                float2 uv2 : TEXCOORD2;     //Dynamic Lightmap UVs [0..1] (X = U | Y = V)
                float4 color : COLOR;       //Vertex Color (X = Red | Y = Green | Z = Blue | W = Alpha)

                UNITY_VERTEX_INPUT_INSTANCE_ID //Instancing
            };

            struct vertexToFragment
            {
                float4 vertexCameraClipPosition : SV_POSITION;                    //Vertex Position In Camera Clip Space
                float2 uv0 : TEXCOORD0;                         //UV0 Texture Coordinates
                float4 uvStaticAndDynamicLightmap : TEXCOORD1;  //(XY = Static Lightmap UVs, ZW = Dynamic Lightmap UVs)
                float4 vertexWorldPosition : TEXCOORD2;               //Vertex World Space Position 
                float3 tangentSpace0 : TEXCOORD3;
                float3 tangentSpace1 : TEXCOORD4;
                float3 tangentSpace2 : TEXCOORD5;

                UNITY_FOG_COORDS(6)

                UNITY_VERTEX_OUTPUT_STEREO //Instancing
            };

            vertexToFragment vertex_forward_base(meshData data)
            {
                vertexToFragment vertex;

                //Instancing
                UNITY_SETUP_INSTANCE_ID(data);
                UNITY_INITIALIZE_OUTPUT(vertexToFragment, vertex);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(vertex);

                //transforms a point from object space to the camera's clip space
                vertex.vertexCameraClipPosition = UnityObjectToClipPos(data.vertex);

                //[TEXCOORD ASSIGNMENT 1]
                //This is the simplest way of getting texture coordinates.
                //This can be useful if you have multiple tiled textures in a shader, but don't want to create a large amount of texcoords to store all of them.
                //You can instead transform the texture coordinates in the fragment shader for each of those textures when sampling them.
                vertex.uv0 = data.uv0;

                //[TEXCOORD ASSIGNMENT 2]
                //This is a common way of getting texture coordinates, and transforming them with tiling/offsets from _MainTex.
                //Technically this is more efficent than the first because these are only computed per vertex and for one texture.
                //But it can become limiting if you have multiple textures and each of them have their own tiling/offsets
                //o.uv0 = TRANSFORM_TEX(v.uv0, _MainTex);

                //define our world position vector
                vertex.vertexWorldPosition = mul(unity_ObjectToWorld, data.vertex);

                //get regular static lightmap texcoord ONLY if lightmaps are in use
                #if defined(LIGHTMAP_ON)
                    vertex.uvStaticAndDynamicLightmap.xy = data.uv1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
                #endif

                //get dynamic lightmap texcoord ONLY if dynamic lightmaps are in use
                #if defined(DYNAMICLIGHTMAP_ON)
                    vertex.uvStaticAndDynamicLightmap.zw = data.uv2.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
                #endif

                //if we are using a normal map then compute tangent vectors, otherwise just compute the regular mesh normal
                #if defined(_NORMALMAP)
                    //compute the world normal
                    float3 worldNormal = UnityObjectToWorldNormal(normalize(data.normal));

                    //the tangents of the mesh
                    float3 worldTangent = UnityObjectToWorldDir(data.tangent.xyz);

                    //compute bitangent from cross product of normal and tangent
                    float3 worldBiTangent = cross(worldNormal, worldTangent) * (data.tangent.w * unity_WorldTransformParams.w);

                    //output the tangent space matrix
                    vertex.tangentSpace0 = float3(worldTangent.x, worldBiTangent.x, worldNormal.x);
                    vertex.tangentSpace1 = float3(worldTangent.y, worldBiTangent.y, worldNormal.y);
                    vertex.tangentSpace2 = float3(worldTangent.z, worldBiTangent.z, worldNormal.z);
                #else
                    //the world normal of the mesh
                    vertex.tangentSpace0 = UnityObjectToWorldNormal(normalize(data.normal));
                #endif

                UNITY_TRANSFER_FOG(vertex, vertex.vertexCameraClipPosition);

                return vertex;
            }

            float4 fragment_forward_base(vertexToFragment vertex) : SV_Target
            {
                //||||||||||||||||||||||||||||||| VECTORS |||||||||||||||||||||||||||||||
                //||||||||||||||||||||||||||||||| VECTORS |||||||||||||||||||||||||||||||
                //||||||||||||||||||||||||||||||| VECTORS |||||||||||||||||||||||||||||||
                //main shader vectors used for textures or lighting calculations.

                float2 vector_uv = vertex.uv0; //uvs for sampling regular textures (uv0)
                float2 vector_lightmapUVs = vertex.uvStaticAndDynamicLightmap.xy; //uvs for baked lightmaps (uv1)
                float2 vector_lightmapDynamicUVs = vertex.uvStaticAndDynamicLightmap.zw; //uvs for dynamic lightmaps (enlighten) (uv2)
                float3 vector_worldPosition = vertex.vertexWorldPosition.xyz; //world position vector
                float3 vector_viewPosition = _WorldSpaceCameraPos.xyz - vector_worldPosition; //camera world position
                float3 vector_viewDirection = normalize(vector_viewPosition); //camera world position direction
                float3 vector_tangent = float3(vertex.tangentSpace0.x, vertex.tangentSpace1.x, vertex.tangentSpace2.x);
                float3 vector_biTangent = float3(vertex.tangentSpace0.y, vertex.tangentSpace1.y, vertex.tangentSpace2.y);
                float3 vector_worldNormal = float3(vertex.tangentSpace0.z, vertex.tangentSpace1.z, vertex.tangentSpace2.z);
                float3 vector_lightDirection = normalize(_WorldSpaceLightPos0.xyz);
                float3x3 matrix_tangentToWorld = float3x3(vector_tangent, vector_biTangent, vector_worldNormal);
                float3 vector_viewDirectionTangentSpace = mul(matrix_tangentToWorld, vector_viewDirection);
                float3 vector_lightDirectionTangent = mul(matrix_tangentToWorld, vector_lightDirection.xyz);

                #if defined(_NORMALMAP)
                    float4 texture_normalMap = tex2D(_BumpMap, vector_uv);
                    float3 unpackedNormal = UnpackNormalWithScale(texture_normalMap, _NormalStrength);

                    float3 vector_normalDirection = float3(
                        dot(vertex.tangentSpace0, unpackedNormal.xyz),
                        dot(vertex.tangentSpace1, unpackedNormal.xyz),
                        dot(vertex.tangentSpace2, unpackedNormal.xyz));

                    vector_normalDirection = normalize(vector_normalDirection);
                #else
                    float3 vector_normalDirection = vertex.tangentSpace0;
                #endif

                float3 vector_reflectionDirection = reflect(-vector_viewDirection, vector_normalDirection);

                //||||||||||||||||||||||||||||||| FINAL COLOR |||||||||||||||||||||||||||||||
                //||||||||||||||||||||||||||||||| FINAL COLOR |||||||||||||||||||||||||||||||
                //||||||||||||||||||||||||||||||| FINAL COLOR |||||||||||||||||||||||||||||||

                float4 finalColor = float4(0, 0, 0, 1);

                //||||||||||||||||||||||||||||||| ENLIGHTEN LIGHTING |||||||||||||||||||||||||||||||
                //||||||||||||||||||||||||||||||| ENLIGHTEN LIGHTING |||||||||||||||||||||||||||||||
                //||||||||||||||||||||||||||||||| ENLIGHTEN LIGHTING |||||||||||||||||||||||||||||||
                //support for enlighten realtime precomputed GI

                #if defined(DYNAMICLIGHTMAP_ON)
                    float4 dynamicLightmap = UNITY_SAMPLE_TEX2D(unity_DynamicLightmap, vector_lightmapDynamicUVs.xy);

                    dynamicLightmap.rgb = DecodeRealtimeLightmap(dynamicLightmap);

                    //Samples the directional lightmap if enabled.
                    //This can allow us to do more shading.
                    #if defined(DIRLIGHTMAP_COMBINED)
                        //[Method 1]: 
                        //This is doing it by hand, and is slightly different as in that it will shade the underlying lightmap with more contrast.
                        //You can also use the lightmap direction, treat it as a light and use it to compute a specular term.
                        float4 dynamicLightmapDirection = UNITY_SAMPLE_TEX2D_SAMPLER(unity_DynamicDirectionality, unity_DynamicLightmap, vector_lightmapDynamicUVs.xy) * 2.0f - 1.0f;
                        float dynamicLightmapDirectionLength = length(dynamicLightmapDirection.w);
                        dynamicLightmapDirection /= dynamicLightmapDirectionLength;

                        //[Method 2]: 
                        //This is doing just like method 1 except its using unity's built in function for it.
                        //Contrast is slightly less however, but according to comments in the internal function its closer in apperance to the underlying lightmap.
                        //float4 dynamicLightmapDirection = UNITY_SAMPLE_TEX2D_SAMPLER(unity_DynamicDirectionality, unity_DynamicLightmap, vector_lightmapDynamicUVs.xy);
                        //dynamicLightmap.rgb = DecodeDirectionalLightmap(dynamicLightmap.rgb, dynamicLightmapDirection, vector_normalDirection);
                    #endif

                    finalColor += dynamicLightmap;
                #endif


                //||||||||||||||||||||||||||||||| BAKED LIGHTING |||||||||||||||||||||||||||||||
                //||||||||||||||||||||||||||||||| BAKED LIGHTING |||||||||||||||||||||||||||||||
                //||||||||||||||||||||||||||||||| BAKED LIGHTING |||||||||||||||||||||||||||||||
                //support for regular baked unity lightmaps.

                #if defined(LIGHTMAP_ON)
                    float4 indirectLightmap = UNITY_SAMPLE_TEX2D(unity_Lightmap, vector_lightmapUVs.xy);

                    indirectLightmap.rgb = DecodeLightmap(indirectLightmap);

                    //Samples the directional lightmap if enabled.
                    //This can allow us to do more shading.
                    #if defined(DIRLIGHTMAP_COMBINED)
                        //[Method 1]: 
                        //Samples the baked directional lightmap.
                        //This is doing it by hand, and is slightly different as in that it will shade the underlying lightmap with more contrast.
                        //You can also use the lightmap direction, treat it as a light and use it to compute a specular term.
                        float4 lightmapDirection = UNITY_SAMPLE_TEX2D_SAMPLER(unity_LightmapInd, unity_Lightmap, vector_lightmapUVs) * 2.0 - 1.0;
                        float lightmapDirectionLength = length(lightmapDirection.w);
                        lightmapDirection /= lightmapDirectionLength;
                        indirectLightmap *= max(0.0, dot(lightmapDirection, vector_normalDirection));

                        //[Method 2]: 
                        //Samples the baked directional lightmap.
                        //This is doing just like method 1 except its using unity's built in function for it.
                        //Contrast is slightly less however, but according to comments in the internal function its closer in apperance to the underlying lightmap.
                        //float4 lightmapDirection = UNITY_SAMPLE_TEX2D_SAMPLER(unity_LightmapInd, unity_Lightmap, vector_lightmapUVs);
                        //indirectLightmap.rgb = DecodeDirectionalLightmap(indirectLightmap.rgb, lightmapDirection, vector_normalDirection);
                    #endif

                    finalColor += indirectLightmap;
                #endif

                //||||||||||||||||||||||||||||||| AMBIENT LIGHTING |||||||||||||||||||||||||||||||
                //||||||||||||||||||||||||||||||| AMBIENT LIGHTING |||||||||||||||||||||||||||||||
                //||||||||||||||||||||||||||||||| AMBIENT LIGHTING |||||||||||||||||||||||||||||||
                //support for regular ambient lighting (non-lightmapped, no englighten).
                //NOTE: this still works even when there are no light probes, and the enviorment is set to either a gradient, or a single color.

                #if !defined (LIGHTMAP_ON)
                    #if defined (UNITY_LIGHT_PROBE_PROXY_VOLUME)
                        float3 sphericalHarmonicsColor = float3(0, 0, 0);
                        float3 dominantDirection = float3(0, 0, 0);

                        UNITY_BRANCH
                            if (unity_ProbeVolumeParams.x == 1.0)
                            {
                                sphericalHarmonicsColor = SHEvalLinearL0L1_SampleProbeVolume(float4(vector_normalDirection, 1), vector_worldPosition);

                                dominantDirection = GetDominantDirectionFromSH_ProbeVolume(vector_worldPosition.xyz);
                            }
                            else
                            {
                                sphericalHarmonicsColor = ShadeSH9(float4(vector_normalDirection, 1));

                                dominantDirection = GetDominantDirectionFromSH_Probe();
                            }
                    #else
                        float3 sphericalHarmonicsColor = ShadeSH9(float4(vector_normalDirection, 1));
                        float3 dominantDirection = GetDominantDirectionFromSH_Probe();
                    #endif

                    finalColor.rgb += sphericalHarmonicsColor;
                #endif

                //||||||||||||||||||||||||||||||| ALBEDO |||||||||||||||||||||||||||||||
                //||||||||||||||||||||||||||||||| ALBEDO |||||||||||||||||||||||||||||||
                //||||||||||||||||||||||||||||||| ALBEDO |||||||||||||||||||||||||||||||

                //transform the UVs so that we can tile/offset the main texture.
                //we could also do this in the vertex shader before hand (which is slightly more efficent)
                vector_uv = vector_uv * _MainTex_ST.xy + _MainTex_ST.zw;

                // sample the texture
                float4 textureColor = tex2D(_MainTex, vector_uv) * _Color;

                finalColor *= textureColor;

                //||||||||||||||||||||||||||||||| ENVIORMENT REFLECTIONS |||||||||||||||||||||||||||||||
                //||||||||||||||||||||||||||||||| ENVIORMENT REFLECTIONS |||||||||||||||||||||||||||||||
                //||||||||||||||||||||||||||||||| ENVIORMENT REFLECTIONS |||||||||||||||||||||||||||||||

                #if defined (UNITY_SPECCUBE_BOX_PROJECTION)
                    vector_reflectionDirection = BoxProjectedCubemapDirection(vector_reflectionDirection, vector_worldPosition, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
                #endif

                float perceptualRoughness = 1 - _Smoothness;
                float mip = perceptualRoughnessToMipmapLevel(perceptualRoughness);

                float4 enviormentReflection = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, vector_reflectionDirection.xyz, mip);
                enviormentReflection.rgb = DecodeHDR(enviormentReflection, unity_SpecCube0_HDR);

                finalColor += enviormentReflection * _ReflectionIntensity;

                //||||||||||||||||||||||||||||||| UNITY FOG |||||||||||||||||||||||||||||||
                //||||||||||||||||||||||||||||||| UNITY FOG |||||||||||||||||||||||||||||||
                //||||||||||||||||||||||||||||||| UNITY FOG |||||||||||||||||||||||||||||||

                // apply fog
                UNITY_APPLY_FOG(vertex.fogCoord, finalColor);

                return finalColor;
            }
            ENDCG
        }

        Pass
        {
            Name "ObjectShaderTemplate_ShadowCaster"

            Tags 
            { 
                "LightMode" = "ShadowCaster" 
            }

            CGPROGRAM

            #pragma vertex vertex_shadow_cast
            #pragma fragment fragment_shadow_caster
            #pragma target 3.0

            //||||||||||||||||||||||||||||| UNITY3D KEYWORDS |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| UNITY3D KEYWORDS |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| UNITY3D KEYWORDS |||||||||||||||||||||||||||||

            #pragma multi_compile_shadowcaster
            #pragma multi_compile_instancing

            //||||||||||||||||||||||||||||| UNITY3D INCLUDES |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| UNITY3D INCLUDES |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| UNITY3D INCLUDES |||||||||||||||||||||||||||||

            //BUILT IN RENDER PIPELINE
            #include "UnityCG.cginc"

            struct meshData
            {
                float4 vertex : POSITION;   //Vertex Position (X = Position X | Y = Position Y | Z = Position Z | W = 1)
                float3 normal : NORMAL;     //Normal Direction [-1..1] (X = Direction X | Y = Direction Y | Z = Direction)

                UNITY_VERTEX_INPUT_INSTANCE_ID //Instancing
            };

            struct vertexToFragment
            {
                V2F_SHADOW_CASTER;

                UNITY_VERTEX_OUTPUT_STEREO //Instancing
            };

            vertexToFragment vertex_shadow_cast(meshData v)
            {
                vertexToFragment vertex;

                //Instancing
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_OUTPUT(vertexToFragment, vertex);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(vertex);

                TRANSFER_SHADOW_CASTER_NORMALOFFSET(vertex)

                return vertex;
            }

            float4 fragment_shadow_caster(vertexToFragment vertex) : SV_Target
            {
                SHADOW_CASTER_FRAGMENT(vertex)
            }

            ENDCG
        }
    }
}
