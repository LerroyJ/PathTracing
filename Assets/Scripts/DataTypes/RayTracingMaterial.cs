using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[System.Serializable]
public struct RayTracingMaterial
{
    public enum MaterialFlag
    {
        None,
        InvisibleLight,
        Diffuse,
        Mirror
    }

    public Color colour;
    public Color emissionColour;
    public Color specularColour;
    public float emissionStrength;
    [Range(0, 1)] public float smoothness;
    [Range(0, 1)] public float specularProbability;
    public MaterialFlag flag;

    public void SetDefaultValues()
    {
        colour = Color.white;
        emissionColour = Color.white;
        emissionStrength = 0;
        specularColour = Color.white;
        smoothness = 0;
        specularProbability = 1;
    }
}
