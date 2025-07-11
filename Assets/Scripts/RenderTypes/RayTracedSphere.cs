using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class RayTracedSphere : MonoBehaviour
{
    [SerializeField, HideInInspector] bool materialInitFlag;
    [Header("Configurable Properties")]
    [Tooltip("�뾶��С")]
    public float radius = 1.0f;

    [Tooltip("��ʾ��ɫ")]
    public RayTracingMaterial material;
}
