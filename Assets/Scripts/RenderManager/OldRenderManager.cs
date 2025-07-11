// PathTracingRenderer.cs
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using static UnityEngine.Mathf;

[ExecuteAlways,ImageEffectAllowedInSceneView]
public class OldRenderManager : MonoBehaviour
{
    
    [SerializeField] bool useShaderInSceneView;
    [SerializeField] Shader pathTracingShaer;

    [SerializeField] int maxBounce = 2;
    [SerializeField] int sceneTriangles;

    Material rayTracingMaterial;


    struct Sphere
    {
        public Vector3 position;
        public float radius; 
        public RayTracingMaterial material;
    };

    struct Light {
        public Vector3 position;
        public Vector3 intensity;
    };

    [Header("Scene")]
    public GameObject[] sphereObjects;
    public GameObject[] lightObjects;
    ComputeBuffer sphereBuffer;
    ComputeBuffer lightBuffer;
    ComputeBuffer triangleBuffer;
    ComputeBuffer meshInfoBuffer;

    BVHAccel bvh;
    List<Triangle> triangles;

    void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        bool isSceneCam = Camera.current.name == "SceneCamera";
        if (!isSceneCam || useShaderInSceneView)
        {
            InitFrame();
            Graphics.Blit(null, dest, rayTracingMaterial);
        }
        else
        {
            Graphics.Blit(src, dest);
        }
    }

    void InitFrame() {
        ShaderHelper.InitMaterial(pathTracingShaer, ref rayTracingMaterial);
        UpdateCameraParams(Camera.current);
        CreateSphere();
        CreateMesh();
        CreateLight();
        ShaderParamsSetting();
    }

    void ShaderParamsSetting() {
        rayTracingMaterial.SetInt("MaxBounce", maxBounce);
    }

    void CreateSphere()
    {
        Sphere[] spheres = new Sphere[sphereObjects.Length];
        for (int i = 0; i < spheres.Length; i++)
        {
            RayTracedSphere sphere = sphereObjects[i].GetComponent<RayTracedSphere>();
            Color c = sphere.material.colour;
            spheres[i].material.colour = new Vector4(c.r, c.g, c.b, c.a);
            spheres[i].position = sphere.transform.position;
            spheres[i].radius = sphere.radius;
            spheres[i].material.flag = sphere.material.flag;
        }

        ShaderHelper.CreateStructuredBuffer(ref sphereBuffer, spheres);
        rayTracingMaterial.SetBuffer("Spheres", sphereBuffer);
        rayTracingMaterial.SetInt("NumSpheres", spheres.Length);
    }


    void CreateLight() {
        Light[] lights = new Light[lightObjects.Length];
        for (int i = 0; i < lights.Length; i++)
        {
            LightObject light = lightObjects[i].GetComponent<LightObject>();
            lights[i].position = light.transform.position;
            lights[i].intensity = light.intensity * Vector3.one;
        }
        ShaderHelper.CreateStructuredBuffer(ref lightBuffer, lights);
        rayTracingMaterial.SetBuffer("Lights", lightBuffer);
        rayTracingMaterial.SetInt("NumLights", lights.Length);
    }

    void CreateMesh() {
        RayTracedMesh[] meshObjects = FindObjectsOfType<RayTracedMesh>();
        if (meshObjects.Length == 0) return;
        triangles ??= new List<Triangle>();
        triangles.Clear();

        for (int i = 0; i < meshObjects.Length; i++)
        {
            triangles.AddRange(meshObjects[i].ExtractWorldTriangles());
        }

        if (bvh == null || !Application.isPlaying) {
            bvh ??= new BVHAccel();
            bvh.Init();
            var triIndex = Enumerable.Range(0, triangles.Count).ToList();
            bvh.recursiveBuild(triangles, triIndex);
        }
        ShaderHelper.CreateStructuredBuffer(ref triangleBuffer, triangles);
        ShaderHelper.CreateStructuredBuffer(ref meshInfoBuffer, bvh.roots);
        rayTracingMaterial.SetBuffer("Triangles", triangleBuffer);
        rayTracingMaterial.SetInt("NumTriangles", triangles.Count);
        rayTracingMaterial.SetBuffer("AllMeshInfo", meshInfoBuffer);
        rayTracingMaterial.SetInt("NumMeshes", bvh.roots.Count);
    }


    void UpdateCameraParams(Camera camera) {
        float planeHeight = camera.nearClipPlane * Tan(camera.fieldOfView * 0.5f * Deg2Rad) * 2;
        float planeWidth = planeHeight * camera.aspect;

        rayTracingMaterial.SetVector("ViewParams",new Vector3 (planeWidth,planeHeight,camera.nearClipPlane));
        rayTracingMaterial.SetMatrix("CamLocalToWorldMatrix",camera.transform.localToWorldMatrix);
    }

    void OnDisable()
    {
        ShaderHelper.Release(sphereBuffer, triangleBuffer, meshInfoBuffer);
        ShaderHelper.Release(lightBuffer);
    }
}

