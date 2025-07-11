using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[System.Serializable]
public struct AABB
{
    public Vector3 boundsMin;
    public Vector3 boundsMax;

    public AABB(Vector3 min, Vector3 max) {
        boundsMin = min; boundsMax = max;
    }

    public static AABB Union(AABB a, AABB b)
    {
        return new AABB(Vector3.Min(a.boundsMin, b.boundsMin),
           Vector3.Max(a.boundsMax, b.boundsMax));
    }

    public static AABB Union(AABB a, Vector3 b)
    {
        return new AABB(Vector3.Min(a.boundsMin, b),
           Vector3.Max(a.boundsMax, b));
    }

    public Vector3 Centroid() {
        return boundsMin * 0.5f + boundsMax * 0.5f;
    }

    public int maxExtent()
    {
        Vector3 d = boundsMax - boundsMin;
        if (d.x > d.y && d.x > d.z)
            return 0;
        else if (d.y > d.z)
            return 1;
        else
            return 2;
    }
}
