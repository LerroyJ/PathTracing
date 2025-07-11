Shader "Custom/WhittedStyleRayTracing"
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
                float kr;
                int bounce;
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

            struct Light {
                float3 position;
                float3 intensity;
            };
            StructuredBuffer<Light> Lights;
            int NumLights;

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

            // 三角形相交
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

            // fresnel系数计算
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

            // 暴力求解最近光线交点
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
                        closestHit.material.colour = float4(hitInfo.normal, 1);
                        closestHit.material.materialType = 2;
                    }
                }
                return closestHit;
            }

            // 一层BVH加速
            HitInfo OneBVHCalculateRayCollision(Ray ray) {
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

            // Whitted-Style Ray Tracing
            // 2 bounce
            float4 WSCastRay(Ray ray) {
                const int MAX_BOUNCE = 2;
                const int STACK_SIZE = 4;
                Ray stack[STACK_SIZE];
                int sp = 0;
                stack[sp++] = ray;
                float4 res = float4(0, 0, 0, 1);
                float kr;
                float3 ka = float3(0.005, 0.005, 0.005);
                float3 amb_light_intensity = float3(10, 10, 10);
                float3 ambient = amb_light_intensity * ka;
                while (sp > 0) {
                    Ray ray = stack[--sp];
                    HitInfo info = OneBVHCalculateRayCollision(ray);
                    if (info.didHit) {
                        switch (info.material.materialType) {
                        case 0:
                            if (ray.bounce < MAX_BOUNCE) {
                                kr = fresnel(ray.dir, info.normal, 1.5);
                                Ray reflectionRay;
                                float3 reflection_Direction = normalize(reflect(ray.dir, info.normal));

                                float3 reflectionRay_Orig = (dot(reflection_Direction, info.normal) < 0) ?
                                    info.hitPoint - info.normal * 0.00001 :
                                    info.hitPoint + info.normal * 0.00001;

                                reflectionRay.dir = reflection_Direction;
                                reflectionRay.origin = reflectionRay_Orig;
                                reflectionRay.bounce = ray.bounce + 1;
                                reflectionRay.kr = kr * ray.kr;
                                stack[sp++] = reflectionRay;
                            }
                            break;
                        case 1:
                            if (ray.bounce < MAX_BOUNCE) {
                                kr = fresnel(ray.dir, info.normal, 3);
                                Ray reflectionRay, refractionRay;
                                float3 reflection_Direction = normalize(reflect(ray.dir, info.normal));

                                float3 reflectionRay_Orig = (dot(reflection_Direction, info.normal) < 0) ?
                                    info.hitPoint - info.normal * 0.00001 :
                                    info.hitPoint + info.normal * 0.00001;

                                float3 refraction_Direction = normalize(refract(ray.dir, info.normal, 0.6667));

                                float3 refractionRay_Orig = (dot(refraction_Direction, info.normal) < 0) ?
                                    info.hitPoint - info.normal * 0.00001 :
                                    info.hitPoint + info.normal * 0.00001;

                                reflectionRay.dir = reflection_Direction;
                                reflectionRay.origin = reflectionRay_Orig;
                                reflectionRay.bounce = ray.bounce + 1;
                                reflectionRay.kr = kr * ray.kr;
                                stack[sp++] = reflectionRay;

                                refractionRay.dir = refraction_Direction;
                                refractionRay.origin = refractionRay_Orig;
                                refractionRay.bounce = ray.bounce + 1;
                                refractionRay.kr = (1 - kr) * ray.kr;
                                stack[sp++] = refractionRay;
                            }
                            break;
                        default:
                            float3 lightAmt, specularColor;
                            float3 ks = float3(0.7937, 0.7937, 0.7937);
                            float3 shadowPointOrig = dot(ray.dir, info.normal) < 0 ? info.hitPoint + info.normal * 0.00001 : info.hitPoint - info.normal * 0.00001;
                            for (int i = 0; i < NumLights; i++) {
                                float3 lightDir = Lights[i].position - info.hitPoint;
                                float light_Distance_2 = dot(lightDir, lightDir);
                                lightDir = normalize(lightDir);
                                float LdotN = max(0.f, dot(lightDir, info.normal));
                                Ray light_ray;
                                light_ray.dir = lightDir;
                                light_ray.origin = shadowPointOrig;
                                HitInfo shadow_res = OneBVHCalculateRayCollision(light_ray);
                                bool inShadow = shadow_res.didHit && (light_Distance_2 > shadow_res.dst * shadow_res.dst) && shadow_res.material.materialType == 2;
                                lightAmt += inShadow ? 0 : LdotN * (Lights[i].intensity / light_Distance_2) * info.material.colour.xyz;
                                float3 reflection_Direction = reflect(-lightDir, info.normal);
                                specularColor += inShadow ? 0 : pow(max(0.f, -dot(reflection_Direction, ray.dir)),
                                    150) * (Lights[i].intensity / light_Distance_2) * ks;
                            }
                            res += float4(lightAmt + specularColor + ambient, 1) * ray.kr;
                            break;
                        }
                    }
                }
                return res;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float3 viewPointLocal = float3(i.uv - 0.5,1) * ViewParams;
                float3 viewPoint = mul(CamLocalToWorldMatrix, float4(viewPointLocal, 1));

                Ray ray;
                ray.origin = _WorldSpaceCameraPos;
                ray.dir = normalize(viewPoint - ray.origin);
                ray.bounce = 0;
                ray.kr = 1;

                return WSCastRay(ray);
            }
            ENDCG
        }
    }
}
