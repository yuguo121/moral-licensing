# Corporate ESG Engagement and Earnings Management（Moral Lisensing 主仓库）

## 项目概述

研究企业 ESG 参与行为与盈余管理（Earnings Management）之间的关系，关注行业罪恶属性（sin industry / industry culpability）的调节作用。本目录作为 **独立 Git 仓库** 使用；代码与文档进 Git，**本地数据不进 Git**（见 `.gitignore` 与 `data/README.md`）。

---

## 文件结构（概要）

```
Moral Lisensing/
├── code/
│   ├── Master_Analysis.do          # 主分析（Part 1–8）
│   ├── Master_Analysis_v2.do       # v2 流程（含 final_analysis_v2.dta）
│   ├── …                           # 识别策略、IV、DID 等
│   └── legacy_corporate_esg_em/    # 【早期版本】自「Corporate ESG and EM」迁入的 .do
├── data/
│   ├── README.md                   # raw 联接（junction）与路径约定
│   ├── raw/                        # 目录联接 → 本机 D:\Research\Data（需自行 mklink /J，不提交）
│   └── processed/                # 项目 .dta（默认不提交，仅 .gitkeep 占位）
├── output/                         # 回归 RTF / 日志等（按需是否纳入版本控制）
├── paper/
└── README.md
```

---

## 数据与路径约定

| 全局宏 | 含义 |
|--------|------|
| `RAW_DATA` | `$ROOT\data\raw` → 建议用 **junction** 指向 `D:\Research\Data` |
| `PROJ_DATA` | `$ROOT\data\processed` → `final_analysis_v2.dta`、`msci_esg.dta` 等 |

**首次在本机配置 `data\raw`（目录联接）：**

- **PowerShell**（默认终端不是 cmd 时用这条）：  
  `New-Item -ItemType Junction -Path "…\Moral Lisensing\data\raw" -Target "D:\Research\Data"`
- **cmd**：`mklink /J "…\data\raw" "D:\Research\Data"`  
  在 PowerShell 里调用 cmd：`cmd /c 'mklink /J "…" "D:\Research\Data"'`

若已存在空的 `data\raw` 文件夹，请先删除再执行。完整说明见 `data/README.md`。

**公共原始数据（联接后位于 `data\raw` 下）示例：**

| 数据集 | 相对路径（在 `data\raw` 下） | 说明 |
|--------|------------------------------|------|
| Compustat | `Financials\compustat_80_25.dta` | DA 等 |
| KLD | `ESG\kld_zy.dta` | 变量名需与脚本一致 |
| IO | `Financials\io.dta` | 机构持股 |
| Firm age | `firm_age.dta` | |

**本项目处理数据（`data\processed`，不提交）：** `final_analysis_v2.dta`、`msci_esg.dta`、`ceo_compensation.dta`、`duality_sup.dta` 等。

---

## GitHub / 版本控制

- `.gitignore` 已忽略：`data/raw/`、`data/processed/*`（保留 `processed/.gitkeep`）、全局 `*.dta` 等。
- 克隆仓库后：创建 `data\raw` 联接、在 `data\processed` 放入或生成所需 `.dta`，再运行 Stata。

初始化远程仓库示例（在仓库根目录执行）：

```bash
git init
git add .
git commit -m "Initial commit: code and docs"
git remote add origin <你的 GitHub 仓库 URL>
git push -u origin main
```

分支名可按习惯使用 `master` / `main`。

---

## 分析流程（Master_Analysis.do）

```
Part 1: DA 计算
  ├── 输入: $RAW_DATA\Financials\compustat_80_25.dta
  └── 输出: $PROJ_DATA\dv_em_temp.dta

Part 2: 数据合并
  └── 输出: $PROJ_DATA\playboard_temp.dta

Part 3: 调节变量
  └── 输出: $PROJ_DATA\final_analysis.dta

Part 4–8: 回归 → output/*.rtf
```

（具体文件名以 `Master_Analysis.do` / `Master_Analysis_v2.do` 内为准。）

---

## 早期脚本（legacy）

`code/legacy_corporate_esg_em/` 中的文件来自原 **Corporate ESG and EM** 文件夹，**文件头已标注【早期版本】**；路径多为历史机器（如 `E:\empirical_study\data_raw`），仅供对照，**主线请以当前 `Master_Analysis*.do` 为准**。

---

## 待确认事项

- [ ] 确认 `compustat_80_25.dta` 是否包含 DA 所需变量
- [x] `kld_zy.dta` 变量映射已确认（以当前脚本为准）
- [x] `ceo_compensation.dta` 等已置于 `data\processed`
