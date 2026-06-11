# MoonCRDTKit Roadmap

## 0.1.x 基础稳定期

- 完成向量时钟、LWW Register、G-Counter、PN-Counter、OR-Set 和同步摘要。
- 保持 CLI 演示、README、CHANGELOG 和协作模板完整。
- 用确定性测试覆盖公开 API 的典型路径和合并路径。

## 0.2.x 协同结构扩展

- 增加 MV-Register，保留并发写入的多值结果。
- 增加 Map CRDT，用多个 CRDT 字段组合对象状态。
- 增加更完整的 OR-Set tombstone 压缩策略。

## 0.3.x 同步协议示例

- 增加状态摘要交换示例。
- 增加离线表单和协同任务列表示例。
- 增加冲突可视化和变更日志导出。

## 长期方向

- 保持核心库零平台依赖。
- 补充 benchmark 和随机合并一致性测试。
- 沉淀为 MoonBit 离线优先应用和边缘同步工具的基础组件。
