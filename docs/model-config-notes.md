# OpenClaw 模型配置指南

本文档记录如何在 OpenClaw 中配置大模型提供商（以火山引擎为例）。

## 支持的模型提供商

OpenClaw 内置支持以下模型提供商：

| 提供商 | Provider ID | 环境变量 | 示例模型 |
|--------|-------------|----------|----------|
| OpenAI | `openai` | `OPENAI_API_KEY` | `openai/gpt-5.4` |
| Anthropic | `anthropic` | `ANTHROPIC_API_KEY` | `anthropic/claude-opus-4-6` |
| Google Gemini | `google` | `GEMINI_API_KEY` | `google/gemini-3.1-pro-preview` |
| 火山引擎 | `volcengine` | `VOLCANO_ENGINE_API_KEY` | `volcengine/doubao-seed-1-8-251228` |
| BytePlus | `byteplus` | `BYTEPLUS_API_KEY` | `byteplus/seed-1-8-251228` |
| Moonshot (Kimi) | `moonshot` | `MOONSHOT_API_KEY` | `moonshot/kimi-k2.5` |
| OpenRouter | `openrouter` | `OPENROUTER_API_KEY` | `openrouter/anthropic/claude-sonnet-4-5` |

## 火山引擎配置

### 获取 API Key

1. 登录 [火山引擎控制台](https://console.volcengine.com/)
2. 进入 **火山方舟** 产品
3. 在 **API Key 管理** 中创建密钥

### 可用模型

**通用模型 (`volcengine`)：**

- `volcengine/doubao-seed-1-8-251228` (Doubao Seed 1.8)
- `volcengine/doubao-seed-code-preview-251028` (代码模型)
- `volcengine/kimi-k2-5-260127` (Kimi K2.5)
- `volcengine/glm-4-7-251222` (GLM 4.7)
- `volcengine/deepseek-v3-2-251201` (DeepSeek V3.2 128K)

**代码模型 (`volcengine-plan`)：**

- `volcengine-plan/ark-code-latest`
- `volcengine-plan/doubao-seed-code`
- `volcengine-plan/kimi-k2.5`

## UI 配置步骤

### 步骤 1：添加 API Key

1. 打开 Gateway UI：http://127.0.0.1:18789
2. 如果提示 **pairing required**，需要先批准设备配对
3. 点击顶部导航栏的 **Config**
4. 在左侧菜单点击 **Environment**
5. 展开 **Environment Variable Overrides**
6. 点击 **Add Entry**
7. 填写：
   - **Key**: `VOLCANO_ENGINE_API_KEY`
   - **Value**: 你的火山引擎 API Key
8. 点击 **Save** 保存

### 步骤 2：设置默认模型

1. 在 Config 页面，点击左侧 **Agents**
2. 展开 **Agent Defaults** 部分
3. 找到 **Model** 相关设置
4. 在 Primary Model 中填入：`volcengine/doubao-seed-1-8-251228`
5. 点击 **Save** 保存
6. 点击 **Apply** 或 **Update** 应用更改

### 步骤 3（可选）：使用 Raw 模式编辑

如果 Form 模式无法编辑某些字段：

1. 点击 **Raw** 按钮切换到 JSON5 编辑模式
2. 找到 `agents.defaults` 部分
3. 添加或修改 `model` 配置：

```json5
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "volcengine/doubao-seed-1-8-251228"
      }
    }
  }
}
```

4. 点击 **Save** 保存
5. 重启 Gateway 使配置生效

## 设备配对

首次从浏览器访问 Gateway 时需要配对：

1. 访问 Gateway UI，会看到 **pairing required** 提示
2. 在终端执行：

```bash
# Docker 部署
docker exec openclaw-gateway node dist/index.js devices list
docker exec openclaw-gateway node dist/index.js devices approve <requestId>

# 本地部署
openclaw devices list
openclaw devices approve <requestId>
```

3. 刷新浏览器页面

配对后，浏览器会存储凭证，后续访问无需再输入 token。

## 验证配置

### 查看日志确认模型

```bash
docker logs openclaw-gateway --tail 20
```

成功配置后会显示：

```
[gateway] agent model: volcengine/doubao-seed-1-8-251228
```

### 在 Chat 页面测试

1. 打开 http://127.0.0.1:18789
2. 在 Chat 输入框发送测试消息
3. 确认模型正常响应

## 故障排除

### API Key 未生效

1. 确认 API Key 已保存（在 Raw 模式下显示为 `__OPENCLAW_REDACTED__`）
2. 重启 Gateway：`docker restart openclaw-gateway`

### 模型不可用

1. 确认模型 ID 正确（格式：`provider/model-name`）
2. 确认 API Key 有权限访问该模型
3. 查看日志排查错误：`docker logs openclaw-gateway`

### UI 显示 "Schema unavailable"

1. 确认已完成设备配对
2. 刷新页面或清除浏览器缓存
3. 使用带 token 的 URL 访问：`http://127.0.0.1:18789#token=<your-token>`

## 配置文件位置

- **Docker 部署**: `~/.openclaw/openclaw.json`（挂载到容器的 `/home/node/.openclaw/openclaw.json`）
- **本地部署**: `~/.openclaw/openclaw.json`

配置示例：

```json5
{
  "env": {
    "vars": {
      "VOLCANO_ENGINE_API_KEY": "your-api-key"
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "volcengine/doubao-seed-1-8-251228"
      }
    }
  }
}
```
