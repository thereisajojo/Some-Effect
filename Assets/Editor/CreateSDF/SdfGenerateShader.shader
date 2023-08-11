Shader "Hidden/SdfGenerateShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            sampler2D _MainTex;
            float4 _MainTex_TexelSize;
            float _range;

            bool isIn(float2 uv)
            {
                float4 texColor = tex2D(_MainTex, uv);
                return texColor.r > 0.5;
            }

            float squaredDistanceBetween(float2 uv1, float2 uv2)
            {
                float2 delta = uv1 - uv2;
                float dist = (delta.x * delta.x) + (delta.y * delta.y);
                return dist;
            }

            float4 frag (v2f i) : SV_Target
            {
                float2 uv = i.uv;

                const float range = _range;
                const int iRange = int(range);
                float halfRange = range / 2.0;
                float2 startPosition = float2(i.uv.x - halfRange * _MainTex_TexelSize.x, i.uv.y - halfRange * _MainTex_TexelSize.y);

                bool fragIsIn = isIn(uv);
                float squaredDistanceToEdge = (halfRange * _MainTex_TexelSize.x * halfRange * _MainTex_TexelSize.y) * 2.0;

                for (int dx = 0; dx < iRange; dx++)
                {
                    for (int dy = 0; dy < iRange; dy++)
                    {
                        float2 scanPositionUV = startPosition + float2(dx * _MainTex_TexelSize.x, dy * _MainTex_TexelSize.y);

                        bool scanIsIn = isIn(scanPositionUV / 1);
                        if (scanIsIn != fragIsIn)
                        {
                            float scanDistance = squaredDistanceBetween(i.uv, scanPositionUV);
                            if (scanDistance < squaredDistanceToEdge)
                            {
                                squaredDistanceToEdge = scanDistance;
                            }
                        }
                    }
                }

                float normalised = squaredDistanceToEdge / ((halfRange * _MainTex_TexelSize.x * halfRange * _MainTex_TexelSize.y) * 2.0);
                float distanceToEdge = sqrt(normalised);
                if (fragIsIn)
                    distanceToEdge = -distanceToEdge;
                normalised = 0.5 - distanceToEdge;

                return float4(normalised, normalised, normalised, 1.0);
            }
            ENDCG
        }
    }
}
