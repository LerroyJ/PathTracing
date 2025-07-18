# PathTracting
一个基于 Unity 引擎实现的简洁路径追踪渲染器，支持多种材质模型、反射光线追踪、多帧累积与 BVH 加速结构，适用于图形学学习与实验研究。
<img width="2046" height="1172" alt="ray" src="https://github.com/user-attachments/assets/ace25618-2fb7-4991-89de-06451bcee1ba" />

## 特性功能

-  **渲染流程框架**：使用 C# 构建完整的路径追踪控制流程，统一采样数据传输与 Shader 调度管理
-  **BSDF 材质系统**：实现BSDF采样与评估（支持漫反射、镜面反射），实现不同材质类型（如玻璃、金属等）
-  **光线反弹机制**：支持余弦加权半球采样、多次间接反射与俄罗斯轮盘赌路径终止策略
-  **图像累积收敛**：逐帧图像累积，提升渲染稳定性，减少随机噪点
-  **BVH 加速结构**：基于层次包围盒构建空间加速结构，显著提升场景求交效率
![bvh](https://github.com/user-attachments/assets/91dcf455-1b11-4e8a-8e2b-13cdf2369db2)

## 开始
### unity版本
2021.3.20及以上

### 运行
克隆或下载存储库后，在 Unity 中打开根项目文件夹，然后按 Play 按钮。
