// 组织列表归一化：从 backstage_user_orgs 的返回值与 outputSchema 里定位组织数组。
// 网关的 outputSchema 由 pydantic 生成，数组可能被 anyOf/oneOf 包裹，这里统一处理。

export function normalizeOrgs(payload, outputSchema) {
  function locate(value, schema) {
    if (!schema) return null;
    const type = schema.type;
    if (type === "array" || (Array.isArray(type) && type.includes("array"))) {
      return Array.isArray(value) ? { value, items: schema.items } : null;
    }
    // pydantic v2 的 Optional[T] 会生成 anyOf/oneOf，数组类型可能被包在分支里。
    for (const branch of [...(schema.anyOf || []), ...(schema.oneOf || [])]) {
      const found = locate(value, branch);
      if (found) return found;
    }
    for (const [key, child] of Object.entries(schema?.properties || {})) {
      const found = locate(value?.[key], child);
      if (found) return found;
    }
    return null;
  }
  const collection = locate(payload, outputSchema);
  const properties = collection?.items?.properties;
  if (!Array.isArray(collection?.value) || !properties) {
    throw new Error("backstage_user_orgs 的 outputSchema 未定义组织数组及元素字段");
  }
  const typeKey = Object.keys(properties).find((key) => key === "org_type");
  const idKey = Object.keys(properties).find((key) => key === "org_id");
  const nameKey = Object.keys(properties).find((key) => key === "org_name" || key === "name");
  if (!typeKey || !idKey || !nameKey) throw new Error("backstage_user_orgs 的 outputSchema 缺少组织类型、ID 或名称字段");
  return collection.value.map((org) => ({
    org_type: org[typeKey],
    org_id: Number(org[idKey]),
    name: org[nameKey] || "",
  })).filter((org) => org.org_type && Number.isInteger(org.org_id) && org.org_id >= 0);
}
