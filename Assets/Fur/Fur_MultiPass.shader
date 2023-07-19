Shader "Custom/Fur_MultiPass"
{
    Properties
    {
        [Header(Macro)]
        [Toggle(_DEBUG_LAYERMAP)] _DebugLayerMap("Debug LayerMap", Float) = 0.0
        [Toggle(_FABRIC)] _Fabric("Fabric Scatter", Float) = 1.0
        [ToggleOff] _EnvironmentReflections("Environment Reflections", Float) = 1.0
        [ToggleOff] _RECEIVE_SHADOWS("Receive Shadow", Float) = 1.0
        
        [Header(Main)]
        [MainColor]_Color("Color", Color) = (1,1,1,1)
        _MainTex("Albedo", 2D) = "white" {}

        _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
        _Glossiness("Smoothness", Range(0.0, 1.0)) = 0.5

        [Toggle(_NORMALMAP)] _UseNormalMap("Use Normal Map", Float) = 0.0
        _BumpMap("Normal Map", 2D) = "bump" {}
        _BumpScale("Noramal Scale", Range(0,1)) = 1.0

        [Space(20)]
        _FabricScatterColor("Fabric Scatter Color", Color) = (1,1,1,1)
        _FabricScatterScale("Fabric Scatter Scale", Range(0,1)) = 0

        [Space(20)]
        _LayerTex("Layer", 2D) = "white" {}
        _FurLength("Fur Length", Range(.0002, 10)) = 0.15
        _CutoffEnd("Alpha Cutoff end", Range(0,1)) = 1.0 // how thick they are at the end
        _EdgeFade("Edge Fade", Range(0,1)) = 0.5
        _Gravity("Gravity Direction", Vector) = (0, -1, 0, 0)
        _GravityStrength("Gravity Strength", Range(0,1)) = 0.25
        _FlowMap("Flow Map", 2D) = "gray" {}
        _UVOffset("UVOffset", Range(0,1)) = 0.0
        [Header(Shadow)]
        _ShadowColor("Shadow Color", Color) = (0,0,0,0)
        _ShadowLerp("Shadow AO", Range(0,1)) = 1.0
        
        // Blending state
        [Header(Settings)]
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("Src Blend Mode", Float) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("Dst Blend Mode", Float) = 10
        [Toggle]_ZWrite("Z-Write", Float) = 1.0
        // [Toggle(_ALPHATEST_ON)] _AlphaTest("Alpha Test", Float) = 1.0
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline"
        }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        TEXTURE2D(_MainTex);      SAMPLER(sampler_MainTex);
        TEXTURE2D(_BumpMap);      SAMPLER(sampler_BumpMap);
        TEXTURE2D(_LayerTex);     SAMPLER(sampler_LayerTex);
        TEXTURE2D(_FlowMap);      SAMPLER(sampler_FlowMap);
        TEXTURE2D(_OcclusionMap); SAMPLER(sampler_OcclusionMap);

        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        float4 _LayerTex_ST;
        
        half4 _Color;
        float _Metallic;
        float _Glossiness;
        float _BumpScale;
        half4 _FabricScatterColor;
        float _FabricScatterScale;
        float _FurLength;
        float _CutoffEnd;
        float _EdgeFade;
        float3 _Gravity;
        float _GravityStrength;
        float _UVOffset;
        half4 _ShadowColor;
        float _ShadowLerp;
        CBUFFER_END
        
        half _FUR_OFFSET;
        
        ENDHLSL

        Pass
        {
            Name "FurRender"
            Tags
            {
                "LightMode" = "UniversalForward"
            }

            ZWrite[_ZWrite]
            Cull Back

            HLSLPROGRAM
            #pragma shader_feature_local _DEBUG_LAYERMAP
            #pragma shader_feature_local _FABRIC
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF
            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fog

            #pragma vertex vert
            #pragma fragment frag

            #include "FurCore.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "FurRender"
            Tags
            {
                "LightMode" = "FurRendererLayer"
            }

            Blend[_SrcBlend][_DstBlend]
            ZWrite[_ZWrite]
            Cull Back

            HLSLPROGRAM
            #pragma shader_feature_local _DEBUG_LAYERMAP
            #pragma shader_feature_local _FABRIC
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF
            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fog

            #pragma vertex vert
            #pragma fragment frag

            #include "FurCore.hlsl"
            ENDHLSL
        }
    }
}