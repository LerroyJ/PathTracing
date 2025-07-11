using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

public class BVHAccel
{
    //public enum SplitMethod { NAIVE, SAH };
    //SplitMethod splitMethod1;
    public List<BVHBuildNode> roots;

    int globalIndex;
    public BVHAccel() {
        roots ??= new List<BVHBuildNode>();
    }

    public void Init() {
        if (roots.Count > 0) { 
            roots.Clear();
        }
        globalIndex = 0;
    }

    public BVHBuildNode recursiveBuild(List<Triangle> triangles, List<int> triIndex)
    {
        BVHBuildNode node = new BVHBuildNode();
        AABB bounds = new AABB(Vector3.one * float.MaxValue, Vector3.one * float.MinValue);
        for (int i = 0; i < triangles.Count; i++)
        {
            bounds = AABB.Union(bounds, triangles[i].GetBound());
        }
        if (triangles.Count == 1)
        {
            node.bound = bounds;
            node.left = -1;
            node.right = -1;
            node.triangleIndex = triIndex[0];
        }
        else if (triangles.Count == 2)
        {
            BVHBuildNode left = recursiveBuild(triangles.GetRange(0, 1), triIndex.GetRange(0,1));
            BVHBuildNode right = recursiveBuild(triangles.GetRange(1, 1), triIndex.GetRange(1, 1));
            node.bound = AABB.Union(left.bound, right.bound);
            node.left = left.thisIndex;
            node.right = right.thisIndex;
            node.triangleIndex = -1;
        }
        else {
            var compareIndex = Enumerable.Range(0, triangles.Count).ToList();
            AABB centroidBounds = new AABB(Vector3.one * float.MaxValue, Vector3.one * float.MinValue);
            for (int i = 0; i < triangles.Count; i++)
            {
                centroidBounds = AABB.Union(centroidBounds, triangles[i].GetBound().Centroid());
            }
            // max dim 0-x,1-y,2-z
            int dim = centroidBounds.maxExtent();
            
            switch (dim) {
                case 0:
                    compareIndex.Sort((i, j) => triangles[i].GetBound().Centroid().x.CompareTo(triangles[j].GetBound().Centroid().x));
                    triangles = compareIndex.Select(i => triangles[i]).ToList();
                    triIndex = compareIndex.Select(i => triIndex[i]).ToList();
                    break;
                case 1:
                    compareIndex.Sort((i, j) => triangles[i].GetBound().Centroid().y.CompareTo(triangles[j].GetBound().Centroid().y));
                    triangles = compareIndex.Select(i => triangles[i]).ToList();
                    triIndex = compareIndex.Select(i => triIndex[i]).ToList();
                    break;
                case 2:
                    compareIndex.Sort((i, j) => triangles[i].GetBound().Centroid().z.CompareTo(triangles[j].GetBound().Centroid().z));
                    triangles = compareIndex.Select(i => triangles[i]).ToList();
                    triIndex = compareIndex.Select(i => triIndex[i]).ToList();
                    break;
            }
            int middling = triangles.Count / 2;
            var leftTris = triangles.GetRange(0, middling);
            var rightTris = triangles.GetRange(middling, triangles.Count - middling);

            var left = recursiveBuild(leftTris, triIndex.GetRange(0, middling));
            var right = recursiveBuild(rightTris, triIndex.GetRange(middling, triangles.Count - middling));

            node.bound = AABB.Union(left.bound,right.bound);
            node.left = left.thisIndex;
            node.right = right.thisIndex;
            node.triangleIndex = -1;
        }
        node.thisIndex = globalIndex;
        roots.Add(node);
        globalIndex++;
        return node;
    }


}
