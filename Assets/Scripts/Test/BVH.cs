using System.Collections;
using System.Collections.Generic;
using System.ComponentModel.Design.Serialization;
using System.Linq;
using Unity.VisualScripting;
using Unity.VisualScripting.FullSerializer;
using UnityEditor.Experimental.GraphView;
using UnityEngine;
using static BVHAccel;

[ExecuteAlways, ImageEffectAllowedInSceneView]
public class BVH : MonoBehaviour
{
    List<Triangle> triangles;
    [SerializeField] BVHAccel bvh;
    [SerializeField] int trianglesCount;

    RayTracedMesh[] meshObjects;

    void OnDrawGizmos()
    {
        meshObjects = FindObjectsOfType<RayTracedMesh>();
        if (meshObjects.Length == 0) return;

        triangles ??= new List<Triangle>();
        triangles.Clear();

        for (int i = 0; i < meshObjects.Length; i++)
        {
            triangles.AddRange(meshObjects[i].ExtractWorldTriangles());
        }
        bvh ??= new BVHAccel();
        bvh.Init();
        var triIndex = Enumerable.Range(0, triangles.Count).ToList();
        bvh.recursiveBuild(triangles, triIndex);
        foreach (BVHBuildNode node in bvh.roots)
        {

            DrawBound(node.bound, Color.red);
        }
        trianglesCount = triangles.Count;
    }

    void DrawBound(AABB aabb, Color color) {
        Gizmos.color = color;  // 设置Gizmos的颜色
        // 计算AABB的8个顶点
        Vector3[] vertices = new Vector3[8];
        vertices[0] = new Vector3(aabb.boundsMin.x, aabb.boundsMin.y, aabb.boundsMin.z);
        vertices[1] = new Vector3(aabb.boundsMax.x, aabb.boundsMin.y, aabb.boundsMin.z);
        vertices[2] = new Vector3(aabb.boundsMax.x, aabb.boundsMin.y, aabb.boundsMax.z);
        vertices[3] = new Vector3(aabb.boundsMin.x, aabb.boundsMin.y, aabb.boundsMax.z);
        vertices[4] = new Vector3(aabb.boundsMin.x, aabb.boundsMax.y, aabb.boundsMin.z);
        vertices[5] = new Vector3(aabb.boundsMax.x, aabb.boundsMax.y, aabb.boundsMin.z);
        vertices[6] = new Vector3(aabb.boundsMax.x, aabb.boundsMax.y, aabb.boundsMax.z);
        vertices[7] = new Vector3(aabb.boundsMin.x, aabb.boundsMax.y, aabb.boundsMax.z);

        // 绘制AABB的12条边
        Gizmos.DrawLine(vertices[0], vertices[1]);
        Gizmos.DrawLine(vertices[1], vertices[2]);
        Gizmos.DrawLine(vertices[2], vertices[3]);
        Gizmos.DrawLine(vertices[3], vertices[0]);

        Gizmos.DrawLine(vertices[4], vertices[5]);
        Gizmos.DrawLine(vertices[5], vertices[6]);
        Gizmos.DrawLine(vertices[6], vertices[7]);
        Gizmos.DrawLine(vertices[7], vertices[4]);

        Gizmos.DrawLine(vertices[0], vertices[4]);
        Gizmos.DrawLine(vertices[1], vertices[5]);
        Gizmos.DrawLine(vertices[2], vertices[6]);
        Gizmos.DrawLine(vertices[3], vertices[7]);
    }
}
