using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class RayTracedSphere : MonoBehaviour
{
    [SerializeField, HideInInspector] bool materialInitFlag;
    [Header("Configurable Properties")]
    [Tooltip("半径大小")]
    public float radius = 1.0f;

    [Tooltip("显示颜色")]
    public RayTracingMaterial material;
}
