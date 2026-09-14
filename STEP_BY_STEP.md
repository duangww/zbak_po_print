# ZMM_R002 → Fiori 手工创建步骤

包建议：`Z002`（与原程序同一包）。SmartForms `ZMM_R002_03B` / `ZMM_R002_02` 不要改。

**已跑通的 RAP + Fiori Elements 扩展 + 打印方案**见 **[RAP_FIORI_PRINT.md](./RAP_FIORI_PRINT.md)**（架构、扩展按钮、踩坑、验收）。本文只保留 ADT 建对象顺序。

本地源码：

- ABAP：`abap/`
- 已验证前端：`C:\Users\bak\Desktop\zbak_po_print`（`zbakpoprint`）
- 本仓库 `webapp/` 为早期草稿，不要当部署源

---

## 进度（2026-09-14）

- 后端 RAP Custom Entity + `PoPdf` 出 PDF + `confirmPrint` 写日志已通
- 前端用 VS Code Fiori generator：List Report Page，主实体 `PoPrint`
- 预览/打印走 `ext/CustomActions.js`；ADT Preview 测列表即可，测 PDF 必须跑 UI5 工程
- 打印成功：先 `GET_PDF`（PoPdf `$filter`），再 `save()` 写 `ZMM_PRINT_LOG`

---

## 进度（2026-09-10 下班存档）

方案已定：Fiori 列表 + SmartForms 出 PDF 预览/打印，原程序 `ZMM_R002` 先保留。

### 今天已完成

- 本地全部源码已写好（`abap/` + `webapp/`）
- DEV 已开始手工创建对象
- 已修 2 个激活问题（源码已改，以本地文件为准再贴一次）：
  1. `ZCL_MM_R002_SERVICE`：不要用 `TSFOTL`。OTF 行结构是 `ITCOO`，`SSF_CLOSE` 的 `otfdata` 是 `TSFOTF`
  2. `ZCL_MM_R002_RAP_HANDLER`：泛型表不能 `APPEND VALUE #( sign = ... )`，已改成 `CREATE DATA` + 组件赋值

### 明天从这里继续

1. 用本地最新文件重新粘贴并激活 `ZCL_MM_R002_RAP_HANDLER`
2. 按下面「激活顺序」从 **第 4.2 步** 接着做：
   - `ZCL_MM_R002_PDF_HANDLER`
   - 激活两个 Custom Entity
   - BDEF + `ZBP_CE_MM_R002`
   - Service Definition / Binding Publish
   - UI5 上传 + FLP

ADT 里已建到哪、激活没有，以系统为准；本地文件始终是最新正确版本。

---

## 0. 创建前准备

1. 准备一个开发运输请求。
2. ADT 连 **DEV**。
3. 确认 SmartForms `ZMM_R002_03B` 能在 GUI 程序 `ZMM_R002` 打出样张（Fiori 只换入口）。
4. 确认号段对象 `ZPRINTLOG`、表 `ZMM_PRINT_LOG` 可用。

激活顺序必须按下面走，依赖反了会激活失败。

---

## 1. 创建服务类 `ZCL_MM_R002_SERVICE`

ADT：`New` → `ABAP Class`

| 项          | 值                    |
| ----------- | --------------------- |
| Name        | `ZCL_MM_R002_SERVICE` |
| Description | PO打印服务（无GUI）   |
| Package     | `Z002`                |

把 `abap/zcl_mm_r002_service.clas.abap` **整份**粘进 `source/main`（含 `DEFINITION` + `IMPLEMENTATION`）。

三个 include（Local Types / Definitions / Implementations）保持空或只留注释。

激活。0 error 即可（warning 可忽略）。

---

## 2. 创建抽象实体 `ZA_MM_R002_IN`

ADT：`New` → `Data Definition`，类型选 **Abstract Entity**（不要 View）。

| 项          | 值              |
| ----------- | --------------- |
| Name        | `ZA_MM_R002_IN` |
| Description | PO打印确认参数  |

粘贴 `abap/za_mm_r002_in.ddls`，激活。

---

## 3. 创建 Custom Entity

### 3.1 `ZCE_MM_R002`（列表）

`New` → `Data Definition` → 模板选 **Define custom entity with parameters** 后把内容整段换成 `abap/zce_mm_r002.ddls`。

此时 Query 类还没有，**先保存不激活**，或激活报找不到类也没关系，第 4 步补上再激活。

### 3.2 `ZCE_MM_R002_PDF`（PDF）

同样创建 `ZCE_MM_R002_PDF`，粘贴 `abap/zce_mm_r002_pdf.ddls`。

---

## 4. 创建两个 RAP Handler 类

### 4.1 `ZCL_MM_R002_RAP_HANDLER`

粘贴 `abap/zcl_mm_r002_rap_handler.clas.abap`，激活。

### 4.2 `ZCL_MM_R002_PDF_HANDLER`

粘贴 `abap/zcl_mm_r002_pdf_handler.clas.abap`，激活。

然后回到第 3 步两个 DDLS **再激活**。

---

## 5. 创建行为定义（BDEF）

### 5.1 列表（带确认打印 Action）

在 `ZCE_MM_R002` 上右键 → `New Behavior Definition`

- Implementation type：`Unmanaged`
- 名称保持 `ZCE_MM_R002`

把内容换成 `abap/zce_mm_r002.bdef`。

保存时 ADT 会提示创建行为实现类 `ZBP_CE_MM_R002` → **同意创建**。

### 5.2 行为实现类 `ZBP_CE_MM_R002`

1. 类的 `source/main` 用 `abap/zbp_ce_mm_r002.clas.abap`（空壳即可）。
2. 打开 **Local Types / Class Implementation（本地实现）**：
   - 向导生成的 `lsc_zce_mm_r002`（saver）**保留**，方法体保持空即可，不要删。
   - `lhc_poprint` 用 `abap/zbp_ce_mm_r002.clas.locals_imp.abap`（文件里已含 handler + 空 saver）。
3. 先激活 `ZBP_CE_MM_R002`，再激活 BDEF `ZCE_MM_R002`。

如果 `static action confirmPrint` 激活失败：把 BDEF 改成与盈利指标一样的空块（见文末「降级」），UI 仍能预览 PDF，只是不写日志。

### 5.3 PDF 实体 BDEF

对 `ZCE_MM_R002_PDF` 新建 BDEF，粘贴 `abap/zce_mm_r002_pdf.bdef`（空 unmanaged，不要 implementation class），激活。

---

## 6. 服务定义 + 绑定 + 发布

### 6.1 Service Definition `ZUI_MM_R002`

`New` → `Service Definition`，粘贴 `abap/zui_mm_r002.srvd`，激活。

### 6.2 Service Binding `ZUI_MM_R002_O4`

`New` → `Service Binding`

| 项           | 值               |
| ------------ | ---------------- |
| Name         | `ZUI_MM_R002_O4` |
| Binding Type | `OData V4 - UI`  |
| Service      | `ZUI_MM_R002`    |

激活后点 **Publish**。

发布成功后，绑定编辑器里会显示服务 URL，类似：

```text
/sap/opu/odata4/sap/zui_mm_r002_o4/srvd/sap/zui_mm_r002/0001/
```

**把这段 URL 复制下来**，去改 `webapp/manifest.json` 的 `sap.app.dataSources.mainService.uri`（若不一致）。

有的系统是 `srvd_a2x`，以绑定画面为准。

### 6.3 ADT Preview 只测查询

Binding **Preview** 用来确认列表、过滤即可。  
Preview **不会**加载 `webapp` 扩展，因此链接会顶掉当前页；CDS 也没有 `@HTML5.linkTarget`。

要新开窗口预览：部署第 7 步应用。

---

## 7. 前端应用

不要用本仓库旧 `webapp/` 部署。用已验证工程 `C:\Users\bak\Desktop\zbak_po_print`。

向导、manifest 自定义按钮、`CustomActions.js`、证书与 `npm run start-noflp` 见 [RAP_FIORI_PRINT.md](./RAP_FIORI_PRINT.md)。

部署时上传该工程的 `webapp/`（含 `ext/CustomActions.js`、`annotations/annotation.xml`）。Component ID：`zbakpoprint`。

### 7.1 BSP 应用

1. 创建 BSP：`ZMM_R002_UI`，包 `Z002`
2. `/UI5/UI5_REPOSITORY_LOAD` 上传整个 `webapp/`
3. 确认有：`Component.js`、`manifest.json`、`ext/controller/ListReportExt.js`、`i18n/`

### 7.2 改服务地址

打开已上传的 `manifest.json`，`uri` 必须与第 6.2 步 Publish 后的 URL **完全一致**（含末尾 `/`）。

### 7.3 单测 URL（绕过 FLP）

```text
https://<主机>:<端口>/sap/bc/ui5_ui5/sap/zmm_r002_ui/index.html
```

若 `sap-ui-core.js` 404，把 `webapp/index.html` 里 bootstrap 的 `src` 改成你们系统实际 UI5 路径，例如：

```text
/sap/bc/ui5_ui5/1/resources/sap-ui-core.js
```

FLP 磁贴走 Component，不依赖 index.html。

---

## 8. 做 FLP 磁贴

1. `/UI2/FLPD_CUST` 建目录、组。
2. 目标映射：
   - Semantic Object：`ZBAK_PO_PRINT`（或你们规范名）
   - Action：`display`
   - Application Type：`SAPUI5 Fiori App`
   - SAPUI5 Component：`zbakpoprint`
   - URL：`/sap/bc/ui5_ui5/sap/zmm_r002_ui`
3. 磁贴标题：PO打印。
4. 角色加目录，用户打 PFCG 角色后清缓存：`/UI2/INVALIDATE_CLIENT_CACHES`。

---

## 9. 前台怎么用（验收）

1. 输入订单号或日期区间，勾选「不显示已打印」（默认勾），点 **查询**。
2. 勾选一行或多行 → **预览**：弹出 PDF，**不写** `ZMM_PRINT_LOG`。
3. **打印**：弹出同一 PDF（浏览器里打印），并调用 `confirmPrint` 写日志；列表刷新后「已打印」应有勾。
4. **特殊模板**：走 SmartForm `ZMM_R002_02`（设备表仍为空，与现 GUI 一致）。

对照 GUI `ZMM_R002` 同一张 PO，核对页眉、单价、税额、行项目。

---

## 对象清单（打勾）

| 顺序 | 对象                      | 类型               | 本地文件                                              |
| ---- | ------------------------- | ------------------ | ----------------------------------------------------- |
| 1    | `ZCL_MM_R002_SERVICE`     | CLAS               | `zcl_mm_r002_service.clas.abap`                       |
| 2    | `ZA_MM_R002_IN`           | DDLS abstract      | `za_mm_r002_in.ddls`                                  |
| 3    | `ZCE_MM_R002`             | DDLS custom entity | `zce_mm_r002.ddls`                                    |
| 4    | `ZCE_MM_R002_PDF`         | DDLS custom entity | `zce_mm_r002_pdf.ddls`                                |
| 5    | `ZCL_MM_R002_RAP_HANDLER` | CLAS               | `zcl_mm_r002_rap_handler.clas.abap`                   |
| 6    | `ZCL_MM_R002_PDF_HANDLER` | CLAS               | `zcl_mm_r002_pdf_handler.clas.abap`                   |
| 7    | `ZBP_CE_MM_R002`          | CLAS for behavior  | `zbp_ce_mm_r002.clas.abap` + `*.clas.locals_imp.abap` |
| 8    | `ZCE_MM_R002`             | BDEF               | `zce_mm_r002.bdef`                                    |
| 9    | `ZCE_MM_R002_PDF`         | BDEF               | `zce_mm_r002_pdf.bdef`                                |
| 10   | `ZUI_MM_R002`             | SRVD               | `zui_mm_r002.srvd`                                    |
| 11   | `ZUI_MM_R002_O4`          | SRVB               | ADT 里建，无本地文件                                  |
| 12   | `zbakpoprint` UI5         | Fiori Elements     | `C:\Users\bak\Desktop\zbak_po_print`                  |

---

## 常见激活问题

| 现象                                       | 处理                                                                             |
| ------------------------------------------ | -------------------------------------------------------------------------------- |
| `TSFOTL` 不存在                            | 已改：`STANDARD TABLE OF itcoo`；`CONVERT_OTF` 的 `OTF` 用 `ITCOO`               |
| `APPEND VALUE #(...) TO ct_range` 激活失败 | 已改：泛型表用 `CREATE DATA LIKE LINE OF` 再 APPEND                              |
| CE 报 `query.implementedBy` 类不存在       | 先激 Handler 再激 DDLS                                                           |
| BDEF 报类 `ZBP_CE_MM_R002` 不存在          | 先让 ADT 生成行为类，再激活 BDEF                                                 |
| `static action` 语法错                     | 用文末降级空 BDEF，UI 预览仍可用                                                 |
| `CONVERT_OTF` 没有 `BIN_FILE`              | 把 `get_pdf` 里改成 `CONVERT_OTF_2_PDF`，或只收 `LINES` 再转 xstring             |
| PDF `message` = 找不到表单                 | 系统里 Form 名确认是 `ZMM_R002_03B`                                              |
| 预览空白 / OTF 空                          | 输出设备 `LP01` 是否存在；可改服务类里 `ls_out-tddest`                           |
| `confirmPrint` 嵌套 COMMIT dump            | Action 里不要写库/COMMIT；放到 `save()`，`WRITE_LOG` 传 `iv_commit = abap_false` |
| `$metadata`「简单值没有类型」              | 布尔字段不要 CDS `@Consumption.filter.defaultValue: 'true'`                      |
| 点打印不进 `GET_PDF`                       | 打印须先查 `PoPdf`；`confirmPrint` 只写日志                                      |
| Binding URL 404                            | 未 Publish，或 manifest 的 `srvd` / `srvd_a2x` 与系统不一致                      |
| 列表一查询就全表扫                         | 至少输入订单号或日期，与 GUI 相同                                                |

---

## 降级（只要预览、暂不写日志）

`ZCE_MM_R002` 的 BDEF 改成：

```
unmanaged;

define behavior for ZCE_MM_R002 alias PoPrint
{
}
```

不要 `ZBP_CE_MM_R002`。前台点打印仍能出 PDF；写日志会提示失败，可忽略。
