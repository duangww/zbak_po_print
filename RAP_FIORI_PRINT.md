# RAP + Fiori Elements 扩展 + SmartForms 打印（成功案例）

采购订单打印：GUI `ZMM_R002` 改为 Fiori。SmartForms `ZMM_R002_03B` / `ZMM_R002_02` 不变。  
**已验证可用**：Fiori Elements List Report + 自定义工具栏按钮 + RAP Custom Entity 出 PDF + Action 写打印日志。

前端工程：`C:\Users\bak\Desktop\zbak_po_print`（应用 ID `zbakpoprint`）  
后端源码：本仓库 `abap/`  
ADT 建对象顺序仍见 `STEP_BY_STEP.md`。

---

## 1. 结论（以后同类需求按这个拆）

| 能力                           | 谁做                                                               | 不要怎么做                                                               |
| ------------------------------ | ------------------------------------------------------------------ | ------------------------------------------------------------------------ |
| 列表、筛选、列                 | RAP CDS `@UI.*` + Custom Entity Query                              | 不要 Freestyle 手写整页（除非放弃注解）                                  |
| 打印预览 / 真正出 PDF          | Custom Entity `PoPdf` 查询 → `GET_PDF`（`GETOTF` + `CONVERT_OTF`） | 不要指望 `#FOR_ACTION` 自动下载 XSTRING；不要在 RAP Action 里 `SSF_OPEN` |
| 浏览器里看 PDF                 | `webapp/ext/CustomActions.js`：取流 → Blob → `window.open`         | ADT Preview 不加载扩展，测不了预览                                       |
| 确认打印（写 `ZMM_PRINT_LOG`） | BDEF Action `confirmPrint`，**只在 saver `save()` 里写库**         | 不要在 `FOR MODIFY` 里 `COMMIT WORK` / `NUMBER_GET_NEXT`                 |
| 工具栏按钮顺序、单选启用       | `manifest.json` 自定义 Action                                      | 不要用 CDS `#FOR_ACTION` 做预览（Elements 不会把 Action 结果变成下载）   |

Fiori **没有** SAP GUI 的打印对话框。物理打印 = 浏览器打开 PDF 后选打印机。

---

## 2. 运行时分工

```
筛选 / 列表
  Fiori Elements FilterBar + Table
    → OData V4 GET /PoPrint
    → ZCL_MM_R002_RAP_HANDLER
    → ZCL_MM_R002_SERVICE=>GET_PO_DATA

打印预览（单选）
  CustomActions.previewPdf
    → GET /PoPdf?$filter=ebelns eq '…' and formid eq 'ZMM_R002_03B'
    → ZCL_MM_R002_PDF_HANDLER   ← 断点打 GET_PDF 要打在这里调用的服务类
    → GET_PDF（SSF GETOTF → PDF）
    → Blob → 新标签预览

打印（可多选）
  CustomActions.confirmPrint
    ① 同上出 PDF，新标签打开并尝试 window.print()
    ② 成功后 POST confirmPrint
    ③ ZBP confirmPrint 只缓冲单号
    ④ saver save() → WRITE_LOG（无 COMMIT）
```

**不要**在 `confirmPrint` 的 `FOR MODIFY` 里调 `GET_PDF`：SmartForms / `COMMIT` 会 `BEHAVIOR_ILLEGAL_STATEMENT`，整个 `$batch` 失败。

PDF Handler **只认 `$filter`**，不认键预览 `PoPdf(ebelns='…',formid='…')/pdf`（后者易 400）。

---

## 3. 后端对象（保留）

| 对象                             | 作用                                                 |
| -------------------------------- | ---------------------------------------------------- |
| `ZCL_MM_R002_SERVICE`            | 取数、`GET_PDF`、`WRITE_LOG`                         |
| `ZCE_MM_R002` / Handler          | 列表 Custom Entity                                   |
| `ZCE_MM_R002_PDF` / PDF Handler  | PDF 流 Custom Entity，alias `PoPdf`                  |
| `ZA_MM_R002_PDF`                 | `previewPdf` Action 的 result（可留；UI 预览不靠它） |
| BDEF `ZCE_MM_R002`               | `previewPdf`（可选）、`confirmPrint`                 |
| `ZBP_CE_MM_R002`                 | Action 缓冲 + `save()` 写日志                        |
| `ZUI_MM_R002` / `ZUI_MM_R002_O4` | OData V4 UI，需 Publish                              |

`ZA_MM_R002_IN` 已无用（旧静态 Action 参数），可不建。

列表 CDS 要点：

- 不要给 `previewPdf` / `confirmPrint` 加 `@UI.lineItem #FOR_ACTION`（自定义按钮会重复）
- `noshow : abap_boolean` → 筛选栏复选框
- **不要** `@Consumption.filter.defaultValue: 'true'`（布尔默认值会把 `$metadata` 弄成「简单值没有类型」）
- 默认勾选放前端 `webapp/annotations/annotation.xml` 的 `Common.FilterDefaultValue` + `<Bool>true</Bool>`

`WRITE_LOG`：RAP 调用必须 `iv_commit = abap_false`；GUI 程序仍可默认 `COMMIT`。

---

## 4. 前端（Fiori generator + 扩展）

向导选 **List Report Page**，主实体 `PoPrint`，OData V4，**Generate Annotations = No**（后端已有 `@UI`）。  
Namespace 空则应用 ID 为 `zbakpoprint`。

### 4.1 自定义按钮（`manifest.json`）

注解按钮永远排在自定义按钮前面，所以要 **隐藏 CDS `confirmPrint`**，两个按钮都走扩展，才能「打印预览 | 打印」：

```json
"PreviewPdf": {
  "press": "zbakpoprint.ext.CustomActions.previewPdf",
  "enabled": "zbakpoprint.ext.CustomActions.singleSelection",
  "requiresSelection": true,
  "text": "{i18n>actionPreview}"
},
"ConfirmPrint": {
  "press": "zbakpoprint.ext.CustomActions.confirmPrint",
  "requiresSelection": true,
  "text": "{i18n>actionPrint}"
}
```

`ListReportExt.controller.js` **不要**再注册：`controllerName` 会去加载 `*.controller.js`，文件名不对就 404。预览列已隐藏，不需要给链接加 `_blank`。

### 4.2 `ext/CustomActions.js`

- 预览：`$filter` 查 `PoPdf` → 转 Blob → `window.open`（不要 `<a download>`）
- 打印：先出 PDF（可多单，`ebelns` 用 `;` 拼接）→ 再 `editFlow.invokeAction(confirmPrint)`
- `pdf` 是 `Edm.Stream`：不要把 Action 返回值当 Base64 `atob`，也不要 GET 不可寻址的 `…/previewPdf(…)/pdf`

### 4.3 本地预览

```bash
cd C:\Users\bak\Desktop\zbak_po_print
npm run start-noflp
```

`ui5.yaml` 必须 `ignoreCertErrors: true`，并带 `client: '300'`。  
内网证书校验失败时，代理会把 `$metadata` 伪装成 HTTP 500。

`npm start` 打开 `test/flp.html#app-preview` 可能重复创建 Component（`application-app-preview-component`）。测功能用 `start-noflp`。

---

## 5. 踩坑对照（本案例实测）

| 现象                                         | 原因                                        | 处理                           |
| -------------------------------------------- | ------------------------------------------- | ------------------------------ |
| ADT Preview 点 Action 不下 PDF               | Elements 不处理 Action 的 XSTRING           | 扩展 JS + `PoPdf` 查询         |
| `#ATTACHMENT` 改了仍不下                     | 只对 GET 流有效，对 Action POST 无效        | 同上                           |
| `atob` 编码错误                              | Stream/二进制被当成 Base64                  | 按类型转换；失败再 `$filter`   |
| HTTP 400 拉 PDF                              | 键预览 `/PoPdf(…)/pdf`；Handler 只认 filter | `bindList` + `$filter`         |
| `BEHAVIOR_ILLEGAL_STATEMENT` / `$batch` 失败 | Action 里 `COMMIT` / 取号                   | 缓冲到 `save()`，RAP 不 COMMIT |
| 点打印不进 `GET_PDF`                         | `confirmPrint` 只写日志                     | 打印按钮先查 `PoPdf`           |
| `$metadata`「简单值没有类型」                | 布尔字段 CDS `filter.defaultValue: 'true'`  | 删 CDS 默认值，改本地注解      |
| 筛选空着 `noshow` 仍是 X                     | Handler「没条件就当 X」                     | 只在勾选 true/X 时过滤         |
| 工具栏「打印」在「预览」前                   | 注解 Action 优先                            | 隐藏注解按钮，两个都自定义     |
| `ListReportExt.controller.js` 404            | `controllerName` 强制 `.controller.js`      | 不需要则从 manifest 去掉       |
| 本地 `$metadata` 500                         | Node 不信任内网证书                         | `ignoreCertErrors: true`       |

---

## 6. 验收

1. 筛选：复选框「不显示已打印」；勾选才过滤，不勾显示已打印。
2. 勾一条 → **打印预览**：新标签打开 PDF，**不写**日志。
3. 勾一条或多条 → **打印**：进 `GET_PDF`，打开 PDF / 浏览器打印框，成功后写 `ZMM_PRINT_LOG`，「已打印」刷新。
4. 对照 GUI 同一张 PO 的版式。
5. 特殊模板 `ZMM_R002_02` 仍非主路径（`formid` 可再扩）。

---

## 7. 断点

| 你要点的按钮          | 断点位置                                              |
| --------------------- | ----------------------------------------------------- |
| 查询列表              | `ZCL_MM_R002_RAP_HANDLER` → `GET_PO_DATA`             |
| 打印预览 / 打印出 PDF | `ZCL_MM_R002_SERVICE=>GET_PDF`（由 PDF Handler 调用） |
| 打印写日志            | `ZBP` 的 `save` → `WRITE_LOG`，不是 `GET_PDF`         |
