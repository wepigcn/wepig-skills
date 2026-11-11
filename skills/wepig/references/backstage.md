# backstage 后台服务参考

backstage 服务提供组织结构相关接口，用于查询集团、公司、猪场等组织信息。

## 关键字列表

| 关键字 | 对应端点 | 说明 |
| --- | --- | --- |
| platform, 集团 | backstage_platform_list | 获取集团列表 |
| company, 公司 | backstage_company_list | 获取公司列表 |
| company_group, 公司分组 | backstage_company_group_list | 公司分组列表 |
| farm, 猪场 | backstage_farm_list | 获取猪场列表 |
| farm_group, 猪场分组 | backstage_farm_group_list | 猪场分组列表 |
| org, 组织结构 | backstage_org_limit_list | 组织结构列表 |

## 接口详情

### backstage_platform_list（集团列表）

查询集团信息。

**常用参数：**
- `name`：集团名称（模糊搜索）
- `code`：编码
- `valid`：是否有效
- `offset`、`limit`：分页参数

**示例：**
```bash
# 查询所有集团
wepig call backstage_platform_list limit=100

# 按名称搜索集团
wepig call backstage_platform_list name=微猪 limit=10
```

### backstage_company_list（公司列表）

查询公司信息。

**常用参数：**
- `name`：公司名称/编码（模糊搜索）
- `parent_id`：父级公司 ID
- `parent_ids`：父级公司 ID 列表（逗号分隔）
- `company_group_id`：区域公司 ID
- `begin_date`、`end_date`：日期范围
- `offset`、`limit`：分页参数

**示例：**
```bash
# 查询所有公司
wepig call backstage_company_list limit=100

# 按名称搜索公司
wepig call backstage_company_list name=XX公司 limit=10

# 查询指定父级下的公司
wepig call backstage_company_list parent_id=123 limit=50
```

### backstage_company_group_list（公司分组列表）

查询公司分组信息。

**常用参数：**
- `offset`、`limit`：分页参数

**示例：**
```bash
# 查询所有公司分组
wepig call backstage_company_group_list limit=100
```

### backstage_farm_list（猪场列表）

查询猪场信息。

**常用参数：**
- `name`：猪场名称/编码（模糊搜索）
- `company_id`：公司 ID
- `company_ids`：公司 ID 列表（逗号分隔）
- `parent_id`：父级 ID
- `farm_type`：猪场类型
- `farm_status`：猪场状态
- `begin_date`、`end_date`：日期范围
- `offset`、`limit`：分页参数

**示例：**
```bash
# 查询所有猪场
wepig call backstage_farm_list limit=100

# 按名称搜索猪场
wepig call backstage_farm_list name=XX猪场 limit=10

# 查询指定公司下的猪场
wepig call backstage_farm_list company_id=456 limit=50

# 按猪场类型和状态查询
wepig call backstage_farm_list farm_type=育肥场 farm_status=营业中 limit=50
```

### backstage_farm_group_list（猪场分组列表）

查询猪场分组信息。

**常用参数：**
- `name`：分组名称/编码（模糊搜索）
- `group_id`：分组 ID
- `parent_id`：父级 ID
- `top_group_id`：上级公司 ID 列表
- `begin_date`、`end_date`：日期范围
- `offset`、`limit`：分页参数

**示例：**
```bash
# 查询所有猪场分组
wepig call backstage_farm_group_list limit=100

# 按名称搜索猪场分组
wepig call backstage_farm_group_list name=华北区 limit=10

# 查询指定分组
wepig call backstage_farm_group_list group_id=789 limit=10
```

### backstage_org_limit_list（组织结构列表）

查询完整的组织结构树。

**常用参数：**
- `min_node_type`：最小节点类型（默认 `farm`，即最小展示到猪场级别）
- `ret_type`：返回类型（默认 `0`）

**示例：**
```bash
# 查询完整的组织结构树
wepig call backstage_org_limit_list

# 指定最小节点类型
wepig call backstage_org_limit_list min_node_type=company
```

## 使用说明

1. **分页**：所有列表接口均支持 `offset` 和 `limit` 分页参数，默认 `limit=10`，建议根据实际需求调整。

2. **模糊搜索**：`name` 参数支持模糊匹配，可以用于搜索集团、公司、猪场等名称或编码。

3. **层级关系**：
   - 集团（platform）→ 公司（company）→ 猪场（farm）
   - 通过 `parent_id`、`company_id` 等参数查询下级组织

4. **日期范围**：部分接口支持 `begin_date`、`end_date` 参数，格式为 `YYYY-MM-DD`。

5. **响应字段**：接口返回的组织信息通常包含：
   - `id`：实体 ID
   - `name`：名称
   - `code`：编码
   - `parent_id`：父级 ID
   - 其他业务字段（如地址、联系方式、状态等）
