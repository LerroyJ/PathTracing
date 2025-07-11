using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[System.Serializable]
public struct BVHBuildNode
{
    public AABB bound;
    public int left;
    public int right;
    public int triangleIndex;
    public int thisIndex;
}

//public struct MeshInfo
//{
//    public int firstTriangleIndex;
//    public int numTriangles;
//    public Vector3 boundsMin;
//    public Vector3 boundsMax;
//    public RayTracingMaterial material;

//    public MeshInfo(int firstTriangleIndex, int numTriangles, Vector3 boundsMin, Vector3 boundsMax, RayTracingMaterial material)
//    {
//        this.firstTriangleIndex = firstTriangleIndex;
//        this.numTriangles = numTriangles;
//        this.boundsMin = boundsMin;
//        this.boundsMax = boundsMax;
//        this.material = material;
//    }
//}
