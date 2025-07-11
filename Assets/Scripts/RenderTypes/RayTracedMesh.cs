using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class RayTracedMesh : MonoBehaviour
{
    [Header("Settings")]
    public RayTracingMaterial material;
    //public int trisPerMesh = 100;
    [Header("Info")]
    public MeshFilter meshFilter;
    public int triangleCount;
    List<Triangle> localTriangles;

    void OnValidate() {
        if (meshFilter == null) {
            meshFilter = GetComponent<MeshFilter>();
        }
        triangleCount = meshFilter.sharedMesh.triangles.Length / 3;
    }

    // 最简单的分组，以数量分组，未考虑空间关系
    //public List<MeshInfo> GenerateMeshInfo(int preIndex)
    //{
    //    int numMeshes = Mathf.CeilToInt((float)localTriangles.Count / (float)trisPerMesh);
    //    List<MeshInfo> meshList = new List<MeshInfo>();
    //    for (int meshIndex = 0; meshIndex < numMeshes; meshIndex++)
    //    {
    //        int firstTriangleIndex = meshIndex * trisPerMesh;
    //        int triCount = Mathf.Min(localTriangles.Count - firstTriangleIndex, trisPerMesh);
    //        Vector3 boundsMin = Vector3.one * float.MaxValue;
    //        Vector3 boundsMax = Vector3.one * float.MinValue;

    //        for (int i = 0; i < triCount; i++)
    //        {
    //            Triangle tri = localTriangles[firstTriangleIndex + i];
    //            boundsMin = Vector3.Min(boundsMin, tri.posA);
    //            boundsMin = Vector3.Min(boundsMin, tri.posB);
    //            boundsMin = Vector3.Min(boundsMin, tri.posC);
    //            boundsMax = Vector3.Max(boundsMax, tri.posA);
    //            boundsMax = Vector3.Max(boundsMax, tri.posB);
    //            boundsMax = Vector3.Max(boundsMax, tri.posC);
    //        }
    //        meshList.Add(new MeshInfo(firstTriangleIndex + preIndex, triCount, boundsMin, boundsMax, material));
    //    }
    //    return meshList;
    //}
    public List<Triangle> ExtractWorldTriangles()
    {
        localTriangles = new List<Triangle>();
        Mesh mesh = meshFilter.sharedMesh;
        Transform transform = meshFilter.transform;

        Vector3[] vertices = mesh.vertices;
        Vector3[] normals = mesh.normals;
        int[] triangles = mesh.triangles;

        for (int i = 0; i < triangles.Length; i += 3)
        {
            int i0 = triangles[i];
            int i1 = triangles[i + 1];
            int i2 = triangles[i + 2];

            Vector3 p0 = transform.TransformPoint(vertices[i0]);
            Vector3 p1 = transform.TransformPoint(vertices[i1]);
            Vector3 p2 = transform.TransformPoint(vertices[i2]);

            Vector3 n0 = transform.TransformDirection(normals[i0]);
            Vector3 n1 = transform.TransformDirection(normals[i1]);
            Vector3 n2 = transform.TransformDirection(normals[i2]);
            Triangle tri = new Triangle(p0, p1, p2, n0, n1, n2, material);
            localTriangles.Add(tri);
        }
        return localTriangles;
    }
}
