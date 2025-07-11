Shader "Custom/Pure"
{
    SubShader
    {
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            // --- Settings and constants ---
            static const float PI = 3.1415;

            struct v2f {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            v2f vert(appdata_img v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.texcoord;
                return o;
            };

            // Ray
            float3 ViewParams;
            float4x4 CamLocalToWorldMatrix;

            struct Ray {
                float3 origin;
                float3 dir;
            };

            struct HitInfo {
                bool didHit;
                float dst;
            };

            int Frame;

            uint NextRandom(inout uint state)
            {
                state = state * 747796405 + 2891336453;
                uint result = ((state >> ((state >> 28) + 4)) ^ state) * 277803737;
                result = (result >> 22) ^ result;
                return result;
            }

            float RandomValue(inout uint state)
            {
                return NextRandom(state) / 4294967295.0; // 2^32 - 1
            }

            float2 RandomPointInCircle(inout uint rngState)
            {
                float angle = RandomValue(rngState) * 2 * PI;
                float2 pointOnCircle = float2(cos(angle), sin(angle));
                return pointOnCircle * sqrt(RandomValue(rngState));
            }

            float3 UniformHemisphereSample(uint rngState)
            {
                float z = RandomValue(rngState);
                float r = sqrt(1.0 - z * z);
                float phi = 2.0 * PI * RandomValue(rngState);

                float x = r * cos(phi);
                float y = r * sin(phi);

                return float3(x, y, z);
            }

            float3 TangentToWorld(float3 localDir, float3 normal) {
                float3 up = abs(normal.z) < 0.999 ? float3(0, 0, 1) : float3(1, 0, 0);
                float3 tangent = normalize(cross(up, normal));
                float3 bitangent = cross(normal, tangent);

                // 将 localDir 转换到世界空间
                return localDir.x * tangent + localDir.y * bitangent + localDir.z * normal;
            }

            float3 RandomHemisphereDirection(float3 normal, uint rngState) {
                float3 localDir = UniformHemisphereSample(rngState);

                return TangentToWorld(localDir, normal);
            }

            HitInfo IntersectGround(Ray ray) {
                HitInfo hitInfo = (HitInfo)0;
                if (ray.dir.y >= 0)
                    return hitInfo;
                hitInfo.dst = -ray.origin.y / ray.dir.y;
                hitInfo.didHit = hitInfo.dst > 0;
                return hitInfo;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                uint2 numPixels = _ScreenParams.xy;
                uint2 pixelCoord = i.uv * numPixels;
                uint pixelIndex = pixelCoord.y * numPixels.x + pixelCoord.x;
                uint rngState = pixelIndex + Frame * 719393;

                float3 viewPointLocal = float3(i.uv - 0.5,1) * ViewParams;
                float3 viewPoint = mul(CamLocalToWorldMatrix, float4(viewPointLocal, 1));

                Ray ray;
                ray.origin = _WorldSpaceCameraPos;
                ray.dir = normalize(viewPoint - ray.origin);

                HitInfo hitInfo = IntersectGround(ray);
                if (hitInfo.didHit) {
                    float3 normal = float3(0, 1, 0);
                    float3 newDir = RandomHemisphereDirection(normal, rngState); // 第一次 bounce
                    // 用方向表示颜色（调试用）
                    return float4(newDir * 0.5 + 0.5, 1);
                }
                return float4(0, 0, 0, 1);
            }
            ENDCG
        }
    }
}
