# 盈余管理测度方法详解

## 目录

1. [应计盈余管理（Accruals-based Earnings Management）](#一应计盈余管理)
  - Jones模型（1991）
  - Modified Jones模型（Dechow et al., 1995）
  - Performance-matched模型（Kothari et al., 2005）
  - Dechow-Dichev模型（2002）
2. [真实活动盈余管理（Real Activities Manipulation）](#二真实活动盈余管理)
  - Roychowdhury（2006）模型
3. [其他测度方法](#三其他测度方法)

---

# 一、应计盈余管理（Accruals-based Earnings Management）

## 1. Jones模型（1991）

### 1.1 模型背景

Jones（1991）提出了第一个系统性的应计盈余管理测度模型，该模型基于应计项目与营业收入、固定资产之间的预期关系，将总应计分解为非 discretionary 和 discretionary 两部分。

### 1.2 原始回归方程

Jones模型通过以下横截面回归方程估计正常应计（Normal Accruals）：

$$
\frac{TA_{it}}{A_{i,t-1}} = \alpha_1 \frac{1}{A_{i,t-1}} + \alpha_2 \frac{\Delta REV_{it}}{A_{i,t-1}} + \alpha_3 \frac{PPE_{it}}{A_{i,t-1}} + \varepsilon_{it}
$$

### 1.3 变量定义


| 变量                 | 定义      | 计算方法                                                    |
| ------------------ | ------- | ------------------------------------------------------- |
| $TA_{it}$          | 总应计项目   | $TA_{it} = NI_{it} - CFO_{it}$，其中$NI$为净利润，$CFO$为经营活动现金流 |
| $A_{i,t-1}$        | 滞后一期总资产 | 上年末总资产，用于标准化                                            |
| $\Delta REV_{it}$  | 营业收入变动  | $REV_{it} - REV_{i,t-1}$                                |
| $PPE_{it}$         | 固定资产原值  | 固定资产原值（Property, Plant, and Equipment）                  |
| $\varepsilon_{it}$ | 残差项     | 代表 discretionary accruals                               |


### 1.4 非 Discretionary Accruals 的计算

首先，使用估计期（通常是事件前若干年）的数据估计模型参数 $\hat{\alpha}_1, \hat{\alpha}_2, \hat{\alpha}_3$。

然后，计算事件期的非 discretionary accruals（NDA）：

$$
NDA_{it} = \hat{\alpha}*1 \frac{1}{A*{i,t-1}} + \hat{\alpha}*2 \frac{\Delta REV*{it}}{A_{i,t-1}} + \hat{\alpha}*3 \frac{PPE*{it}}{A_{i,t-1}}
$$

### 1.5 Discretionary Accruals 的推导

Discretionary Accruals（DA）是实际应计与预期应计之差：

$$
DA_{it} = \frac{TA_{it}}{A_{i,t-1}} - NDA_{it}
$$

或者直接从回归残差获得：

$$
DA_{it} = \hat{\varepsilon}_{it}
$$

### 1.6 模型优点与局限性

**优点：**

- 首次系统性地分离了 discretionary 和 non-discretionary accruals
- 理论基础扎实，被广泛接受
- 变量易于获取，计算简便

**局限性：**

- 无法识别通过应收账款进行的收入操纵
- 假设所有收入变动都导致正常应计变动
- 对极端业绩公司估计存在偏差
- 横截面估计假设同行业公司具有相同的应计生成过程

---

## 2. Modified Jones模型（Dechow et al., 1995）

### 2.1 修改动机

Dechow、Sloan和Sweeney（1995）发现Jones模型存在一个重要缺陷：**无法识别通过应收账款进行的收入操纵**。当公司通过放宽信用政策或虚构销售来增加收入时，应收账款会增加，但这种操纵不会被Jones模型捕获。

### 2.2 核心修改

Modified Jones模型在营业收入变动中**扣除应收账款变动**，以更准确地识别收入操纵：

$$
\frac{TA_{it}}{A_{i,t-1}} = \alpha_1 \frac{1}{A_{i,t-1}} + \alpha_2 \frac{\Delta REV_{it} - \Delta REC_{it}}{A_{i,t-1}} + \alpha_3 \frac{PPE_{it}}{A_{i,t-1}} + \varepsilon_{it}
$$

### 2.3 变量定义（新增）


| 变量                | 定义     | 计算方法                     |
| ----------------- | ------ | ------------------------ |
| $\Delta REC_{it}$ | 应收账款变动 | $REC_{it} - REC_{i,t-1}$ |


### 2.4 计算步骤

**第一步：估计参数**

使用估计期数据，运行以下回归：

$$
\frac{TA_{it}}{A_{i,t-1}} = \alpha_1 \frac{1}{A_{i,t-1}} + \alpha_2 \frac{\Delta REV_{it}}{A_{i,t-1}} + \alpha_3 \frac{PPE_{it}}{A_{i,t-1}} + \varepsilon_{it}
$$

获得参数估计值 $\hat{\alpha}_1, \hat{\alpha}_2, \hat{\alpha}_3$。

**第二步：计算非 Discretionary Accruals**

在事件期，使用修正后的公式计算NDA：

$$
NDA_{it} = \hat{\alpha}*1 \frac{1}{A*{i,t-1}} + \hat{\alpha}*2 \frac{\Delta REV*{it} - \Delta REC_{it}}{A_{i,t-1}} + \hat{\alpha}*3 \frac{PPE*{it}}{A_{i,t-1}}
$$

**第三步：计算 Discretionary Accruals**

$$
DA_{it} = \frac{TA_{it}}{A_{i,t-1}} - NDA_{it}
$$

### 2.5 应收账款调整的逻辑

- **正常经营情况**：收入增加伴随着应收账款正常增加
- **收入操纵情况**：公司通过虚构销售或放宽信用政策增加收入，导致应收账款异常增加
- **调整效果**：扣除应收账款变动后，收入操纵导致的异常应收账款会体现在DA中

### 2.6 模型评价

**改进之处：**

- 有效识别收入操纵行为
- 提高了盈余管理的检测能力
- 成为后续研究的标准基准

**剩余局限：**

- 仍无法解决极端业绩偏差问题
- 对业绩极端公司的应计估计不够准确

---

## 3. Performance-matched模型（Kothari et al., 2005）

### 3.1 问题背景

Kothari、Leone和Wasley（2005）发现，传统的Jones模型和Modified Jones模型存在一个严重问题：**极端业绩偏差（Performance-related Bias）**。具体表现为：

1. **高业绩公司**：往往有负的 discretionary accruals
2. **低业绩公司**：往往有正的 discretionary accruals

这种偏差源于应计与业绩之间的非线性关系，而非真实的盈余管理。

### 3.2 加入ROA的原因

在模型中加入业绩变量（ROA）可以：

- 控制业绩对应计的影响
- 消除极端业绩偏差
- 提高盈余管理测度的准确性

### 3.3 回归方程

**Performance-matched Jones模型：**

$$
\frac{TA_{it}}{A_{i,t-1}} = \alpha_1 \frac{1}{A_{i,t-1}} + \alpha_2 \frac{\Delta REV_{it}}{A_{i,t-1}} + \alpha_3 \frac{PPE_{it}}{A_{i,t-1}} + \alpha_4 ROA_{i,t-1} + \varepsilon_{it}
$$

**Performance-matched Modified Jones模型：**

$$
\frac{TA_{it}}{A_{i,t-1}} = \alpha_1 \frac{1}{A_{i,t-1}} + \alpha_2 \frac{\Delta REV_{it} - \Delta REC_{it}}{A_{i,t-1}} + \alpha_3 \frac{PPE_{it}}{A_{i,t-1}} + \alpha_4 ROA_{i,t-1} + \varepsilon_{it}
$$

### 3.4 变量定义（新增）


| 变量            | 定义        | 计算方法                     |
| ------------- | --------- | ------------------------ |
| $ROA_{i,t-1}$ | 滞后一期资产收益率 | $NI_{i,t-1} / A_{i,t-1}$ |


### 3.5 非 Discretionary Accruals 计算

$$
NDA_{it} = \hat{\alpha}*1 \frac{1}{A*{i,t-1}} + \hat{\alpha}*2 \frac{\Delta REV*{it} - \Delta REC_{it}}{A_{i,t-1}} + \hat{\alpha}*3 \frac{PPE*{it}}{A_{i,t-1}} + \hat{\alpha}*4 ROA*{i,t-1}
$$

### 3.6 另一种Performance-matching方法

除了直接在模型中加入ROA，Kothari等还提出了一种**配对方法**：

1. 根据ROA将样本公司分为若干组（如十分位）
2. 在每个ROA组内估计Jones/Modified Jones模型
3. 用同组公司的中位数或平均数作为匹配基准

### 3.7 模型评价

**优点：**

- 有效消除极端业绩偏差
- 显著提高盈余管理测度的准确性
- 被广泛认为是目前最好的应计盈余管理测度方法

**局限性：**

- 可能过度控制，将真实的盈余管理也作为业绩效应消除
- 需要更大的样本量以保证每个ROA组内有足够观测值

---

## 4. Dechow-Dichev模型（2002）

### 4.1 理论基础

Dechow和Dichev（2002）提出了一个基于**应计质量（Accrual Quality）**的盈余管理测度方法。该模型的核心思想是：

> 正常的应计项目应该能够较好地预测未来的现金流。如果应计项目与未来现金流的关系不稳定，则表明应计质量较低，可能存在盈余管理。

### 4.2 回归方程

Dechow-Dichev模型通过以下回归估计应计质量：

$$
\Delta WC_{it} = \alpha_0 + \alpha_1 CFO_{i,t-1} + \alpha_2 CFO_{it} + \alpha_3 CFO_{i,t+1} + \varepsilon_{it}
$$

其中，$\Delta WC_{it}$ 是营运资本变动（Working Capital Accruals）。

### 4.3 变量定义


| 变量                 | 定义        | 计算方法                |
| ------------------ | --------- | ------------------- |
| $\Delta WC_{it}$   | 营运资本变动    | 流动应计项目，计算公式见下文      |
| $CFO_{i,t-1}$      | 滞后一期经营现金流 | 上年经营活动现金流           |
| $CFO_{it}$         | 当期经营现金流   | 本年经营活动现金流           |
| $CFO_{i,t+1}$      | 领先一期经营现金流 | 下年经营活动现金流           |
| $\varepsilon_{it}$ | 残差        | 代表应计质量，残差越大表示应计质量越低 |


### 4.4 营运资本应计（Working Capital Accruals）的计算

$$
\Delta WC_{it} = \Delta CA_{it} - \Delta CL_{it} - \Delta Cash_{it} + \Delta STD_{it}
$$

其中：

- $\Delta CA_{it}$ = 流动资产变动
- $\Delta CL_{it}$ = 流动负债变动
- $\Delta Cash_{it}$ = 现金及现金等价物变动
- $\Delta STD_{it}$ = 短期借款变动（包含在流动负债中的债务部分）

**简化公式（基于资产负债表）：**

$$
\Delta WC_{it} = -(\Delta AR_{it} + \Delta Inv_{it} + \Delta OtherCA_{it} - \Delta AP_{it} - \Delta TP_{it} - \Delta OtherCL_{it})
$$

### 4.5 标准化处理

为了可比性，通常将残差标准化：

$$
AQ_{it} = \frac{|\varepsilon_{it}|}{A_{i,t-1}}
$$

$AQ_{it}$ 即为应计质量指标，**值越大表示应计质量越低，盈余管理可能性越高**。

### 4.6 McNichols（2002）扩展模型

McNichols（2002）对Dechow-Dichev模型进行了扩展，加入了营业收入变动和固定资产：

$$
\Delta WC_{it} = \alpha_0 + \alpha_1 CFO_{i,t-1} + \alpha_2 CFO_{it} + \alpha_3 CFO_{i,t+1} + \alpha_4 \Delta REV_{it} + \alpha_5 PPE_{it} + \varepsilon_{it}
$$

这个扩展模型结合了Jones模型和Dechow-Dichev模型的特点。

### 4.7 与Jones模型的区别


| 维度         | Jones模型                | Dechow-Dichev模型      |
| ---------- | ---------------------- | -------------------- |
| **理论基础**   | 应计与收入、固定资产的线性关系        | 应计对未来现金流的预测能力        |
| **核心假设**   | 正常应计由经营规模决定            | 高质量应计应能预测未来现金流       |
| **盈余管理识别** | 实际应计偏离预期应计             | 应计与现金流关系不稳定          |
| **数据需求**   | 仅需当期数据                 | 需要多期现金流数据            |
| **输出结果**   | Discretionary accruals | Accrual quality (残差) |


### 4.8 模型评价

**优点：**

- 理论基础扎实，从应计的经济实质出发
- 不依赖于特定的盈余管理动机假设
- 可以捕捉各种类型的盈余管理

**局限性：**

- 需要未来现金流数据，限制了实时应用
- 残差可能包含非盈余管理的噪音
- 计算相对复杂

---

# 二、真实活动盈余管理（Real Activities Manipulation）

## 1. Roychowdhury（2006）模型

### 1.1 理论基础

Roychowdhury（2006）提出了一个系统的真实活动盈余管理测度框架。真实活动盈余管理是指管理层通过**改变实际经营活动**来操纵盈余，而非通过会计选择。主要包括三种方式：

1. **销售操纵（Sales Manipulation）**：通过价格折扣或放宽信用政策增加销售
2. **过度生产（Overproduction）**：通过增加产量降低单位产品成本
3. **削减酌量性费用（Reduction of Discretionary Expenses）**：削减研发、广告等可自由支配费用

### 1.2 异常经营现金流（Abnormal Cash Flow from Operations）

#### 1.2.1 正常经营现金流模型

经营现金流与销售的关系：

$$
\frac{CFO_{it}}{A_{i,t-1}} = \alpha_0 + \alpha_1 \frac{1}{A_{i,t-1}} + \alpha_2 \frac{REV_{it}}{A_{i,t-1}} + \alpha_3 \frac{\Delta REV_{it}}{A_{i,t-1}} + \varepsilon_{it}
$$

#### 1.2.2 变量定义


| 变量                | 定义      | 计算方法                     |
| ----------------- | ------- | ------------------------ |
| $CFO_{it}$        | 经营活动现金流 | 现金流量表中的经营活动现金流           |
| $REV_{it}$        | 营业收入    | 利润表中的营业收入                |
| $\Delta REV_{it}$ | 营业收入变动  | $REV_{it} - REV_{i,t-1}$ |
| $A_{i,t-1}$       | 滞后一期总资产 | 上年末总资产                   |


#### 1.2.3 异常经营现金流

$$
Abnormal\ CFO_{it} = \frac{CFO_{it}}{A_{i,t-1}} - \left(\hat{\alpha}*0 + \hat{\alpha}1 \frac{1}{A{i,t-1}} + \hat{\alpha}2 \frac{REV{it}}{A*{i,t-1}} + \hat{\alpha}*3 \frac{\Delta REV*{it}}{A_{i,t-1}}\right)
$$

**解释**：异常CFO为**负**表示可能存在销售操纵（价格折扣导致现金流减少）。

---

### 1.3 异常生产成本（Abnormal Production Costs）

#### 1.3.1 生产成本定义

生产成本（PROD）包括销售成本和存货变动：

$$
PROD_{it} = COGS_{it} + \Delta Inv_{it}
$$

其中：

- $COGS_{it}$ = 销售成本（Cost of Goods Sold）
- $\Delta Inv_{it}$ = 存货变动（Inventory Change）

#### 1.3.2 正常生产成本模型

$$
\frac{PROD_{it}}{A_{i,t-1}} = \alpha_0 + \alpha_1 \frac{1}{A_{i,t-1}} + \alpha_2 \frac{REV_{it}}{A_{i,t-1}} + \alpha_3 \frac{\Delta REV_{it}}{A_{i,t-1}} + \alpha_4 \frac{\Delta REV_{i,t-1}}{A_{i,t-1}} + \varepsilon_{it}
$$

#### 1.3.3 变量定义


| 变量                   | 定义       | 计算方法                          |
| -------------------- | -------- | ----------------------------- |
| $PROD_{it}$          | 生产成本     | $COGS_{it} + \Delta Inv_{it}$ |
| $COGS_{it}$          | 销售成本     | 利润表中的销售成本                     |
| $\Delta Inv_{it}$    | 存货变动     | $Inv_{it} - Inv_{i,t-1}$      |
| $\Delta REV_{i,t-1}$ | 滞后一期收入变动 | 用于捕捉生产滞后                      |


#### 1.3.4 异常生产成本

$$
Abnormal\ PROD_{it} = \frac{PROD_{it}}{A_{i,t-1}} - \left(\hat{\alpha}*0 + \hat{\alpha}1 \frac{1}{A{i,t-1}} + \hat{\alpha}2 \frac{REV{it}}{A*{i,t-1}} + \hat{\alpha}*3 \frac{\Delta REV*{it}}{A_{i,t-1}} + \hat{\alpha}*4 \frac{\Delta REV*{i,t-1}}{A_{i,t-1}}\right)
$$

**解释**：异常PROD为**正**表示可能存在过度生产（通过增加产量降低单位成本）。

---

### 1.4 异常酌量性费用（Abnormal Discretionary Expenses）

#### 1.4.1 酌量性费用定义

酌量性费用（DISX）包括：

- 研发费用（R&D）
- 广告费用（Advertising）
- 销售及管理费用（SG&A）

$$
DISX_{it} = RD_{it} + Advertising_{it} + SGA_{it}
$$

#### 1.4.2 正常酌量性费用模型

$$
\frac{DISX_{it}}{A_{i,t-1}} = \alpha_0 + \alpha_1 \frac{1}{A_{i,t-1}} + \alpha_2 \frac{REV_{i,t-1}}{A_{i,t-1}} + \varepsilon_{it}
$$

**注意**：这里使用**滞后一期收入**而非当期收入，因为酌量性费用通常基于上期销售预算。

#### 1.4.3 变量定义


| 变量                 | 定义      | 计算方法                                    |
| ------------------ | ------- | --------------------------------------- |
| $DISX_{it}$        | 酌量性费用   | $RD_{it} + Advertising_{it} + SGA_{it}$ |
| $RD_{it}$          | 研发费用    | 利润表中的研发费用                               |
| $Advertising_{it}$ | 广告费用    | 利润表中的广告费用                               |
| $SGA_{it}$         | 销售及管理费用 | 利润表中的销售及管理费用                            |


#### 1.4.4 异常酌量性费用

$$
Abnormal\ DISX_{it} = \frac{DISX_{it}}{A_{i,t-1}} - \left(\hat{\alpha}*0 + \hat{\alpha}1 \frac{1}{A{i,t-1}} + \hat{\alpha}2 \frac{REV{i,t-1}}{A*{i,t-1}}\right)
$$

**解释**：异常DISX为**负**表示可能存在削减酌量性费用以增加盈余。

---

### 1.5 综合REM指标

#### 1.5.1 单一综合指标

Roychowdhury（2006）提出了一个综合的真实活动盈余管理指标：

$$
REM_{it} = Abnormal\ PROD_{it} - Abnormal\ CFO_{it} - Abnormal\ DISX_{it}
$$

**解释**：

- 异常PROD为正表示过度生产
- 异常CFO为负表示销售操纵
- 异常DISX为负表示削减费用
- 综合指标REM越大，表示真实活动盈余管理程度越高

#### 1.5.2 各指标的经济含义


| 指标            | 符号  | 经济含义           |
| ------------- | --- | -------------- |
| Abnormal CFO  | 负   | 价格折扣或放宽信用政策    |
| Abnormal PROD | 正   | 过度生产以降低单位成本    |
| Abnormal DISX | 负   | 削减研发、广告、SG&A费用 |
| REM           | 正   | 综合真实活动盈余管理程度   |


---

### 1.6 模型估计步骤总结

**第一步：分行业-年度估计参数**

对每个行业-年度组合，分别运行以下回归：

1. **经营现金流模型**：

$$
\frac{CFO_{it}}{A_{i,t-1}} = \alpha_0 + \alpha_1 \frac{1}{A_{i,t-1}} + \alpha_2 \frac{REV_{it}}{A_{i,t-1}} + \alpha_3 \frac{\Delta REV_{it}}{A_{i,t-1}} + \varepsilon_{it}
$$

1. **生产成本模型**：

$$
\frac{PROD_{it}}{A_{i,t-1}} = \alpha_0 + \alpha_1 \frac{1}{A_{i,t-1}} + \alpha_2 \frac{REV_{it}}{A_{i,t-1}} + \alpha_3 \frac{\Delta REV_{it}}{A_{i,t-1}} + \alpha_4 \frac{\Delta REV_{i,t-1}}{A_{i,t-1}} + \varepsilon_{it}
$$

1. **酌量性费用模型**：

$$
\frac{DISX_{it}}{A_{i,t-1}} = \alpha_0 + \alpha_1 \frac{1}{A_{i,t-1}} + \alpha_2 \frac{REV_{i,t-1}}{A_{i,t-1}} + \varepsilon_{it}
$$

**第二步：计算异常值**

使用估计参数计算每家公司的异常CFO、异常PROD和异常DISX。

**第三步：计算综合REM指标**

$$
REM_{it} = Abnormal\ PROD_{it} - Abnormal\ CFO_{it} - Abnormal\ DISX_{it}
$$

---

### 1.7 模型评价

**优点：**

- 系统性地捕捉了三种主要的真实活动盈余管理方式
- 理论基础扎实，符合管理层实际决策逻辑
- 变量易于获取，计算相对简便
- 被后续研究广泛采用

**局限性：**

- 需要分行业-年度估计，对样本量有要求
- 异常值可能包含非盈余管理的经济因素
- 无法区分不同动机的真实活动操纵
- 酌量性费用的定义存在争议

---

# 三、其他测度方法

## 1. 总应计（Total Accruals）

### 1.1 定义

总应计是最简单的盈余管理测度方法，直接计算净利润与经营现金流之差：

$$
TA_{it} = NI_{it} - CFO_{it}
$$

### 1.2 标准化

为了可比性，通常将总应计标准化：

$$
\frac{TA_{it}}{A_{i,t-1}} = \frac{NI_{it} - CFO_{it}}{A_{i,t-1}}
$$

### 1.3 优缺点

**优点：**

- 计算简单，易于理解
- 无需估计模型参数
- 适用于小样本研究

**缺点：**

- 无法区分 discretionary 和 non-discretionary 部分
- 包含大量正常经营相关的应计
- 盈余管理信号噪音较大

---

## 2. 基于现金流量表的应计

### 2.1 现金流量表法

Hribar和Collins（2002）指出，基于资产负债表的应计计算可能存在误差，特别是在存在并购、剥离等活动时。他们提出了基于现金流量表的应计计算方法。

### 2.2 计算公式

**总应计（现金流量表法）：**

$$
TA_{it}^{CF} = NI_{it} - CFO_{it}^{CF}
$$

其中，$CFO_{it}^{CF}$ 是现金流量表中报告的经营活动现金流。

### 2.3 营运资本应计（现金流量表法）

$$
\Delta WC_{it}^{CF} = -[\Delta AR_{it} + \Delta Inv_{it} + \Delta OtherCA_{it} - \Delta AP_{it} - \Delta TP_{it} - \Delta OtherCL_{it}]
$$

其中各项变动可以通过现金流量表补充资料获得。

### 2.4 与资产负债表法的比较


| 维度        | 资产负债表法 | 现金流量表法   |
| --------- | ------ | -------- |
| **数据来源**  | 资产负债表  | 现金流量表    |
| **并购影响**  | 受影响    | 不受影响     |
| **剥离影响**  | 受影响    | 不受影响     |
| **数据可得性** | 所有公司   | 部分早期公司缺失 |
| **计算复杂度** | 简单     | 较复杂      |


### 2.5 Hribar-Collins修正

Hribar和Collins（2002）建议，在使用Jones类模型时，应使用现金流量表法计算应计：

$$
\frac{NI_{it} - CFO_{it}^{CF}}{A_{i,t-1}} = \alpha_1 \frac{1}{A_{i,t-1}} + \alpha_2 \frac{\Delta REV_{it} - \Delta REC_{it}}{A_{i,t-1}} + \alpha_3 \frac{PPE_{it}}{A_{i,t-1}} + \varepsilon_{it}
$$

---

## 3. 盈余管理的其他测度方法

### 3.1 盈余分布法（Earnings Distribution Approach）

Burgstahler和Dichev（1997）提出通过分析盈余分布来检测盈余管理：

- **原理**：如果公司存在避免报告亏损或避免盈余下降的动机，盈余分布在零点附近或上年盈余点附近会出现不连续性
- **方法**：检验盈余分布的平滑性，寻找"断层"

### 3.2 具体账户分析法（Specific Account Analysis）

针对特定应计账户进行分析：

- **坏账准备**：$ALLOW_{it} = \alpha_0 + \alpha_1 AR_{it} + \alpha_2 \Delta AR_{it} + \varepsilon_{it}$
- **存货跌价准备**
- **资产减值准备**

### 3.3 会计政策变更法

检测会计政策变更对盈余的影响：

$$
\Delta NI_{it}^{accounting} = NI_{it}^{new\ policy} - NI_{it}^{old\ policy}
$$

---

# 四、方法选择建议

## 4.1 应计盈余管理方法选择


| 研究场景   | 推荐方法                               | 理由         |
| ------ | ---------------------------------- | ---------- |
| 一般研究   | Performance-matched Modified Jones | 最稳健，消除业绩偏差 |
| 关注收入操纵 | Modified Jones                     | 直接识别应收账款操纵 |
| 关注应计质量 | Dechow-Dichev                      | 从经济实质角度测度  |
| 小样本研究  | Total Accruals                     | 无需估计模型     |
| 存在并购活动 | 现金流量表法                             | 避免并购影响     |


## 4.2 真实活动盈余管理方法选择


| 研究场景   | 推荐方法             | 理由         |
| ------ | ---------------- | ---------- |
| 一般研究   | Roychowdhury综合指标 | 系统性强，被广泛接受 |
| 关注成本操纵 | 异常PROD           | 直接测度过度生产   |
| 关注销售操纵 | 异常CFO            | 直接测度价格折扣   |
| 关注费用操纵 | 异常DISX           | 直接测度费用削减   |


## 4.3 应计 vs. 真实活动盈余管理


| 维度          | 应计盈余管理    | 真实活动盈余管理 |
| ----------- | --------- | -------- |
| **操纵方式**    | 会计估计和选择   | 实际经营活动决策 |
| **成本**      | 审计风险、监管风险 | 偏离最优经营决策 |
| **可逆性**     | 可逆（后期转回）  | 不可逆      |
| **检测难度**    | 相对容易      | 相对困难     |
| **对公司价值影响** | 较小        | 可能较大     |


---

# 五、参考文献

1. Jones, J. J. (1991). Earnings management during import relief investigations. *Journal of Accounting Research*, 29(2), 193-228.
2. Dechow, P. M., Sloan, R. G., & Sweeney, A. P. (1995). Detecting earnings management. *The Accounting Review*, 70(2), 193-225.
3. Kothari, S. P., Leone, A. J., & Wasley, C. E. (2005). Performance matched discretionary accrual measures. *Journal of Accounting and Economics*, 39(1), 163-197.
4. Dechow, P., & Dichev, I. (2002). The quality of accruals and earnings: The role of accrual estimation errors. *The Accounting Review*, 77(s-1), 35-59.
5. Roychowdhury, S. (2006). Earnings management through real activities manipulation. *Journal of Accounting and Economics*, 42(3), 335-370.
6. Hribar, P., & Collins, D. W. (2002). Errors in estimating accruals: Implications for empirical research. *Journal of Accounting Research*, 40(1), 105-134.
7. McNichols, M. F. (2002). Discussion of "The quality of accruals and earnings: The role of accrual estimation errors". *The Accounting Review*, 77(s-1), 61-69.
8. Burgstahler, D., & Dichev, I. (1997). Earnings management to avoid earnings decreases and losses. *Journal of Accounting and Economics*, 24(1), 99-126.

---

*文档生成日期：2024年*
*本文件详细整理了盈余管理测度的主要方法，供学术研究和实证分析参考。*