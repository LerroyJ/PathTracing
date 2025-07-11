Shader "Custom/Triangle"{
	SubShader{
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
				o.pos = UnityObjectToClipPos(v.vertex); // 转换为屏幕坐标
				o.uv = v.texcoord;
				return o;
			}

			// Ray
			float3 ViewParams;
			float4x4 CamLocalToWorldMatrix;
			
			struct Ray {
				float3 origin;
				float3 dir;
			};

			struct RayTracingMaterial {
				float4 colour;
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
				float area;
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

			// 暴力求解光线最近交点
			HitInfo CalculateRayCollision(Ray ray) {
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

				for (int i = 0; i < NumTriangles; i++) {
					Triangle tri = Triangles[i];
					HitInfo hitInfo = RayTriangle(ray, tri);
					if (hitInfo.didHit && hitInfo.dst < closestHit.dst) {
						closestHit = hitInfo;
						closestHit.material = tri.material;
					}
				}
				return closestHit;
			}

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

			// Phong Shading
			float4 PhongShading(Ray ray, HitInfo info) {
				float3 res = float3(0, 0, 0);
				if (info.didHit) {
					float3 ka = float3(0.005, 0.005, 0.005);
					float3 ks = float3(0.7937, 0.7937, 0.7937);
					float3 amb_light_intensity = float3(10, 10, 10);
					for (int i = 0; i < NumLights; i++) {
						float3 kd = info.material.colour;
						float3 l_out = -ray.dir;
						float3 l_in = Lights[i].position - info.hitPoint;
						float3 h = normalize(normalize(l_in) + normalize(l_out));
						float r = dot(l_in, l_in);
						float3 ambient = amb_light_intensity * ka;
						float3 diffuse = kd * (Lights[i].intensity / r) * max(0, dot(info.normal, normalize(l_in)));
						float3 specular = ks * (Lights[i].intensity / r) * pow(max(0.0f, dot(info.normal, h)), 150);
						res += ambient + diffuse + specular;
					}
					return float4(res, 1);
				}
				return float4(res, 1);
			}

			float4 NormalShading(HitInfo info) {
				if (info.didHit) {
					return info.material.colour;
				}
				return float4(0, 0, 0, 1);
			}

			float4 frag(v2f i) : SV_Target
			{
				float3 viewPointLocal = float3(i.uv - 0.5,1) * ViewParams;
				float3 viewPoint = mul(CamLocalToWorldMatrix, float4(viewPointLocal, 1));

				Ray ray;
				ray.origin = _WorldSpaceCameraPos;
				ray.dir = normalize(viewPoint - ray.origin);
				HitInfo info = BVHCalculateRayCollision(ray);
				return PhongShading(ray, info);
			}
			ENDCG
		}
	}
}