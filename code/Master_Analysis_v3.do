/* ====================================================================
   MASTER ANALYSIS v3

   输入：Master_Merge_v3.do 产出的 final_analysis_v3.dta（gvkey×year）。
   输出：output\v3_OLS_<tag>.rtf（每个 ESG 一张 OLS 表）、
         output\v3_IV_<tag>.rtf （每个 ESG 一张 IV 表）。

   具体步骤、变量含义与估计设定均在下方「SECTION」注释块中说明；
   此处不重复罗列。
   ==================================================================== */

version 19.0
clear all
set more off
capture log close _all

/* ====================================================================
   SECTION 0 —路径、依赖包、读入数据、分析子样本

   步骤：
     (0.1) 设定 ROOT / PROJ_DATA / OUTPUT，工作目录指向 code。
     (0.2) 确认 final_analysis_v3.dta 存在后 use；xtset gvkey year。
     (0.3) keep if year >= 2010（保留 2010 财年及以后）；报告 N。
     (0.4) 日志文件名带时间戳，避免并行/未关闭会话导致 r(608)。
   ==================================================================== */

global ROOT      "c:\Users\HuGoL\OneDrive - HKUST (Guangzhou)\PhD\3_Research\Moral Licensing"
global PROJ_DATA "$ROOT\data\processed"
global OUTPUT    "$ROOT\output"

cd "$ROOT\code"
local _logts = string(clock(c(current_date) + " " + c(current_time), "DMYhms"), "%20.0f")
local _logts = strtrim("`_logts'")
log using "$ROOT\code\analysis_v3_`_logts'.log", replace text

capture confirm file "$PROJ_DATA\final_analysis_v3.dta"
if _rc {
    display as error "Missing final_analysis_v3.dta — run Master_Merge_v3.do first."
    exit 601
}

use "$PROJ_DATA\final_analysis_v3.dta", clear
xtset gvkey year

keep if year >= 2010
quietly count
display as text "  [INFO] Sample: year >= 2010  |  N = " r(N)

display as text _newline ">>> Analysis v3 started: $S_DATE $S_TIME"


/* ====================================================================
   SECTION 1 — 面板结构诊断（只写 log，不改数据）

   步骤：
     (1.1) xtdescribe：不平衡形态、缺年模式（失败则 WARN）。
     (1.2) 按 gvkey 数年内非缺失 year 的个数 _firm_years；在每家保留一行
           （egen tag）上 summarize, detail，报告 min / p50 / mean / max。
   ==================================================================== */

display as text _newline ">>> Panel structure (diagnostic only)"
quietly count
display as text "  Observations: " r(N)
capture quietly xtdescribe, patterns(8)
if _rc display as text "  [WARN] xtdescribe skipped (rc=`=_rc')."
egen byte _tag = tag(gvkey)
bysort gvkey: egen int _firm_years = count(year)
quietly summarize _firm_years if _tag == 1, detail
display as text "  Firm-year count per gvkey: min=" %4.0f r(min) ", p50=" %4.0f r(p50) ///
    ", mean=" %7.2f r(mean) ", max=" %4.0f r(max)
drop _tag _firm_years


/* ====================================================================
   SECTION 2 — 因变量、ESG 变量与 esttab 列标签

   因变量（6）：五类应计 DA + Heese 综合 REM（rem_heese）。
   ESG（4，Refinitiv）：fid1 Overall / fid4 Env / fid6 Social / env_soc E+S。
   ivtags：与 ivall 一一对应，用于 eststo 名称与输出文件名后缀。
   ==================================================================== */

local dvlist da_dss da_ko da_yu da_ge da_dechow ///
             rem_heese

local iv_ref  fid1_vscore fid4_vscore fid6_vscore env_soc_score
// local iv_kld  emp_kld env_kld kld_es_total
// local iv_msci environmental_pillar_score social_pillar_score weighted_average_score

local ivall   `iv_ref'
local ivtags  ref1 ref4 ref6 ref46


/* ====================================================================
   SECTION 3 — 变量标签（供 esttab label显示；不改变内存中的变量名）
   ==================================================================== */

capture label var da_dss          "DA: BS accrual, no dep [Compustat]"
capture label var da_ko           "DA: Jones incl. dep [Compustat]"
capture label var da_yu           "DA: NI − OANCF [Compustat]"
capture label var da_ge           "DA: IBC − OANCF [Compustat]"
capture label var da_dechow       "DA: IB − dCHE [Compustat]"
label var rem_heese               "REM aggregate [Compustat]"
capture label var ab_prod         "Abnormal production [Compustat]"
capture label var ab_disexp_neg   "Abnl disc. exp. ×(−1) [Compustat]"

capture label var fid1_vscore     "ESG Overall [Refinitiv]"
capture label var fid4_vscore     "Environmental [Refinitiv]"
capture label var fid5_vscore     "Governance [Refinitiv]"
capture label var fid6_vscore     "Social [Refinitiv]"
capture label var env_soc_score   "E+S Combined [Refinitiv]"

capture label var emp_kld         "Employee Net [KLD]"
capture label var env_kld         "Environmental Net [KLD]"
capture label var kld_es_total    "E+S Net [KLD]"

capture label var environmental_pillar_score "Environmental Pillar [MSCI]"
capture label var social_pillar_score        "Social Pillar [MSCI]"
capture label var weighted_average_score     "Overall Weighted [MSCI]"

label var industry_type  "Industry Culpability"
label var size           "Firm Size"
label var mb2            "Market-to-Book"
label var lev            "Leverage"
label var roa            "ROA"
label var growth_asset   "Asset Growth"
label var cash_holding   "Cash Holdings"
capture label var adj_roa       "Industry-adj. ROA"
capture label var per_io        "Institutional Ownership"
capture label var big_4         "Big 4 Auditor"
capture label var firm_age      "Firm Age"
capture label var numest        "Analyst Coverage"
capture label var numup         "Analyst Up Revisions [IBES]"
capture label var numdown       "Analyst Down Revisions [IBES]"
capture label var ceo_age       "CEO Age"
capture label var ceo_female    "CEO Female"
capture label var ceo_tenure    "CEO Tenure"
capture label var ceo_ownership "CEO Ownership"
capture label var interim_ceo   "Interim CEO"
capture label var cfo_age       "CFO Age"
capture label var cfo_female    "CFO Female"
capture label var cfo_tenure    "CFO Tenure"
capture label var interim_cfo   "Interim CFO"
capture label var duality       "CEO Duality"


/* ====================================================================
   SECTION 4 — 控制变量、ESG 入模列表、非缺失率、Winsorize

     控制变量：核心 6 个 + 若存在则追加 CEO / analyst / governance。
     ESG 列表：按 ivall 顺序，仅保留数据中存在的变量。
     Winsorize：dvlist + ivlist + ctrl，cuts(0.5 99.5)。
   ==================================================================== */

global ctrl size mb2 lev roa growth_asset cash_holding

foreach _v in per_io big_4 firm_age numest ///
              ceo_age ceo_female ceo_tenure ceo_ownership interim_ceo ///
              cfo_age cfo_female cfo_tenure interim_cfo duality {
    capture confirm variable `_v'
    if !_rc global ctrl $ctrl `_v'
}

local ivlist
local tags
local niv : word count `ivall'
forvalues i = 1/`niv' {
    local v : word `i' of `ivall'
    local t : word `i' of `ivtags'
    capture confirm variable `v'
    if !_rc {
        local ivlist `ivlist' `v'
        local tags   `tags'   `t'
    }
}
local niv : word count `ivlist'

display as text "  [INFO] Controls: $ctrl"
display as text "  [INFO] ESG measures: `ivlist'"

quietly count
local Ntot = r(N)
display as text _newline ">>> Non-missing rates (N=`Ntot')"
foreach v in `dvlist' `ivlist' $ctrl industry_type {
    capture confirm variable `v'
    if _rc continue
    quietly count if !missing(`v')
    display as text "  " %28s "`v'" "  " %6.2f (100*r(N)/`Ntot') "%"
}

local wvars
foreach v in `dvlist' `ivlist' $ctrl {
    capture confirm variable `v'
    if !_rc local wvars `wvars' `v'
}
winsor2 `wvars', cuts(0.5 99.5) replace


/* ====================================================================
   SECTION 5 — IV 工具：同 SIC-2×year 留一法（LOO）同伴均值

     对每个存在于数据中的 ESG（ivlist）生成常存变量 ivloo_<ivtags>，
     公式：组内 sum(ESG) 与 count，(sum − 自身) / (n−1)，仅当 n>1 且 ESG 非缺失。
     须在 winsorize（SECTION 4）之后执行，与原先 IV 循环内构造的 Z 一致。
   ==================================================================== */

display as text _newline ">>> LOO instruments (SIC-2 × year, pre-regression)"

forvalues j = 1/`niv' {
    local iv  : word `j' of `ivlist'
    local tag : word `j' of `tags'
    capture confirm variable `iv'
    if _rc continue

    capture confirm variable ivloo_`tag'
    if !_rc drop ivloo_`tag'

    tempvar _sm _cn
    quietly bysort sic_2 year: egen double `_sm' = total(`iv')
    quietly bysort sic_2 year: egen long   `_cn' = count(`iv')
    quietly gen double ivloo_`tag' = (`_sm' - `iv') / (`_cn' - 1) ///
        if `_cn' > 1 & !missing(`iv')
    drop `_sm' `_cn'

    capture label var ivloo_`tag' "LOO peer mean, `iv' (SIC-2×year)"
    display as text "  [LOO] ivloo_`tag'  ←  `iv'"
}

* OLS 单条示例（无宏；因变量/ESG 可换；控制变量 = SECTION 4 中 global ctrl 的核心 6 个）：
* reghdfe da_dss fid1_vscore i.industry_type size mb2 lev roa growth_asset cash_holding, absorb(gvkey year) cluster(gvkey)
* IV 单条示例（与 SECTION 7 同型；内生 fid1_vscore，工具 ivloo_ref1 = SECTION 5 对应该 ESG）：
* ivreghdfe da_dss (fid1_vscore = ivloo_ref1) i.industry_type size mb2 lev roa growth_asset cash_holding, absorb(gvkey year) cluster(gvkey)
* OLS 附加检验：调节效应（ESG × industry_type；## 含 ESG 主效应、行业主效应与交互，不再单列 i.industry_type）：
* reghdfe da_dss c.fid1_vscore##i.industry_type size mb2 lev roa growth_asset cash_holding, absorb(gvkey year) cluster(gvkey)
* IV 附加检验：同上调节设定，内生块与工具块为平行因子（LOO 与对应 ESG 同步交互）：
* ivreghdfe da_dss (c.fid1_vscore##i.industry_type = c.ivloo_ref1##i.industry_type) size mb2 lev roa growth_asset cash_holding, absorb(gvkey year) cluster(gvkey)


/* ====================================================================
   SECTION 6 — OLS: reghdfe

     外层 = ESG，内层 = DV → 每个 ESG 一张表，6 个 DV 为列。
     模型：DV ~ ESG + i.industry_type + $ctrl, absorb(gvkey year) cluster(gvkey)
   ==================================================================== */

display as text _newline ">>> Part A: OLS (reghdfe)"

forvalues j = 1/`niv' {
    local iv  : word `j' of `ivlist'
    local tag : word `j' of `tags'
    display as text _newline "  [OLS] ESG = `iv'"

    eststo clear
    local mlist
    foreach dv of local dvlist {
        capture confirm variable `dv'
        if _rc continue
        capture noisily reghdfe `dv' `iv' i.industry_type $ctrl, ///
            absorb(gvkey year) cluster(gvkey)
        if !_rc {
            eststo m_`dv'
            estadd local fe "Firm, Year"
            local mlist `mlist' m_`dv'
        }
    }
    if "`mlist'" != "" {
        esttab `mlist' using "$OUTPUT\v3_OLS_`tag'.rtf", ///
            replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
            label compress nogaps ///
            scalars("fe FE" "N Observations" "r2_a Adj R²") ///
            title("OLS — ESG: `iv'") ///
            addnotes("Cluster: gvkey. FE: firm + year.")
    }
}

display as text ">>> Part A completed."


/* ====================================================================
   SECTION 7 — IV: ivreghdfe（工具变量见 SECTION 5：ivloo_<tag>）

     每个 ESG 对应 ivloo_<ivtags>，对 6 个 DV 分别跑 ivreghdfe。
     每个 ESG 一张表，附 Kleibergen-Paap Wald F（弱工具变量检验）。
   ==================================================================== */

display as text _newline ">>> Part B: IV (ivreghdfe + SECTION 5 LOO vars)"

forvalues j = 1/`niv' {
    local iv  : word `j' of `ivlist'
    local tag : word `j' of `tags'
    local keepvars `iv' $ctrl
    display as text _newline "  [IV] ESG = `iv'  |  Z = ivloo_`tag'"

    capture confirm variable ivloo_`tag'
    if _rc {
        display as text "  [SKIP] ivloo_`tag' missing — run SECTION 5 logic for `iv'."
        continue
    }

    eststo clear
    local mlist
    foreach dv of local dvlist {
        capture confirm variable `dv'
        if _rc continue
        capture noisily ivreghdfe `dv' (`iv' = ivloo_`tag') ///
            i.industry_type $ctrl, absorb(gvkey year) cluster(gvkey)
        if !_rc {
            eststo iv_`dv'
            estadd local fe       "Firm, Year"
            estadd local instmt   "LOO SIC-2 × year (ivloo_`tag')"
            capture estadd scalar KP_F = e(widstat)
            local mlist `mlist' iv_`dv'
        }
    }

    if "`mlist'" != "" {
        esttab `mlist' using "$OUTPUT\v3_IV_`tag'.rtf", ///
            replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
            label compress nogaps keep(`keepvars') ///
            scalars("fe FE" "instmt Instrument" ///
                    "KP_F Kleibergen-Paap F" "N Observations") ///
            title("IV-LOO — ESG: `iv'") ///
            addnotes("Instrument = leave-one-out SIC-2 × year peer mean." ///
                     "Cluster: gvkey. FE: firm + year.")
    }
}


display as text _newline ">>> Analysis v3 finished: $S_DATE $S_TIME"
log close
