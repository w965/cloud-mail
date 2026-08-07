# Public API 接口文档

本文档描述 Cloud Mail 对外提供的 Public API，包括公共 Token 获取、邮件列表查询和用户添加接口。

## 基本约定

- Base URL：`https://<你的域名>`
- API 前缀：`/api`
- 请求格式：`application/json`
- 除获取 Token 外，Public API 均需要在 `Authorization` 请求头中直接传入公共 Token。
- `Authorization` 的值不需要添加 `Bearer` 前缀。

公共接口的成功响应统一为：

```json
{
  "code": 200,
  "message": "success",
  "data": null
}
```

失败响应统一为：

```json
{
  "code": 401,
  "message": "错误信息"
}
```

客户端应以响应体中的 `code` 判断业务结果，不应只依赖 HTTP 状态码。

## 获取公共 Token

使用管理员邮箱和密码生成 Public API Token。

```text
POST /api/public/genToken
```

该接口不需要 `Authorization` 请求头。

### 请求参数

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | :---: | --- |
| `email` | string | 是 | 必须为环境变量 `admin` 配置的管理员邮箱 |
| `password` | string | 是 | 管理员密码 |

### 请求示例

```bash
curl -X POST 'https://mail.example.com/api/public/genToken' \
  -H 'Content-Type: application/json' \
  -d '{
    "email": "admin@example.com",
    "password": "your-password"
  }'
```

### 成功响应

```json
{
  "code": 200,
  "message": "success",
  "data": {
    "token": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  }
}
```

每次重新生成 Token 都会覆盖之前的公共 Token，旧 Token 随即失效。Token 应作为敏感信息保存，调用该接口时必须使用 HTTPS。

## 查询邮件列表

按照一个或多个可选条件查询邮件。多个查询条件同时传入时使用 `AND` 组合。

```text
POST /api/public/emailList
```

### 请求头

```text
Authorization: <public-token>
Content-Type: application/json
```

### 请求参数

| 字段 | 类型 | 必填 | 默认值 | 说明 |
| --- | --- | :---: | --- | --- |
| `toEmail` | string | 否 | - | 匹配 `toEmail` 字段，不区分大小写，使用 SQL `LIKE` 规则 |
| `recipientAddress` | string | 否 | - | 精确匹配任意 `recipient[].address`，不区分大小写，首尾空格会被忽略 |
| `sendEmail` | string | 否 | - | 匹配发件邮箱，不区分大小写，使用 SQL `LIKE` 规则 |
| `sendName` | string | 否 | - | 匹配发件人名称，不区分大小写，使用 SQL `LIKE` 规则 |
| `subject` | string | 否 | - | 匹配邮件主题，不区分大小写，使用 SQL `LIKE` 规则 |
| `content` | string | 否 | - | 匹配邮件 HTML 内容，不区分大小写，使用 SQL `LIKE` 规则 |
| `type` | number | 否 | - | 邮件类型：`0` 为收件，`1` 为发件 |
| `isDel` | number | 否 | - | 删除状态：`0` 为正常，`1` 为已删除 |
| `timeSort` | string | 否 | `desc` | 传 `asc` 时按邮件 ID 升序，其余值按降序 |
| `num` | number | 否 | `1` | 页码，从 `1` 开始 |
| `size` | number | 否 | `20` | 每页数量 |

`recipientAddress` 是可选参数。不传、传 `null` 或传空字符串时，不会增加收件人地址过滤条件。

`recipientAddress` 与 `toEmail` 含义不同：

- `recipientAddress` 匹配邮件头中完整的 `recipient` 数组，适用于发件记录、多收件人以及 `toEmail` 为空或与邮件头收件人不同的情况。
- `toEmail` 只匹配数据库中的 `to_email` 字段，不能替代 `recipientAddress`。

`toEmail`、`sendEmail`、`sendName`、`subject` 和 `content` 使用 SQL `LIKE`。如需模糊查询，需要由调用方显式传入 `%` 通配符，例如 `%example.com` 或 `%验证码%`。`recipientAddress` 为精确地址匹配，不支持通配符。

### 按收件人地址查询

```bash
curl -X POST 'https://mail.example.com/api/public/emailList' \
  -H 'Authorization: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' \
  -H 'Content-Type: application/json' \
  -d '{
    "recipientAddress": "recipient@example.com",
    "type": 1,
    "isDel": 0,
    "num": 1,
    "size": 20
  }'
```

### 按主题模糊查询

```bash
curl -X POST 'https://mail.example.com/api/public/emailList' \
  -H 'Authorization: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' \
  -H 'Content-Type: application/json' \
  -d '{
    "subject": "%验证码%",
    "timeSort": "desc"
  }'
```

### 成功响应

接口直接在 `data` 中返回邮件数组，不包含总记录数。

```json
{
  "code": 200,
  "message": "success",
  "data": [
    {
      "emailId": 10,
      "sendEmail": "sender@example.com",
      "sendName": "Sender",
      "subject": "Hello",
      "toEmail": "mailbox@example.com",
      "toName": "",
      "recipient": [
        {
          "address": "recipient@example.com",
          "name": "Recipient"
        }
      ],
      "cc": [],
      "bcc": [],
      "type": 0,
      "createTime": "2026-08-07 09:38:29",
      "content": "<div>Hello</div>",
      "text": "Hello",
      "isDel": 0
    }
  ]
}
```

### 响应字段

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `emailId` | number | 邮件 ID |
| `sendEmail` | string/null | 发件邮箱 |
| `sendName` | string/null | 发件人名称 |
| `subject` | string/null | 邮件主题 |
| `toEmail` | string | 数据库中的目标邮箱字段 |
| `toName` | string | 目标邮箱名称 |
| `recipient` | array | 收件人数组，元素包含 `address` 和 `name` |
| `cc` | array | 抄送人数组 |
| `bcc` | array | 密送人数组 |
| `type` | number | `0` 为收件，`1` 为发件 |
| `createTime` | string | 邮件创建时间 |
| `content` | string/null | HTML 正文 |
| `text` | string/null | 纯文本正文 |
| `isDel` | number | `0` 为正常，`1` 为已删除 |

## 添加用户

批量添加用户。该接口需要 Public API Token。

```text
POST /api/public/addUser
```

### 请求头

```text
Authorization: <public-token>
Content-Type: application/json
```

### 请求参数

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | :---: | --- |
| `list` | array | 是 | 待添加的用户数组；空数组会直接返回成功 |
| `list[].email` | string | 是 | 用户邮箱，域名必须包含在环境变量 `domain` 中 |
| `list[].password` | string | 否 | 用户密码；不传时由服务端生成随机密码 |
| `list[].roleName` | string | 否 | 角色名称；不传或角色不存在时使用默认角色 |

如果省略 `password`，当前接口不会在响应中返回服务端生成的随机密码，调用方应根据实际使用场景决定是否显式传入密码。

### 请求示例

```bash
curl -X POST 'https://mail.example.com/api/public/addUser' \
  -H 'Authorization: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' \
  -H 'Content-Type: application/json' \
  -d '{
    "list": [
      {
        "email": "user1@example.com",
        "password": "secure-password",
        "roleName": "默认用户"
      },
      {
        "email": "user2@example.com",
        "password": "secure-password"
      }
    ]
  }'
```

### 成功响应

```json
{
  "code": 200,
  "message": "success",
  "data": null
}
```

## 常见错误

| `code` | 场景 |
| --- | --- |
| `401` | Public Token 无效 |
| `501` | 参数或业务校验失败，例如管理员身份验证、邮箱格式、域名或用户状态不符合要求 |
| `502` | KV 或 D1 数据库未绑定 |
| `500` | 未分类的服务端错误 |

错误消息可能根据服务端语言配置返回中文或英文。

## 部署升级说明

`recipientAddress` 查询会优先使用 `email_recipient` 地址索引表。部署升级时，数据库初始化过程会完成以下操作：

1. 创建收件人索引表和复合索引。
2. 从已有邮件的全部 `recipient[].address` 回填历史数据。
3. 创建新增、修改和删除触发器，持续同步后续邮件数据。

仓库自带的 GitHub Actions 部署流程会在 Worker 发布后自动调用初始化接口。初始化完成前，`recipientAddress` 查询会暂时直接解析旧的 `recipient` JSON 数据，因此旧数据仍可查询；初始化完成后会自动使用索引。

如果使用其他部署流程，应在升级后调用一次：

```text
GET /api/init/<JWT_SECRET>
```

初始化成功时返回纯文本：

```text
success
```

`JWT_SECRET` 属于敏感信息，不应记录在公开日志、文档示例或客户端代码中。
