// locate()/normalizeOrgs 的回归测试：网关 outputSchema 的各种数组包装形态。
import assert from "node:assert/strict";
import test from "node:test";

import { normalizeOrgs } from "./orgs.mjs";

const ORG_ITEM = {
  type: "object",
  properties: {
    org_id: { type: "integer" },
    org_name: { type: "string" },
    org_type: { type: "string" },
    status: { type: "integer" },
  },
};

const ORG = { org_id: 16, org_name: "模拟猪场16", org_type: "FARM", status: 1 };
const EXPECTED = [{ org_type: "FARM", org_id: 16, name: "模拟猪场16" }];

function envelope(dataSchema) {
  return {
    type: "object",
    properties: {
      code: { anyOf: [{ type: "integer" }, { type: "null" }] },
      msg: { anyOf: [{ type: "string" }, { type: "null" }] },
      data: dataSchema,
    },
  };
}

test("anyOf 包裹的数组（pydantic Optional[List[T]]，线上实际形态）", () => {
  const schema = envelope({ anyOf: [{ type: "array", items: ORG_ITEM }, { type: "null" }] });
  assert.deepEqual(normalizeOrgs({ code: 0, msg: "success", data: [ORG] }, schema), EXPECTED);
});

test("oneOf 包裹的数组", () => {
  const schema = envelope({ oneOf: [{ type: "null" }, { type: "array", items: ORG_ITEM }] });
  assert.deepEqual(normalizeOrgs({ code: 0, msg: "success", data: [ORG] }, schema), EXPECTED);
});

test("type 为 [array, null] 的联合类型", () => {
  const schema = envelope({ type: ["array", "null"], items: ORG_ITEM });
  assert.deepEqual(normalizeOrgs({ code: 0, msg: "success", data: [ORG] }, schema), EXPECTED);
});

test("直接 type: array 的旧形态仍然可用", () => {
  const schema = envelope({ type: "array", items: ORG_ITEM });
  assert.deepEqual(normalizeOrgs({ code: 0, msg: "success", data: [ORG] }, schema), EXPECTED);
});

test("数组藏在深层对象属性里也能找到", () => {
  const schema = envelope({
    type: "object",
    properties: { result: { type: "object", properties: { list: { type: "array", items: ORG_ITEM } } } },
  });
  const payload = { code: 0, msg: "success", data: { result: { list: [ORG] } } };
  assert.deepEqual(normalizeOrgs(payload, schema), EXPECTED);
});

test("data 为 null 时抛 schema 缺失错误，而不是静默返回空列表", () => {
  const schema = envelope({ anyOf: [{ type: "array", items: ORG_ITEM }, { type: "null" }] });
  assert.throws(
    () => normalizeOrgs({ code: 0, msg: "success", data: null }, schema),
    /outputSchema 未定义组织数组及元素字段/,
  );
});

test("array 分支但实际值不是数组时不被误判", () => {
  const schema = envelope({ anyOf: [{ type: "array", items: ORG_ITEM }, { type: "null" }] });
  assert.throws(
    () => normalizeOrgs({ code: 0, msg: "success", data: { orgs: [ORG] } }, schema),
    /outputSchema 未定义组织数组及元素字段/,
  );
});

test("元素字段缺失时抛字段错误", () => {
  const schema = envelope({
    anyOf: [{ type: "array", items: { type: "object", properties: { org_id: { type: "integer" } } } }, { type: "null" }],
  });
  assert.throws(() => normalizeOrgs({ code: 0, msg: "success", data: [ORG] }, schema), /缺少组织类型、ID 或名称字段/);
});

test("按 outputSchema 的 name 字段兜底，并过滤掉非法元素", () => {
  const item = { type: "object", properties: { org_id: { type: "integer" }, name: { type: "string" }, org_type: { type: "string" } } };
  const schema = envelope({ type: "array", items: item });
  const data = [
    { org_id: 4, name: "培训猪场", org_type: "FARM" },
    { org_id: -1, name: "非法", org_type: "FARM" },
    { org_id: "x", name: "非法", org_type: "FARM" },
    { org_id: 5, name: "无类型", org_type: "" },
  ];
  assert.deepEqual(normalizeOrgs({ code: 0, msg: "success", data }, schema), [
    { org_type: "FARM", org_id: 4, name: "培训猪场" },
  ]);
});
