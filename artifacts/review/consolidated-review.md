# Consolidated Review: PR #1

**Date**: 2026-04-26T00:15:00+08:00
**Agents**: code-review, error-handling, test-coverage, comment-quality, docs-impact
**Total Findings**: 12

---

## Executive Summary

项目整体代码质量良好，模块化设计清晰，命名规范一致。主要问题集中在：**缺少正式的单元测试文件**（解析器、去重、数据库三个核心模块）、几处错误处理的优化空间、以及文档需要补充。没有严重到阻止合并的 CRITICAL 问题。

**Overall Verdict**: APPROVE (建议修复 HIGH 问题后合并)

**Auto-fix Candidates**: 3 MEDIUM issues can be auto-fixed
**Manual Review Needed**: 2 HIGH issues（补充测试）、2 LOW（文档）

---

## Statistics

| Agent | CRITICAL | HIGH | MEDIUM | LOW | Total |
|-------|----------|------|--------|-----|-------|
| Code Review | 0 | 0 | 1 | 3 | 4 |
| Error Handling | 0 | 0 | 3 | 1 | 4 |
| Test Coverage | 1 | 2 | 0 | 0 | 3 |
| Comment Quality | 0 | 0 | 0 | 3 | 3 |
| Docs Impact | 0 | 1 | 1 | 0 | 2 |
| **Total** | **1** | **3** | **5** | **7** | **16** |

（去重后: 12 个独立问题）

---

## HIGH Issues (Should Fix)

### Issue 1: `page_parser.py` 缺少单元测试

**Source Agent**: test-coverage
**Location**: `src/scraper/page_parser.py`
**Category**: missing-test

**Problem**:
`_parse_house_info` 和 `is_car_space` 等核心解析逻辑没有测试覆盖。贝壳可能随时更新 `houseInfo` 格式，无声的数据损坏非常危险。

**Recommended Fix**:
创建 `tests/test_page_parser.py`，覆盖：
- 标准格式解析（布局/面积/朝向/装修）
- 带楼层和年份的格式
- 不规则格式
- 车位检测

---

### Issue 2: `image_dedup.py` 缺少单元测试

**Source Agent**: test-coverage
**Location**: `src/dedup/image_dedup.py`
**Category**: missing-test

**Problem**:
`classify_listings` 是数据质量的核心，4 个分类路径都没有测试覆盖。

**Recommended Fix**:
创建 `tests/test_image_dedup.py`，覆盖 NEW/DUPLICATE/CAR_SPACE/NO_IMAGE 四种分类。

---

### Issue 3: README 和 CLAUDE.md 需要补充

**Source Agent**: docs-impact
**Location**: `README.md`
**Category**: missing-docs

**Problem**:
README 只有两行标题。CLAUDE.md 不存在。用户（包括未来的你）需要参考文档来使用项目。

**Recommended Fix**:
补充 README（安装/使用/架构）并创建 CLAUDE.md。

---

## MEDIUM Issues (Consider Fixing)

### Issue 1: `page_parser.py` houseInfo 解析顺序可能导致朝向误匹配

**Source Agent**: code-review
**Location**: `src/scraper/page_parser.py:106-138`

**Options**:

| Option | Approach | Effort | Risk if Skipped |
|--------|----------|--------|-----------------|
| Fix Now | 调整 if/elif 顺序 | LOW | 极低：当前顺序在实际数据中工作正常 |
| Skip | 保持现状 | NONE | 极低：标准格式已覆盖 |

**Recommendation**: Skip for now. 标准贝壳数据格式下当前逻辑工作正常。如果遇到数据异常再调整。

---

### Issue 2: `browser.py` close() 吞掉异常

**Source Agent**: error-handling
**Location**: `src/scraper/browser.py:76-82`

**Options**:

| Option | Approach | Effort | Risk if Skipped |
|--------|----------|--------|-----------------|
| Fix Now | 改用逐项 try/except + log | LOW | 低：清理异常不影响功能 |
| Skip | 保持现状 | NONE | 低 |

**Recommendation**: Fix Now — 改动很小，对调试有帮助。

---

### Issue 3: `main.py` page.goto() 异常未区分重试性错误

**Source Agent**: error-handling
**Location**: `main.py:193-200`

**Options**:

| Option | Approach | Effort | Risk if Skipped |
|--------|----------|--------|-----------------|
| Fix Now | 区分 TimeoutError 和其他异常 | LOW | 低：重试3次在超时时有用 |
| Skip | 保持现状 | NONE | 低 |

**Recommendation**: Fix Now — 增加 Playwright TimeoutError 的特化处理。

---

### Issue 4: `connection.py` SQLite 连接缺少重连机制

**Source Agent**: error-handling
**Location**: `src/database/connection.py:20-26`

**Options**:

| Option | Approach | Effort | Risk if Skipped |
|--------|----------|--------|-----------------|
| Fix Now | 拆出 _create_connection 方法 | LOW | 低：WAL 模式下极少损坏 |
| Skip | 保持现状 | NONE | 极低 |

**Recommendation**: Skip. WAL 模式非常可靠，问题概率极低。

---

### Issue 5: `captcha_handler.py` `input()` 缺少超时

**Source Agent**: error-handling
**Location**: `src/scraper/captcha_handler.py:62`

**Options**:

| Option | Approach | Effort | Risk if Skipped |
|--------|----------|--------|-----------------|
| Fix Now | 无法可靠实现（Python input() 限制） | N/A | 低 |
| Skip | 保持现状 | NONE | 低：用户离开时程序会等待 |

**Recommendation**: Skip — Python 标准 input() 无法设置超时。

---

## LOW Issues (For Consideration)

| Issue | Location | Agent | Suggestion |
|-------|----------|-------|------------|
| STEALTH_SCRIPT 缺少各覆写项注释 | `src/config.py:33-65` | comment-quality | 给每项加简短说明 |
| session.py 域名文件名格式 | `src/scraper/session.py:20` | code-review | 直接用域名.原格式 |
| repository.py SELECT * | `src/database/repository.py:60` | code-review | 可选优化字段列表 |
| human_scroll 缺少"为什么"注释 | `src/scraper/browser.py:58` | comment-quality | 补充反爬原因说明 |

---

## Positive Observations

- **模块化设计优秀**：4个模块职责单一，接口清晰，可独立替换
- **反爬策略全面**：stealth脚本、随机延迟、UA轮换、headed模式、验证码人工处理
- **数据库设计合理**：house_code 唯一键、price_history 支持趋势分析、WAL模式保证并发
- **去重逻辑健壮**：4类分类（NEW/DUPLICATE/CAR_SPACE/NO_IMAGE）边界清晰
- **错误恢复好**：单页重试3次、数据库事务回滚、KeyboardInterrupt 处理
- **配置集中**：所有可调参数在 config.py 中，无需改代码

---

## Agent Artifacts

| Agent | Artifact | Findings |
|-------|----------|----------|
| Code Review | `code-review-findings.md` | 4 |
| Error Handling | `error-handling-findings.md` | 4 |
| Test Coverage | `test-coverage-findings.md` | 3 |
| Comment Quality | `comment-quality-findings.md` | 3 |
| Docs Impact | `docs-impact-findings.md` | 2 |
