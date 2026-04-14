/* ====================================================================
   MASTER ANALYSIS v3

   输入：Master_Merge_v3.do 产出的 final_analysis_v3.dta（gvkey×year）。
   输出：output\v3_OLS_main_*.rtf、v3_OLS_int_*.rtf、v3_IV_*.rtf、
         v3_IV_LOO_summary.csv（及同目录 .dta）。

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
     (0.2) 尝试安装 reghdfe、ivreghdfe、winsor2、estout（若无则 SSC）。
     (0.3) 确认 final_analysis_v3.dta 存在后 use；xtset gvkey year。
     (0.4) keep if year > 2015（保留 2016 财年及以后）；报告 N。
     (0.5) 日志文件名带时间戳，避免并行/未关闭会话导致 r(608)。
   ==================================================================== */

global ROOT      "c:\Users\HuGoL\OneDrive - HKUST (Guangzhou)\PhD\3_Research\Moral Licensing"
global PROJ_DATA "$ROOT\data\processed"
global OUTPUT    "$ROOT\output"

cd "$ROOT\code"
local _logts = strofreal(clock(c(current_date) + " " + c(current_time), "DMYhms"))
log using "$ROOT\code\analysis_v3_`_logts'.log", replace text

foreach pkg in reghdfe ivreghdfe winsor2 estout {
    capture which `pkg'
    if _rc {
        capture ssc install `pkg'
        if _rc display as text "  [WARN] Could not install `pkg' (SSC unreachable?)"
    }
}

capture confirm file "$PROJ_DATA\final_analysis_v3.dta"
if _rc {
    display as error "Missing final_analysis_v3.dta — run Master_Merge_v3.do first."
    exit 601
}

use "$PROJ_DATA\final_analysis_v3.dta", clear
xtset gvkey year

keep if year > 2015
quietly count
display as text "  [INFO] Sample: year > 2015  |  N = " r(N)

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
   SECTION 2 — 因变量、ESG 候选列与 esttab 列标签（ivtags）

   因变量（6）：五类应计 DA + Heese 综合 REM（rem_heese）。
   ESG（10，若数据中存在则进入 ivlist）：Refinitiv vs_1 vs_4 vs_6 vs_11；
   KLD emp_kld env_kld kld_es_total；MSCI 三根支柱/加权。
   ivtags：与 ivall 一一对应，用于 eststo 名称（m_ref1、iv_kEmp 等）。
   ==================================================================== */

local dvlist da_dss da_ko da_yu da_ge da_dechow ///
             rem_heese

local iv_ref  vs_1 vs_4 vs_6 vs_11
local iv_kld  emp_kld env_kld kld_es_total
local iv_msci environmental_pillar_score social_pillar_score weighted_average_score

local ivall   `iv_ref' `iv_kld' `iv_msci'
local ivtags  ref1 ref4 ref6 ref11 kEmp kEnv kES mEnv mSoc mAvg


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

capture label var vs_1            "ESG Overall [Refinitiv]"
capture label var vs_4            "Environmental [Refinitiv]"
capture label var vs_5            "Governance [Refinitiv]"
capture label var vs_6            "Social [Refinitiv]"
capture label var vs_11           "E+S Composite [Refinitiv]"

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
capture label var per_io     "Institutional Ownership"
capture label var big_4      "Big 4 Auditor"
capture label var firm_age   "Firm Age"
capture label var ceo_age    "CEO Age"
capture label var ceo_gender "CEO Gender"
capture label var duality    "CEO Duality"


/* ====================================================================
   SECTION 4 —控制变量、IV 实际入模列表、非缺失率

   控制变量：
     核心：size mb2 lev roa growth_asset cash_holding。
     若存在则追加：per_io big_4 firm_age ceo_age ceo_gender duality     （不做按样本量的删减；回归仍 listwise 使用非缺失）。

   IV列表：
     按 ivall 顺序，仅当变量在数据中存在则纳入 ivlist/tags；不做覆盖率阈值剔除。

   非缺失率：
     对 gvkey/year/industry_type、全部 dvlist、ivlist、$ctrl 打印占当前 N 的
     百分比；仅报告，不删观测。
   ==================================================================== */

global ctrl size mb2 lev roa growth_asset cash_holding

foreach _v in per_io big_4 firm_age ceo_age ceo_gender duality {
    capture confirm variable `_v'
    if !_rc global ctrl $ctrl `_v'
}

display as text "  [INFO] Controls: $ctrl"

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

display as text "  [INFO] IVs in model: `ivlist'"

quietly count
local Ntot = r(N)
local miss_check year industry_type
capture confirm variable gvkey
if !_rc local miss_check gvkey `miss_check'
foreach v of local dvlist {
    capture confirm variable `v'
    if !_rc local miss_check `miss_check' `v'
}
foreach v of local ivlist {
    local miss_check `miss_check' `v'
}
foreach v in $ctrl {
    capture confirm variable `v'
    if !_rc local miss_check `miss_check' `v'
}
display as text _newline ">>> Non-missing share of sample (no action; N=`Ntot')"
foreach v of local miss_check {
    quietly count if !missing(`v')
    local pct = 100 * r(N) / `Ntot'
    display as text "  " %28s "`v'" "  " %6.2f `pct' "%"
}


/* ====================================================================
   SECTION 5 — Winsorize（0.5%与 99.5%）

   对象：全部 dvlist、ivlist、$ctrl 中存在的数值变量；cuts(0.5 99.5) replace。
   ==================================================================== */

local wvars
foreach v of local dvlist {
    capture confirm variable `v'
    if !_rc local wvars `wvars' `v'
}
foreach v of local ivlist {
    local wvars `wvars' `v'
}
foreach v in $ctrl {
    capture confirm variable `v'
    if !_rc local wvars `wvars' `v'
}
winsor2 `wvars', cuts(0.5 99.5) replace


/* ====================================================================
   SECTION 6 — OLS（reghdfe）

   对每个 DV：
     (6.1) 主效应：DV ~单个 ESG + i.industry_type + $ctrl；
 absorb(gvkey year)，cluster(gvkey)。输出 v3_OLS_main_<DV>.rtf。
     (6.2) 交互：DV ~ c.ESG##i.industry_type + $ctrl；同上 FE/SE。
           输出 v3_OLS_int_<DV>.rtf。

   内层循环：ESG 列依次取 ivlist 中第 i 个变量；失败则该列跳过（capture）。
   ==================================================================== */

display as text _newline ">>> Part A: OLS (reghdfe) — 6 DVs × IVs..."

local niv : word count `ivlist'

foreach dv of local dvlist {
    capture confirm variable `dv'
    if _rc continue

    display as text _newline "  [OLS] DV = `dv'"

    eststo clear
    local mlist
    forvalues i = 1/`niv' {
        local iv  : word `i' of `ivlist'
        local tag : word `i' of `tags'
        capture noisily reghdfe `dv' `iv' i.industry_type $ctrl, ///
            absorb(gvkey year) cluster(gvkey)
        if !_rc {
            eststo m_`tag'
            estadd local fe "Firm, Year"
            local mlist `mlist' m_`tag'
        }
    }
    if "`mlist'" != "" {
        esttab `mlist' using "$OUTPUT\v3_OLS_main_`dv'.rtf", ///
            replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
            label compress nogaps ///
            scalars("fe FE" "N Observations" "r2_a Adj R²") ///
            title("OLS main effects — DV: `dv'") ///
            addnotes("Cluster: gvkey. FE: firm + year.")
    }

    eststo clear
    local xlist
    forvalues i = 1/`niv' {
        local iv  : word `i' of `ivlist'
        local tag : word `i' of `tags'
        capture noisily reghdfe `dv' c.`iv'##i.industry_type $ctrl, ///
            absorb(gvkey year) cluster(gvkey)
        if !_rc {
            eststo x_`tag'
            estadd local fe "Firm, Year"
            local xlist `xlist' x_`tag'
        }
    }
    if "`xlist'" != "" {
        esttab `xlist' using "$OUTPUT\v3_OLS_int_`dv'.rtf", ///
            replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
            label compress nogaps ///
            scalars("fe FE" "N Observations" "r2_a Adj R²") ///
            title("OLS interaction (ESG × industry_type) — DV: `dv'") ///
            addnotes("Cluster: gvkey. FE: firm + year.")
    }
}

display as text ">>> Part A completed."


/* ====================================================================
   SECTION 7 — IV：同行业×年「留一法」同伴均值工具 +汇总表

   工具变量（对每个内生 ESG 分别构造）：
     在 (sic_2, year) 内，iv_loo = (组内 ESG 合计 − 本企业 ESG) / (n−1)，
     要求组内 n>1 且本企业 ESG 非缺失。含义：同伴平均 ESG，排除自身。

   估计：
     首选 ivreghdfe：内生 (ESG = iv_loo)，absorb(gvkey year)，cluster(gvkey)；
     若 ivreghdfe 不可用或运行失败（常见：ivreg2 过旧 → ms_vcvorthog），
     则同一 spec 改用 xtivreg，fe + i.year，vce(cluster gvkey)。
     run_loo_iv 返回 r(engine_used)、r(ok)、r(F_1st)、r(b_esg)、r(se_esg)。

   esttab（IV 表）：
     不得使用 drop(*.year)：ivreghdfe 吸收年份后 e(b) 中无 *.year，会 r(111)。
     使用 keep(`keeplist_iv')，keeplist_iv = ivlist + $ctrl，只展示 ESG 与控制。

   汇总：
     postfile 写入 v3_IV_LOO_summary.dta，再 list / export 为 csv。

   依赖：ivlist、tags、niv、iv_ref / iv_kld / iv_msci（用于标注数据来源）。
   ==================================================================== */

display as text _newline ">>> Part B: IV-LOO — 6 DVs × IVs..."

local iv_engine "xtivreg"
capture which ivreghdfe
if !_rc local iv_engine "ivreghdfe"
display as text "  [INFO] Preferred IV engine: `iv_engine'"

local keeplist_iv `ivlist'
foreach v in $ctrl {
    local keeplist_iv `keeplist_iv' `v'
}

capture program drop run_loo_iv
program define run_loo_iv, rclass
    * LOO 同伴均值；ivreghdfe 成功则 exit；否则 xtivreg同 spec的可行替代。
    syntax, ESGVAR(name) DVVAR(name) CTRLS(string) ENGINE(string)

    tempvar sm cn iv_loo
    quietly bysort sic_2 year: egen double `sm' = total(`esgvar')
    quietly bysort sic_2 year: egen long   `cn' = count(`esgvar')
    quietly gen double `iv_loo' = (`sm' - `esgvar') / (`cn' - 1) ///
        if `cn' > 1 & !missing(`esgvar')

    if "`engine'" == "ivreghdfe" {
        capture quietly ivreghdfe `dvvar' (`esgvar' = `iv_loo') `ctrls', ///
            absorb(gvkey year) cluster(gvkey)
        if !_rc {
            return local engine_used "ivreghdfe"
            return scalar ok     = 1
            return scalar N_used = e(N)
            capture return scalar F_1st = e(widstat)
            if _rc return scalar F_1st = .
            return scalar b_esg  = _b[`esgvar']
            return scalar se_esg = _se[`esgvar']
            exit
        }
    }

    capture quietly xtivreg `dvvar' (`esgvar' = `iv_loo') `ctrls' i.year, ///
        fe vce(cluster gvkey)
    if _rc {
        return local engine_used ""
        return scalar ok = 0
        return scalar N_used = .
        return scalar F_1st  = .
        return scalar b_esg  = .
        return scalar se_esg = .
        exit
    }
    return local engine_used "xtivreg"
    return scalar ok     = 1
    return scalar N_used = e(N)
    return scalar F_1st  = e(F_f)
    return scalar b_esg  = _b[`esgvar']
    return scalar se_esg = _se[`esgvar']
end

tempname ivpost
postfile `ivpost' str24 dv str32 iv str12 source ///
    double(N F_1st b se) ///
    using "$OUTPUT\v3_IV_LOO_summary.dta", replace

foreach dv of local dvlist {
    capture confirm variable `dv'
    if _rc continue

    display as text _newline "  [IV] DV = `dv'"
    eststo clear
    local ivmodels

    forvalues i = 1/`niv' {
        local iv  : word `i' of `ivlist'
        local tag : word `i' of `tags'

        local src "?"
        foreach _r of local iv_ref {
            if "`iv'" == "`_r'" local src "Refinitiv"
        }
        foreach _k of local iv_kld {
            if "`iv'" == "`_k'" local src "KLD"
        }
        foreach _m of local iv_msci {
            if "`iv'" == "`_m'" local src "MSCI"
        }

        quietly run_loo_iv, esgvar(`iv') dvvar(`dv') ctrls("$ctrl") engine("`iv_engine'")
        if r(ok) == 1 {
            eststo iv_`tag'
            estadd local fe "Firm, Year"
            estadd local instrument "LOO SIC-2×year"
            capture estadd local iv_cmd "`r(engine_used)'"
            capture estadd scalar F_1st = r(F_1st)
            local ivmodels `ivmodels' iv_`tag'
            post `ivpost' ("`dv'") ("`iv'") ("`src'") ///
                (r(N_used)) (r(F_1st)) (r(b_esg)) (r(se_esg))
        }
        else {
            post `ivpost' ("`dv'") ("`iv'") ("`src'") (.) (.) (.) (.)
        }
    }

    if "`ivmodels'" != "" {
        esttab `ivmodels' using "$OUTPUT\v3_IV_`dv'.rtf", ///
            replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
            label compress nogaps keep(`keeplist_iv') ///
            scalars("fe FE" "instrument Instrument" "F_1st First-stage F" "N Observations") ///
            title("IV-LOO — DV: `dv'") ///
            addnotes("Instrument = LOO SIC-2 × year peer average. Cluster: gvkey." ///
                " ivreghdfe requires current ivreg2 (ssc install ivreg2, replace)." ///
                " If ivreghdfe fails, this do-file uses xtivreg; see e(iv_cmd).")
    }
}

postclose `ivpost'

preserve
use "$OUTPUT\v3_IV_LOO_summary.dta", clear
list, sepby(dv) abbreviate(32)
export delimited using "$OUTPUT\v3_IV_LOO_summary.csv", replace
restore


display as text _newline ">>> Analysis v3 finished: $S_DATE $S_TIME"
display as text ">>> Output: $OUTPUT\v3_OLS_*.rtf, v3_IV_*.rtf, v3_IV_LOO_summary.csv"
log close
