using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[System.Serializable]
public struct Triangle
{
    public Vector3 posA, posB, posC;
    public Vector3 normalA, normalB, normalC;
    public RayTracingMaterial material;

    public Triangle(Vector3 a, Vector3 b, Vector3 c, Vector3 na, Vector3 nb, Vector3 nc, RayTracingMaterial mat)
    {
        posA = a; posB = b; posC = c; normalA = na; normalB = nb; normalC = nc;material = mat;
    }

    public AABB GetBound()
    {
        return new AABB(Vector3.Min(posA, Vector3.Min(posB,posC)), Vector3.Max(posA, Vector3.Max(posB, posC)));

    }
}
