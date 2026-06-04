# 文档云 ONLYOFFICE 问题修复任务梳理

> 适用范围：文档云在线编辑、预览、模板、字体、公文版式、批注、页码、产品化裁剪与授权控制。
>
> 重要边界：多人协作人数控制建议通过产品后端 License 与会话控制实现，不做破解类改造。

## 一、总体结论

当前问题分为四类：

1. **环境类问题**：字体缺失、字体缓存未刷新、浏览器缩放、服务器转换环境不一致。
2. **文档兼容类问题**：奇偶页页码、复杂节、镜像页边距、落款掉页、红头样式差异。
3. **产品体验类问题**：模板复用、样式快捷套用、批注常显、段落布局快捷设置。
4. **二开裁剪类问题**：logo 替换、多余按钮隐藏、默认配置、License 校验、协作人数控制。

优先处理顺序必须是：

```text
字体环境统一 -> 文档模板标准化 -> 打开配置统一 -> 产品功能补强 -> 源码二开裁剪
```

如果字体环境未统一，红头样式、落款、页码、页边距等问题会反复出现，不能直接进入源码修改。

---

## 二、BUG 修复任务清单

| 编号 | 问题 | 优先级 | 处理方式 | 是否需要改 ONLYOFFICE 源码 | 责任模块 |
|---|---|---:|---|---|---|
| BUG-01 | 无法导入样式模板，不能快捷复用样式 | P1 | 增加模板中心、公文排版助手 | 部分需要 | 业务前端/后端 |
| BUG-02 | 批注不能保持常显 | P2 | 默认开启评论能力，必要时二开右侧评论栏 | 可能需要 | ONLYOFFICE 前端 |
| BUG-03 | Word 页面版式怪异，左右留白不一致 | P0 | 字体、页边距、镜像页边距、节设置排查 | 一般不需要 | 环境/模板 |
| BUG-04 | 页边距单位只有磅，没有厘米 | P2 | 设置 zh-CN，必要时前端单位换算 | 可能需要 | ONLYOFFICE 前端 |
| BUG-05 | 无法拖拽快速设置段落布局 | P3 | 第一阶段用“公文排版助手”替代 | 需要，成本高 | 产品功能 |
| BUG-06 | 奇偶页页码设置不兼容 | P1 | 检测复杂页眉页脚、分节、奇偶页 | 可能需要 | 文档检测/ONLYOFFICE |
| BUG-07 | 文档落款展示不在同一页 | P1 | 字体统一、模板规范、段落分页控制 | 不建议 | 模板 |
| BUG-09 | 红头样式展示不一致 | P0 | 安装公文字体、统一红头模板 | 一般不需要 | 环境/模板 |
| BUG-10 | 在线字体和本地字体不一致 | P0 | 安装字体、刷新缓存、重启服务 | 不需要 | 环境 |

---

## 三、第一阶段：必须立即完成的任务

### 3.1 安装并挂载中文字体、公文字体

目标：解决在线字体与本地 Word 字体不一致、红头跑版、落款掉页、左右留白视觉不一致等问题。

必须准备字体：

```text
宋体
黑体
楷体
仿宋
仿宋_GB2312
楷体_GB2312
方正小标宋简体
Times New Roman
```

Docker 部署建议挂载：

```yaml
volumes:
  - /data/onlyoffice/fonts:/usr/share/fonts/truetype/custom
```

容器内执行：

```bash
fc-cache -fv
fc-list :lang=zh
supervisorctl restart all
```

验收标准：

```text
1. 红头标题不再换行、变形或变窄；
2. 正文行距接近本地 Word；
3. 落款不再因为字体替换掉页；
4. 在线预览与本地打开字体一致；
5. 页码位置不再明显偏移。
```

### 3.2 固化文档打开配置

必须统一配置：

```text
lang = zh-CN
region = zh-CN
comments = true
compactToolbar = false
feedback = false
help = false
plugins = false
chat = false
```

对应配置文件见：

```text
deploy/onlyoffice/document-editor-config.example.json
```

### 3.3 制作标准公文模板

建议至少内置：

```text
通知模板
请示模板
函模板
会议纪要模板
安全检查通报模板
红头文件模板
```

模板规范：

```text
标题：方正小标宋简体
正文：仿宋_GB2312
一级标题：黑体
二级标题：楷体_GB2312
正文行距：固定值 28 磅
首行缩进：2 字符
落款：使用无边框表格右对齐，不使用大量空格
页边距：上 3.7cm，下 3.5cm，左 2.8cm，右 2.6cm
```

---

## 四、第二阶段：产品功能补强

### 4.1 模板中心

接口建议：

```text
GET    /api/doc-template/list
POST   /api/doc-template/upload
POST   /api/doc-template/create-doc
GET    /api/doc-template/download/{id}
DELETE /api/doc-template/{id}
```

表结构建议：

```sql
CREATE TABLE doc_template (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
    template_name VARCHAR(200) NOT NULL COMMENT '模板名称',
    template_type VARCHAR(100) COMMENT '模板类型',
    file_id BIGINT NOT NULL COMMENT '模板文件ID',
    file_name VARCHAR(255) NOT NULL COMMENT '原始文件名',
    file_path VARCHAR(500) NOT NULL COMMENT '模板文件路径',
    enabled TINYINT DEFAULT 1 COMMENT '是否启用：1启用，0停用',
    sort_no INT DEFAULT 0 COMMENT '排序号',
    create_time DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间'
) COMMENT='文档模板表';
```

### 4.2 公文排版助手

建议提供按钮：

```text
一键正文格式
一键标题格式
一键落款格式
一键清理空行
一键设置页边距
一键设置首行缩进
```

第一阶段不要强行做拖拽标尺，成本高且容易影响 ONLYOFFICE 升级。

### 4.3 字体缺失检测

后端上传 docx 后检测：

```text
word/fontTable.xml
word/styles.xml
word/document.xml
```

如果文档使用字体未安装，提示：

```text
当前文档使用了服务器未安装字体，可能导致在线显示与本地 Word 不一致。
缺失字体：xxx、xxx。
```

---

## 五、第三阶段：需要改 ONLYOFFICE 源码或打补丁的事项

### 5.1 多余按钮隐藏

优先使用 editorConfig.customization 控制。

配置控制不了的按钮，再改 web-apps 前端源码。

参考补丁文件：

```text
patches/onlyoffice-custom-ui.patch
```

### 5.2 批注栏默认展示

先通过配置打开评论权限：

```json
{
  "document": {
    "permissions": {
      "comment": true,
      "review": true
    }
  }
}
```

如果仍不能满足“常显”，再改 documenteditor 右侧面板默认状态。

### 5.3 页边距单位显示为厘米

先通过配置：

```json
{
  "editorConfig": {
    "lang": "zh-CN",
    "region": "zh-CN"
  }
}
```

如果仍显示为磅，再在页面设置面板做 pt/cm 换算。

换算关系：

```text
1 cm = 28.3464567 pt
```

### 5.4 Logo 替换

优先替换外层业务系统 logo。

如必须替换 ONLYOFFICE 内部资源，需要修改 web-apps 的图片资源或构建产物。

---

## 六、License 与协作人数控制

### 6.1 License 校验位置

License 不建议写死在 ONLYOFFICE 源码中，应放在业务后端。

流程：

```text
用户打开文档
    ↓
业务后端校验 License
    ↓
校验通过：返回 ONLYOFFICE config
    ↓
校验失败：拒绝打开编辑器
```

### 6.2 协作人数控制

不做破解。由业务后端控制编辑会话。

逻辑：

```text
当前文档编辑人数 < 授权人数：edit
当前文档编辑人数 >= 授权人数：view
```

表结构：

```sql
CREATE TABLE doc_edit_session (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
    doc_id BIGINT NOT NULL COMMENT '文档ID',
    user_id BIGINT NOT NULL COMMENT '用户ID',
    user_name VARCHAR(100) COMMENT '用户名称',
    session_key VARCHAR(100) NOT NULL COMMENT '会话标识',
    edit_mode VARCHAR(20) DEFAULT 'edit' COMMENT '打开模式：edit/view',
    last_active_time DATETIME COMMENT '最后活跃时间',
    create_time DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    UNIQUE KEY uk_doc_user (doc_id, user_id)
) COMMENT='文档在线编辑会话表';
```

---

## 七、验收清单

### 7.1 P0 验收

```text
1. 在线字体与本地字体一致；
2. 红头样式展示一致；
3. 页面左右留白无明显异常；
4. 落款不再异常掉页；
5. 常用公文模板在线打开正常。
```

### 7.2 P1 验收

```text
1. 模板可上传；
2. 可从模板新建文档；
3. 文档保存回调正常；
4. 奇偶页页码复杂文档有兼容性提示；
5. 样式复用有可替代方案。
```

### 7.3 P2 验收

```text
1. 批注功能可用；
2. 多余按钮被隐藏；
3. Logo 完成替换；
4. License 校验生效；
5. 超出协作人数后自动只读。
```
