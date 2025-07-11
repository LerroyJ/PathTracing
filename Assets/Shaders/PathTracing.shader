Shader "Custom/PathTracing"
{
    SubShader
    {
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

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

            struct RayTracingMaterial {
                float4 colour;
                float4 emissionColour;
                float4 specularColour;
                float emissionStrength;
                float smoothness;
                float specularProbability;
                int materialType;
            };

            struct HitInfo {
                bool didHit;
                float dst;
                float3 hitPoint;
                float3 normal;
                RayTracingMaterial material;
            };

            // Scene
            struct Sphere {
                float3 position;
                float radius;
                RayTracingMaterial material;
            };
            StructuredBuffer<Sphere> Spheres;
            int NumSpheres;

            struct Triangle
            {
                float3 posA;
                float3 posB;
                float3 posC;
                float3 normalA;
                float3 normalB;
                float3 normalC;
                RayTracingMaterial material;
            };
            StructuredBuffer<Triangle> Triangles;
            int NumTriangles;

            struct Bound{
                float3 boundsMin;
                float3 boundsMax;
            };

            struct MeshInfo {
                Bound bound;
                int left;
                int right;
                int triangleIndex;
                int thisIndex;
            };
            StructuredBuffer<MeshInfo> AllMeshInfo;
            int NumMeshes;

            int Frame;
            static const float PI = 3.1415;
            // 随机数生成器
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


            // 球体求交
            HitInfo RaySphere(Ray ray, float3 sphereCenter, float sphereRadius) {
                HitInfo hitInfo = (HitInfo)0;
                float3 offsetRayOrigin = ray.origin - sphereCenter;
                float a = dot(ray.dir, ray.dir);
                float b = 2 * dot(offsetRayOrigin, ray.dir);
                float c = dot(offsetRayOrigin, offsetRayOrigin) - sphereRadius * sphereRadius;

                float discriminant = b * b - 4 * a * c;

                if (discriminant >= 0) {
                    float dst = (-b - sqrt(discriminant)) / (2 * a);

                    if (dst >= 0) {
                        hitInfo.didHit = true;
                        hitInfo.dst = dst;
                        hitInfo.hitPoint = ray.origin + ray.dir * dst;
                        hitInfo.normal = normalize(hitInfo.hitPoint - sphereCenter);
                    }
                }
                return hitInfo;
            }

            // 三角形求交
            HitInfo RayTriangle(Ray ray, Triangle tri)
            {
                float3 edgeAB = tri.posB - tri.posA;
                float3 edgeAC = tri.posC - tri.posA;
                float3 normalVector = cross(edgeAB, edgeAC);
                float3 ao = ray.origin - tri.posA;
                float3 dao = cross(ao, ray.dir);

                float determinant = -dot(ray.dir, normalVector);
                float invDet = 1 / determinant;

                // Calculate dst to triangle & barycentric coordinates of intersection point
                float dst = dot(ao, normalVector) * invDet;
                float u = dot(edgeAC, dao) * invDet;
                float v = -dot(edgeAB, dao) * invDet;
                float w = 1 - u - v;

                // Initialize hit info
                HitInfo hitInfo;
                hitInfo.didHit = determinant >= 1E-6 && dst >= 0 && u >= 0 && v >= 0 && w >= 0;
                hitInfo.hitPoint = ray.origin + ray.dir * dst;
                hitInfo.normal = normalize(tri.normalA * w + tri.normalB * u + tri.normalC * v);
                hitInfo.dst = dst;
                return hitInfo;
            }

            bool allFinite(float3 v){
                return isfinite(v.x) && isfinite(v.y) && isfinite(v.z);
            }

            // AABB
            bool RayBoundingBox(Ray ray, float3 boxMin, float3 boxMax)
            {
                float3 invDir = 1 / ray.dir;
                float3 tMin = (boxMin - ray.origin) * invDir;
                float3 tMax = (boxMax - ray.origin) * invDir;
                float3 t1 = min(tMin, tMax);
                float3 t2 = max(tMin, tMax);
                float tNear = max(max(t1.x, t1.y), t1.z);
                float tFar = min(min(t2.x, t2.y), t2.z);
                return tNear <= tFar;
            };

            // fresnelϵ系数
            float fresnel(float3 dir, float3 N, float ior) {
                float cosi = clamp(-1, 1, dot(dir, N));
                float etai = 1, etat = ior;
                if (cosi > 0) {
                    float t = etai;
                    etai = etat;
                    etat = t;
                }
                float sint = etai / etat * sqrt(max(0.f, 1 - cosi * cosi));
                if (sint >= 1) {
                    return 1;
                }
                else {
                    float cost = sqrt(max(0.f, 1 - sint * sint));
                    cosi = abs(cosi);
                    float Rs = ((etat * cosi) - (etai * cost)) / ((etat * cosi) + (etai * cost));
                    float Rp = ((etai * cosi) - (etat * cost)) / ((etai * cosi) + (etat * cost));
                    return (Rs * Rs + Rp * Rp) / 2;
                }
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

            float3 CosineWeightedHemisphereSample(uint rngState)
            {
                float r1 = RandomValue(rngState);
                float r2 = RandomValue(rngState);
                float r = sqrt(r1);
                float theta = 2.0 * PI * r2;

                float x = r * cos(theta);
                float y = r * sin(theta);
                float z = sqrt(1.0 - r1);

                return float3(x, y, z);
            }

            float3 TangentToWorld(float3 localDir, float3 normal) {
                float3 up = abs(normal.z) < 0.999 ? float3(0, 0, 1) : float3(1, 0, 0);
                float3 tangent = normalize(cross(up, normal));
                float3 bitangent = cross(normal, tangent);

                return localDir.x * tangent + localDir.y * bitangent + localDir.z * normal;
            }

            // Environment Settings
			int EnvironmentEnabled;
			float4 GroundColour;
			float4 SkyColourHorizon;
			float4 SkyColourZenith;
			float SunFocus;
			float SunIntensity;
            // Crude sky colour function for background light
			float3 GetEnvironmentLight(Ray ray)
			{
				if (!EnvironmentEnabled) {
					return 0;
				}
				
				float skyGradientT = pow(smoothstep(0, 0.4, ray.dir.y), 0.35);
				float groundToSkyT = smoothstep(-0.01, 0, ray.dir.y);
				float3 skyGradient = lerp(SkyColourHorizon, SkyColourZenith, skyGradientT);
				float sun = pow(max(0, dot(ray.dir, _WorldSpaceLightPos0.xyz)), SunFocus) * SunIntensity;
				// Combine ground, sky, and sun
				float3 composite = lerp(GroundColour, skyGradient, groundToSkyT) + sun * (groundToSkyT>=1);
				return composite;
			}

            // 暴力求解光线交点
            HitInfo CalculateRayCollision(Ray ray) {
                HitInfo closestHit = (HitInfo)0;
                closestHit.dst = 1.#INF;

                for (int i = 0; i < NumSpheres; i++) {
                    Sphere sphere = Spheres[i];
                    HitInfo hitInfo = RaySphere(ray, sphere.position, sphere.radius);
                    if (hitInfo.didHit && hitInfo.dst < closestHit.dst) {
                        closestHit = hitInfo;
                        closestHit.material = sphere.material;
                    }
                }


                for (int j = 0; j < NumTriangles; j++) {
                    HitInfo hitInfo = RayTriangle(ray, Triangles[j]);
                    if (hitInfo.didHit && hitInfo.dst < closestHit.dst) {
                        closestHit = hitInfo;
                        closestHit.material = Triangles[j].material;
                    }
                }
                return closestHit;
            }

            // BVH加速结构
            HitInfo BVHCalculateRayCollision(Ray ray) {
                HitInfo closestHit = (HitInfo)0;
                closestHit.dst = 1.#INF;

                for (int j = 0; j < NumSpheres; j++) {
                    Sphere sphere = Spheres[j];
                    HitInfo hitInfo = RaySphere(ray, sphere.position, sphere.radius);
                    if (hitInfo.didHit && hitInfo.dst < closestHit.dst) {
                        closestHit = hitInfo;
                        closestHit.material = sphere.material;
                    }
                }


                //for (int i = 0; i < NumMeshes; i++) {
                //    MeshInfo meshInfo = AllMeshInfo[i];
                //    if (!RayBoundingBox(ray, meshInfo.boundsMin, meshInfo.boundsMax))continue;
                //    for (int j = 0; j < meshInfo.numTriangles; j++) {
                //        Triangle tri = Triangles[meshInfo.firstTriangleIndex + j];
                //        HitInfo hitInfo = RayTriangle(ray, tri);
                //        if (hitInfo.didHit && hitInfo.dst < closestHit.dst) {
                //            closestHit = hitInfo;
                //            closestHit.material = meshInfo.material;
                //        }
                //    }
                //}
                int stack[60];
                int stackPtr = 0;
                stack[stackPtr++] = NumMeshes - 1;
                while (stackPtr > 0){
                    int nodeIndex = stack[--stackPtr];
                    MeshInfo meshInfo = AllMeshInfo[nodeIndex];
                    if (!RayBoundingBox(ray, meshInfo.bound.boundsMin,meshInfo.bound.boundsMax))
                        continue;
                    if(meshInfo.triangleIndex != -1){
                        Triangle tri = Triangles[meshInfo.triangleIndex];
                        HitInfo hitInfo = RayTriangle(ray, tri);
                        if (hitInfo.didHit && hitInfo.dst < closestHit.dst) {
                            closestHit = hitInfo;
                            closestHit.material = tri.material;
                        }
                    }else{
                        stack[stackPtr++] = meshInfo.left;
                        stack[stackPtr++] = meshInfo.right;
                    }
                }

                return closestHit;
            }

            int MaxBounce;
            int NumRaysPerPixel;

            float3 PathTracingNormal(Ray ray, uint rngState){
                float3 res = float3(0, 0, 0);
                float3 throughput = float3(1, 1, 1);
                HitInfo hit;
                

                
                for (int bounce = 0; bounce < MaxBounce; bounce++) {
                    hit = BVHCalculateRayCollision(ray);

                    if (hit.didHit) {
                        RayTracingMaterial material = hit.material;

                        bool isSpecularBounce = material.specularProbability >= RandomValue(rngState);
                        
                        float3 diffuseDir = CosineWeightedHemisphereSample(rngState);
                        diffuseDir = normalize(TangentToWorld(diffuseDir, hit.normal));
                        float3 specularDir = reflect(ray.dir, hit.normal);
                        ray.dir = normalize(lerp(diffuseDir, specularDir, material.smoothness * isSpecularBounce));
                        ray.origin = dot(ray.dir, hit.normal) < 0 ? hit.hitPoint - hit.normal * 0.00001 : hit.hitPoint + hit.normal * 0.00001;

                        float3 emittedLight = material.emissionColour * material.emissionStrength;
                        res += emittedLight * throughput;
                        throughput *= lerp(material.colour, material.specularColour, isSpecularBounce);
                    
                        float prob = max(throughput.r, max(throughput.g, throughput.b));
                        if (RandomValue(rngState) > prob) {
                            break;
                        }
                        throughput *= 1.0f / prob;
                    }else{
                        res += GetEnvironmentLight(ray) * throughput;
                        break;
                    }
                }
                return res;
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

                float3 res = float3(0,0,0);
                for(int i = 0; i < NumRaysPerPixel; i++){
                    res += PathTracingNormal(ray, rngState);
                }
                if(NumRaysPerPixel > 0)
                    res = res / NumRaysPerPixel;
                return float4(res , 1);
            }
            ENDCG
        }
    }
}
