using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using static UnityEngine.Mathf;

public class ShaderHelper
{
    public static void InitMaterial(Shader shader, ref Material mat) { 
        if(mat == null || (mat.shader != shader && shader != null)) {
            if(shader == null)
            {
                shader = Shader.Find("Unlit/Texture");
            }
            mat = new Material(shader);
        }
    }

    public static void Release(ComputeBuffer buffer)
    {
        if (buffer != null)
        {
            buffer.Release();
        }
    }


    public static void Release(params ComputeBuffer[] buffers)
    {
        for (int i = 0; i < buffers.Length; i++)
        {
            Release(buffers[i]);
        }
    }

    public static void Release(RenderTexture tex)
    {
        if (tex != null)
        {
            tex.Release();
        }
    }

    // Create a compute buffer containing the given data (Note: data must be blittable)
    public static void CreateStructuredBuffer<T>(ref ComputeBuffer buffer, T[] data) where T : struct
    {
        // Cannot create 0 length buffer (not sure why?)
        int length = Max(1, data.Length);
        // The size (in bytes) of the given data type
        int stride = System.Runtime.InteropServices.Marshal.SizeOf(typeof(T));

        // If buffer is null, wrong size, etc., then we'll need to create a new one
        if (buffer == null || !buffer.IsValid() || buffer.count != length || buffer.stride != stride)
        {
            if (buffer != null) { buffer.Release(); }
            buffer = new ComputeBuffer(length, stride, ComputeBufferType.Structured);
        }

        buffer.SetData(data);
    }

    // Create a compute buffer containing the given data (Note: data must be blittable)
    public static void CreateStructuredBuffer<T>(ref ComputeBuffer buffer, List<T> data) where T : struct
    {
        // Cannot create 0 length buffer (not sure why?)
        int length = Max(1, data.Count);
        // The size (in bytes) of the given data type
        int stride = System.Runtime.InteropServices.Marshal.SizeOf(typeof(T));

        // If buffer is null, wrong size, etc., then we'll need to create a new one
        if (buffer == null || !buffer.IsValid() || buffer.count != length || buffer.stride != stride)
        {
            if (buffer != null) { buffer.Release(); }
            buffer = new ComputeBuffer(length, stride, ComputeBufferType.Structured);
        }

        buffer.SetData(data);
    }
}
