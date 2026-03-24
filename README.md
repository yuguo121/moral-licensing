# Corporate ESG Engagement and Earnings Management

## 项目概述

研究企业 ESG 参与行为与盈余管理（Earnings Management）之间的关系，关注行业罪恶属性（sin industry / industry culpability）的调节作用。

---

## 文件结构

```
Moral Lisensing/
├── code/                          # Stata 分析代码
│   ├── Master_Analysis.do         # 主分析文件（含完整流程 Part 1-8）
│   ├── da_aug.do                  # [历史] DA 计算（已合并入 Master）
│   ├── merge_aug.do               # [历史] 数据合并（已合并入 Master）
│   ├── moderator_sep [Recovered].do  # [历史] 调节变量构造
│   ├── output_sep*.do             # [历史] 分阶段输出脚本
│   ├── ko_da_sic*.do              # [历史] 早期 DA 估算脚本
│   └── final_reg.do               # [历史] 早期回归脚本
│
├── data/                          # 本项目独有数据（不在公共 D:\Research\Data\ 中）
│   ├── msci_esg.dta               # MSCI ESG 评分数据（115 MB）
│   ├── duality_sup.dta            # CEO 二元性补充数据（303 KB）
│   │
│   │── [运行后自动生成，无需手动维护]
│   ├── dv_em_temp.dta             # Part 1 输出：DA 估算结果
│   ├── playboard_temp.dta         # Part 2 输出：合并后分析数据
│   └── final_analysis.dta         # Part 3 输出：含调节变量的最终分析数据集
│
├── output/                        # 回归结果（RTF 格式，可直接粘贴至 Word）
│   ├── Master_Results.rtf         # 主回归（含 CEO 控制变量）
│   ├── Master_Results_no_CEO.rtf  # 稳健性：去除 CEO 变量
│   ├── Master_Results_FF48.rtf    # 稳健性：FF48 行业分类 DA
│   ├── Master_Results_StateYear.rtf  # 稳健性：州×年份固定效应
│   ├── Master_Results_EM_Lag.rtf  # 稳健性：滞后 EM 对 ESG 的影响
│   ├── Master_Results_Entropy.rtf # 稳健性：熵均衡匹配
│   ├── Table1_Descriptive_Stats.rtf  # 描述统计
│   └── Table1_Correlation_Matrix.rtf # 相关系数矩阵
│
├── paper/                         # 论文文稿
│   ├── Corporate ESG..._v3_Rev.docx  # 最新修订版（当前版本）
│   ├── Corporate ESG..._v3.docx      # v3 基础版
│   └── v3.pdf
│
└── README.md                      # 本文件
```

---

## 数据来源说明

所有公共原始数据存放于 `D:\Research\Data\`，运行前请确认以下路径可访问：

| 数据集 | D盘路径 | 说明 |
|--------|---------|------|
| Compustat 财务数据 | `D:\Research\Data\Financials\compustat_80_25.dta` | 原 `cmm_raw.dta`，1980-2025 |
| KLD/MSCI KLD 评级 | `D:\Research\Data\ESG\kld_zy.dta` | 原 `crsp_merged_final_zhangyue.dta`，**需核实变量名** |
| 机构持股（IO） | `D:\Research\Data\Financials\io.dta` | 13F 机构持股比例 |
| CEO 薪酬 | `data\ceo_compensation.dta` | ⚠️ 本项目独有，存放在 data/ |
| 公司年龄 | `D:\Research\Data\firm_age.dta` | ✓ 直接可用 |
| MSCI ESG 评分 | `data\msci_esg.dta` | ⚠️ 本项目独有，存放在 data/ |
| CEO 二元性补充 | `data\duality_sup.dta` | ⚠️ 本项目独有，存放在 data/ |

> ⚠️ **注意**：`kld_zy.dta` 和 `execucomp_raw.dta` 是原始数据，变量名可能与旧项目中的处理后版本不同，首次运行 `Master_Analysis.do` 前需核实。

---

## 分析流程（Master_Analysis.do）

```
Part 1: DA 计算
  ├── 输入: compustat_80_25.dta
  └── 输出: data/dv_em_temp.dta

Part 2: 数据合并
  ├── 输入: dv_em_temp.dta + kld_zy + io + msci_esg + execucomp
  └── 输出: data/playboard_temp.dta

Part 3: 调节变量构造
  ├── 输入: playboard_temp.dta + firm_age + duality_sup
  └── 输出: data/final_analysis.dta

Part 4-8: 回归分析
  ├── 输入: final_analysis.dta
  └── 输出: output/*.rtf
```

---

## 待确认事项

- [ ] 确认 `compustat_80_25.dta` 是否包含 `cusip`, `fyear`, `at`, `ni`, `oancf` 等 DA 计算所需变量
- [x] `kld_zy.dta` 变量映射已确认
- [x] `ceo_compensation.dta` 已放入 `data/`
