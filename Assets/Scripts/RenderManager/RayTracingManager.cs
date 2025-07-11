// PathTracingRenderer.cs
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using static UnityEngine.Mathf;

[System.Serializable]
public struct EnvironmentSettings
{
    public bool enabled;
    public Color groundColour;
    public Color skyColourHorizon;
    public Color skyColourZenith;
    public float sunFocus;
    public float sunIntensity;
}

[ExecuteAlways,ImageEffectAllowedInSceneView]
public class RayTracingManager : MonoBehaviour
{
    
    [SerializeField] bool useShaderInSceneView;
    [SerializeField] Shader pathTracingShaer;
    [SerializeField] Shader accumulateShader;
    [SerializeField] EnvironmentSettings environmentSettings;

    [SerializeField] int numRenderedFrames;
    [SerializeField] int maxBounce = 2;
    [SerializeField] int numRaysPerPixel = 1;

    Material rayTracingMaterial;
    Material accumulateMaterial;
    RenderTexture resultTexture;

    [Header("Scene")]
    public GameObject[] sphereObjects;
    public GameObject[] lightObjects;
    ComputeBuffer sphereBuffer;
    ComputeBuffer triangleBuffer;
    ComputeBuffer meshInfoBuffer;
    ComputeBuffer lightsBuffer;
    ComputeBuffer areasBuffer;

    BVHAccel bvh;
    List<Triangle> triangles;

    [Header("Temp")]
    bool reload = true;
    void Start()
    {
        numRenderedFrames = 0;
    }

    void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        bool isSceneCam = Camera.current.name == "SceneCamera";
        if (isSceneCam)
        {
            if (useShaderInSceneView)
            {
                InitFrame();
                Graphics.Blit(null, dest, rayTracingMaterial);
            }
            else
            {
                Graphics.Blit(src, dest);
            }
        }
        else {
            InitFrameOnce();
            RenderTexture prevFrameCopy = RenderTexture.GetTemporary(src.width, src.height, 0, RenderTextureFormat.ARGBFloat);
            Graphics.Blit(resultTexture, prevFrameCopy);

            rayTracingMaterial.SetInt("Frame", numRenderedFrames);
            RenderTexture currentFrameCopy = RenderTexture.GetTemporary(src.width, src.height, 0, RenderTextureFormat.ARGBFloat);
            Graphics.Blit(null, currentFrameCopy, rayTracingMaterial);

            accumulateMaterial.SetInt("_Frame", numRenderedFrames);
            accumulateMaterial.SetTexture("_PrevFrame", prevFrameCopy);
            Graphics.Blit(currentFrameCopy, resultTexture, accumulateMaterial);

            Graphics.Blit(resultTexture, dest);

            RenderTexture.ReleaseTemporary(currentFrameCopy);
            RenderTexture.ReleaseTemporary(prevFrameCopy);
            numRenderedFrames += Application.isPlaying ? 1 : 0;
        }
    }

    void InitFrameOnce() {
        if(reload)
            InitFrame();
        reload = false;
    }

    void InitFrame() {
        ShaderHelper.InitMaterial(pathTracingShaer, ref rayTracingMaterial);
        ShaderHelper.InitMaterial(accumulateShader, ref accumulateMaterial);

        CreateTexture(ref resultTexture, Screen.width, Screen.height);

        UpdateCameraParams(Camera.current);
        CreateSphere();
        CreateMesh();
        CreateLight();
        ShaderParamsSetting();
    }

    void ShaderParamsSetting() {
        rayTracingMaterial.SetInt("MaxBounce", maxBounce);
        rayTracingMaterial.SetInt("NumRaysPerPixel", numRaysPerPixel);
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
        rayTracingMaterial.SetInteger("EnvironmentEnabled", environmentSettings.enabled ? 1 : 0);
        rayTracingMaterial.SetColor("GroundColour", environmentSettings.groundColour);
        rayTracingMaterial.SetColor("SkyColourHorizon", environmentSettings.skyColourHorizon);
        rayTracingMaterial.SetColor("SkyColourZenith", environmentSettings.skyColourZenith);
        rayTracingMaterial.SetFloat("SunFocus", environmentSettings.sunFocus);
        rayTracingMaterial.SetFloat("SunIntensity", environmentSettings.sunIntensity);
    }

    void CreateMesh() {
        RayTracedMesh[] meshObjects = FindObjectsOfType<RayTracedMesh>();
        if (meshObjects.Length == 0) return;
        triangles ??= new List<Triangle>();
        triangles.Clear();

        for (int i = 0; i < meshObjects.Length; i++)
        {
            List<Triangle> tris;
            tris = meshObjects[i].ExtractWorldTriangles();
            triangles.AddRange(tris);
        }
        bvh ??= new BVHAccel();
        bvh.Init();
        var triIndex = Enumerable.Range(0, triangles.Count).ToList();
        bvh.recursiveBuild(triangles, triIndex);
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

    void CreateTexture(ref RenderTexture resultTexture, int width, int height) {
        if (resultTexture == null || resultTexture.width != width || resultTexture.height != height)
        {
            if (resultTexture != null)
                resultTexture.Release();

            resultTexture = new RenderTexture(width, height, 0, RenderTextureFormat.ARGBFloat);
            resultTexture.Create();
        }
    }

    void OnDisable()
    {
        ShaderHelper.Release(sphereBuffer, triangleBuffer, meshInfoBuffer);
        ShaderHelper.Release(resultTexture);
        ShaderHelper.Release(areasBuffer, lightsBuffer);
    }
}

