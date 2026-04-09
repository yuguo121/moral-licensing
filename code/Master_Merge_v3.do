/* ====================================================================
   MASTER MERGE v3 — build firm-year panel from raw → processed
   Project: Corporate ESG Engagement and Earnings Management
   Run before: Master_Analysis_v3.do

   Prerequisite ESG: run build_asset4_wide.do first to create
     $ESG_DATA\asset4_wide.dta (cusip_8 × year) from asset4_raw.

   --------------------------------------------------------------------
   DV vs IV (names kept as in source / analysis; 出处见下行)
   --------------------------------------------------------------------
   DV — Compustat / Heese construction (本文件 Part 1，非 KLD·MSCI·Refinitiv):
     rem_heese, ab_prod, ab_disexp_neg,
     da_dss da_ko da_yu da_ge da_dechow,
     及 TA 构造用的 dv_ta_*、Jones 回归元 iv_1 iv_22 iv_3（= Modified Jones 自变量，
     非 ESG 工具变量；勿与 IV 混淆）

   IV — KLD: $ESG_DATA\kld_zy.dta（merge 带入 strengths/concerns 等原列名；
     本文件内派生 emp_kld env_kld kld_es_total 亦仅来自 KLD 列）

   IV — Refinitiv（Asset4 宽表）: $ESG_DATA\asset4_wide.dta（vs_* 等，列名保持）

   IV — MSCI: $PROJ_DATA\msci_esg.dta（social_pillar_score 等，列名保持）

   其他合并: IO（institutional ownership per_*，$FIN_DATA\io.dta）;
     CEO 薪酬等（$PROJ_DATA\ceo_compensation.dta）— 非 MSCI/KLD/Refinitiv

   --------------------------------------------------------------------
   Outputs
   --------------------------------------------------------------------
     dv_em_v3.dta          — Part 1：仅 Compustat 侧 EM 度量（DV）
     playboard_v3.dta      — Part 2：DV + KLD / Refinitiv / MSCI / IO / CEO 等
     final_analysis_v3.dta — Part 3：+ firm age、duality；可含 Refinitiv 派生 vs_11

   Merge keys: cusip_8 + fyear/year；最终面板 gvkey × year
   ==================================================================== */

version 19.0
clear all
set more off
capture log close

global ROOT         "c:\Users\HuGoL\OneDrive - HKUST (Guangzhou)\PhD\3_Research\Moral Licensing"
global RAW_ROOT     "D:\Research\Data"
global FIN_DATA     "$RAW_ROOT\Financials"
global CEO_DATA     "$RAW_ROOT\CEO"
global ESG_DATA     "$RAW_ROOT\ESG"
global PROJ_DATA    "$ROOT\data\processed"

cd "$ROOT\code"
log using "$ROOT\code\merge_v3_log.log", replace

capture which asreg
if _rc {
    display as error "Package asreg not found. Installing..."
    ssc install asreg
}

capture program drop log_sample
program define log_sample
    syntax , Step(string)
    quietly count
    display as text "  [SAMPLE] `step': " r(N) " observations"
end

local comp_file     "$FIN_DATA\compustat_80_25.dta"
local io_file       "$FIN_DATA\io.dta"
local kld_file      "$ESG_DATA\kld_zy.dta"
local firm_age_file "$RAW_ROOT\firm_age.dta"
* ESG: Asset4 from pre-built wide panel (see build_asset4_wide.do); MSCI = separate, original names.
local asset4_wide   "$ESG_DATA\asset4_wide.dta"
local msci_file     "$PROJ_DATA\msci_esg.dta"
local ceo_comp_file "$PROJ_DATA\ceo_compensation.dta"
local duality_file  "$PROJ_DATA\duality_sup.dta"

foreach _f in comp_file io_file kld_file firm_age_file asset4_wide msci_file ceo_comp_file duality_file {
    local _path ``_f''
    capture confirm file `"`_path'"'
    if _rc {
        display as error "Required file not found: `_path'"
        exit 601
    }
}

display as text _newline ">>> Merge v3 started: $S_DATE $S_TIME"


/* ====================================================================
   PART 1: DV — RAW COMPUSTAT → HEESE-ALIGNED EM（应计 / REM）
   来源: Compustat；非 KLD、非 MSCI、非 Refinitiv。
   ==================================================================== */
display as text _newline ">>> Part 1: Heese-aligned EM from raw Compustat..."

use `"`comp_file'"', clear

capture confirm numeric variable sic
if _rc {
    destring sic, replace force
}
gen sic_num = sic

drop if inrange(sic_num, 6000, 6999)

capture confirm variable linkprim
if !_rc {
    drop if inlist(linkprim, "N", "J")
}

drop if missing(gvkey) | missing(fyear) | missing(at) | missing(sale) | missing(ni)
drop if at <= 0

destring gvkey, replace force
gen cusip_8 = substr(cusip, 1, 8)

duplicates drop gvkey fyear, force

sort gvkey fyear
capture confirm variable year
if _rc gen year = fyear
else replace year = fyear
xtset gvkey year
log_sample, step("After base Compustat filters")

* Debt/cash: treat Compustat missings as zero for book leverage (common); diagnose CHE before imputing.
quietly count if missing(che)
display as text "  [INFO] Missing CHE before impute: " r(N) " obs"
replace dltt = 0 if missing(dltt)
replace dlc  = 0 if missing(dlc)
replace che  = 0 if missing(che)

gen lev = (dltt + dlc) / at
gen cash_holding = che / at
gen size = ln(at)
gen roa  = ni / at

gen double she = .
capture replace she = seq if !missing(seq)
capture replace she = ceq + pstk if missing(she) & !missing(ceq) & !missing(pstk)
capture replace she = ceq if missing(she) & !missing(ceq)
capture replace she = at - lt - mib if missing(she) & !missing(at) & !missing(lt) & !missing(mib)
capture replace she = at - lt if missing(she) & !missing(at) & !missing(lt)

* Preferred stock: fill by priority without using ps==0 as "unset" (pstkrv can be legitimately 0).
gen double ps = .
capture replace ps = pstkrv if !missing(pstkrv)
capture replace ps = pstkl if missing(ps) & !missing(pstkl)
capture replace ps = pstk if missing(ps) & !missing(pstk)
replace ps = 0 if missing(ps)

gen double be = she - ps
* mb2: market-to-book; be>0 only (negative book equity excluded, common in EM literature).
gen double mb2 = (prcc_f * csho) / be if !missing(prcc_f) & !missing(csho) & !missing(be) & be > 0
gen mv  = prcc_f * csho

* MV filter: prcc_f*csho in Compustat is USD millions; drop micro-caps (project rule).
drop if missing(mv) | mv < 20
log_sample, step("After market-value filter")

tostring sic_num, gen(sic_str) format(%04.0f)
gen sic_2 = substr(sic_str, 1, 2)

sort gvkey year
by gvkey: gen double l_at = at[_n-1] if year[_n-1] == year - 1
quietly count if missing(l_at)
display as text "  [INFO] Dropping obs with no prior-year AT (incl. first firm-year): " r(N)
drop if missing(l_at)
log_sample, step("After lagged-assets requirement")

* --- TA & accrual regressors (same logic as Master_Analysis.do; diffs only if year[_n-1]==year-1) ---
by gvkey: gen double d_act  = act  - act[_n-1]  if year[_n-1] == year - 1
by gvkey: gen double d_lct  = lct  - lct[_n-1]  if year[_n-1] == year - 1
by gvkey: gen double d_che  = che  - che[_n-1]  if year[_n-1] == year - 1
by gvkey: gen double d_dlc  = dlc  - dlc[_n-1]  if year[_n-1] == year - 1
by gvkey: gen double d_revt = revt - revt[_n-1] if year[_n-1] == year - 1
by gvkey: gen double d_rect = rect - rect[_n-1] if year[_n-1] == year - 1

gen double dss_ta = d_act - d_lct - d_che + d_dlc if !missing(d_act, d_lct, d_che, d_dlc)

capture confirm variable dp
if !_rc {
    gen double ko_ta = dss_ta - dp if !missing(dss_ta) & !missing(dp)
    label var ko_ta "Jones TA: dss_ta - dp"
}

capture confirm variable oancf
if !_rc {
    gen double yu_ta = ni - oancf if !missing(ni) & !missing(oancf)
    label var yu_ta "CF accruals: NI - OANCF"
    capture confirm variable ibc
    if !_rc {
        gen double ge_ta = ibc - oancf if !missing(ibc) & !missing(oancf)
        label var ge_ta "CF accruals: IBC - OANCF (IS-CF match)"
    }
}

capture confirm variable ib
if !_rc {
    gen double dechow_ta = ib - d_che if !missing(ib) & !missing(d_che)
    label var dechow_ta "IB - (CHE - L.CHE) = IB - d_che"
}

* Scaled TA (Master_Analysis-style names + legacy dss_ta_scaled for v3 analysis)
gen double dv_ta_dss = dss_ta / l_at if !missing(dss_ta) & !missing(l_at)
gen double dss_ta_scaled = dv_ta_dss
capture confirm variable ko_ta
if !_rc gen double dv_ta_ko = ko_ta / l_at if !missing(ko_ta) & !missing(l_at)
capture confirm variable yu_ta
if !_rc gen double dv_ta_yu = yu_ta / l_at if !missing(yu_ta) & !missing(l_at)
capture confirm variable ge_ta
if !_rc gen double dv_ta_ge = ge_ta / l_at if !missing(ge_ta) & !missing(l_at)
capture confirm variable dechow_ta
if !_rc gen double dv_ta_dechow = dechow_ta / l_at if !missing(dechow_ta) & !missing(l_at)

label var dv_ta_dss "dss_ta / lag AT"
label var dss_ta_scaled "Same as dv_ta_dss (Heese / v3 main DA)"

* Modified-Jones 回归元（Compustat；名称 iv_* 为 Jones 文献记号，不是 ESG IV）
gen double iv_1 = 1 / l_at
gen double iv_22 = (d_revt - d_rect) / l_at if !missing(d_revt) & !missing(d_rect) & !missing(l_at)
gen double iv_3 = ppegt / l_at

* --- Five modified-Jones DAs (same iv_1, iv_22, iv_3; scaled TA differs) ---
foreach stub in dss ko yu ge dechow {
    if "`stub'" == "dss" local dv dv_ta_dss
    else local dv dv_ta_`stub'
    capture confirm variable `dv'
    if _rc continue
    gen byte _ok = !missing(`dv', iv_1, iv_22, iv_3)
    bysort sic_2 year: egen _dacnt = total(_ok)
    display as text "  DA (`stub'): modified Jones on `dv' (SIC-2 × year)..."
    bys year sic_2: asreg `dv' iv_1 iv_22 iv_3 if _dacnt >= 10
    gen double _nda = _b_iv_1 * iv_1 + _b_iv_22 * iv_22 + _b_iv_3 * iv_3 + _b_cons if _dacnt >= 10
    gen double da_`stub' = `dv' - _nda if _dacnt >= 10 & !missing(`dv', iv_1, iv_22, iv_3)
    drop _Nobs _R2 _adjR2 _b_iv_1 _b_iv_22 _b_iv_3 _b_cons _nda _ok _dacnt
}

sort gvkey year

capture confirm variable da_dss
if !_rc {
    label var da_dss "Modified-Jones DA; TA=dv_ta_dss (BS, no dep)"
    gen double dss_da_heese = da_dss
    label var dss_da_heese "Alias of da_dss (backward compat)"
}
capture confirm variable da_ko
if !_rc label var da_ko "Modified-Jones DA; TA=dv_ta_ko (Jones + dep)"
capture confirm variable da_yu
if !_rc label var da_yu "Modified-Jones DA; TA=dv_ta_yu (NI-OANCF)"
capture confirm variable da_ge
if !_rc label var da_ge "Modified-Jones DA; TA=dv_ta_ge (IBC-OANCF)"
capture confirm variable da_dechow
if !_rc label var da_dechow "Modified-Jones DA; TA=dv_ta_dechow (IB-dCHE)"

drop d_act d_lct d_che d_dlc d_revt d_rect

gen double sale_scaled = sale / l_at
by gvkey: gen double d_sale_scaled = (sale - sale[_n-1]) / l_at if year[_n-1] == year - 1
by gvkey: gen double l_d_sale_scaled = d_sale_scaled[_n-1] if year[_n-1] == year - 1
by gvkey: gen double l_sale_scaled = sale_scaled[_n-1] if year[_n-1] == year - 1

replace invch = 0 if missing(invch)
gen double prod_scaled = (cogs + invch) / l_at if !missing(cogs)

replace xrd = 0 if missing(xrd)
* REM discretionary expenses: SG&A + R&D + advertising (xad); xad often 0 if embedded in xsga or undisclosed.
capture confirm variable xad
if _rc gen double xad = 0
else replace xad = 0 if missing(xad)
gen double disexp_scaled = (xsga + xrd + xad) / l_at if !missing(xsga)

gen byte _prod_ok = !missing(prod_scaled, iv_1, sale_scaled, d_sale_scaled, l_d_sale_scaled)
gen byte _disx_ok = !missing(disexp_scaled, iv_1, l_sale_scaled)
bysort sic_2 year: egen _prod_n = total(_prod_ok)
bysort sic_2 year: egen _disx_n = total(_disx_ok)

display as text "  Estimating Heese-style REM (SIC-2 × year)..."
bys year sic_2: asreg prod_scaled iv_1 sale_scaled d_sale_scaled l_d_sale_scaled if _prod_n >= 10
gen double _normal_prod = ///
    _b_iv_1 * iv_1 + _b_sale_scaled * sale_scaled + _b_d_sale_scaled * d_sale_scaled + ///
    _b_l_d_sale_scaled * l_d_sale_scaled + _b_cons if _prod_n >= 10
gen double ab_prod = prod_scaled - _normal_prod if _prod_n >= 10
drop _Nobs _R2 _adjR2 _b_iv_1 _b_sale_scaled _b_d_sale_scaled _b_l_d_sale_scaled _b_cons _normal_prod

bys year sic_2: asreg disexp_scaled iv_1 l_sale_scaled if _disx_n >= 10
gen double _normal_disx = _b_iv_1 * iv_1 + _b_l_sale_scaled * l_sale_scaled + _b_cons if _disx_n >= 10
gen double ab_disexp = disexp_scaled - _normal_disx if _disx_n >= 10
drop _Nobs _R2 _adjR2 _b_iv_1 _b_l_sale_scaled _b_cons _normal_disx _prod_ok _disx_ok _prod_n _disx_n

gen double ab_disexp_neg = -1 * ab_disexp
gen double rem_heese = ab_prod + ab_disexp_neg

label var rem_heese         "REM = AbPROD + AbDISX(-) (Heese-aligned)"

sort gvkey year
compress
save "$PROJ_DATA\dv_em_v3.dta", replace
display as text ">>> Part 1 done: dv_em_v3.dta"


/* ====================================================================
   PART 2: 在 Compustat DV 上叠加 ESG / 治理等 IV（及 IO、CEO）
   KLD → Refinitiv(Asset4) → MSCI 顺序见下；列名尽量保持数据源原名。
   ==================================================================== */
display as text _newline ">>> Part 2: Merges and controls..."

use "$PROJ_DATA\dv_em_v3.dta", clear
capture replace year = fyear if missing(year)

* --- IV — KLD（kld_zy.dta）---
preserve
use `"`kld_file'"', clear
capture confirm variable cusip_8
if _rc gen cusip_8 = substr(cusip, 1, 8)
duplicates drop cusip_8 fyear, force
tempfile kld_temp
save `kld_temp'
restore

merge 1:1 cusip_8 fyear using `kld_temp', ///
    nogen keep(1 3 4 5) update ///
    keepusing(env_str_* env_con_* com_str_* com_con_* hum_str_* hum_con_* ///
              emp_str_* emp_con_* div_str_* div_con_* pro_str_* pro_con_* ///
              cgov_str_* cgov_con_* alc_con_* gam_con_* mil_con_* nuc_con_* tob_con_*)
log_sample, step("After KLD merge")

* --- IO（机构持股，非 KLD/MSCI/Refinitiv）---
preserve
use `"`io_file'"', clear
capture confirm variable cusip_8
if _rc gen cusip_8 = substr(cusip, 1, 8)
capture confirm variable fyear
if _rc {
    capture confirm variable year
    if !_rc rename year fyear
}
duplicates drop cusip_8 fyear, force
tempfile io_temp
save `io_temp'
restore

merge 1:1 cusip_8 fyear using `io_temp', keep(1 3) nogen keepusing(per_*)
log_sample, step("After IO merge")

gen byte culpa = 0
capture unab sinvars : alc_con_* gam_con_* mil_con_* nuc_con_* tob_con_*
if !_rc {
    foreach v of local sinvars {
        replace culpa = 1 if `v' == 1
    }
}

* --- IV — Refinitiv（Asset4 汇总宽表 asset4_wide.dta）---
merge 1:1 cusip_8 year using `"`asset4_wide'"', keep(1 3) nogen keepusing(vs_1 vs_4 vs_5 vs_6)
log_sample, step("After Refinitiv (Asset4) merge")

* --- IV — MSCI（msci_esg.dta；保留原列名）---
merge 1:1 cusip_8 year using `"`msci_file'"', keep(1 3) nogen keepusing(social_pillar_score environmental_pillar_score weighted_average_score)
log_sample, step("After MSCI merge")

* --- CEO 薪酬等（项目文件 ceo_compensation.dta；非 KLD/MSCI/Refinitiv）---
preserve
use `"`ceo_comp_file'"', clear
capture confirm variable cusip_8
if _rc gen cusip_8 = substr(cusip, 1, 8)
capture confirm variable year
if _rc {
    capture confirm variable fyear
    if !_rc gen year = fyear
}
capture confirm variable total_curr_comp
if !_rc gsort cusip_8 year -total_curr_comp
else {
    capture confirm variable ceo_name
    if !_rc sort cusip_8 year ceo_name
    else sort cusip_8 year
}
duplicates drop cusip_8 year, force
tempfile ceo_temp
save `ceo_temp'
restore

merge 1:1 cusip_8 year using `ceo_temp', keep(1 3) nogen
log_sample, step("After CEO compensation merge")

* 派生指标（仅 KLD 原列运算；未改 KLD 字段名）
capture {
    gen emp_kld = emp_str_num1 - emp_con_num1
    gen env_kld = env_str_num1 - env_con_num1
    gen kld_es_total = env_kld + emp_kld
}
capture label var emp_kld "KLD-derived: emp_str_num1 - emp_con_num1"
capture label var env_kld "KLD-derived: env_str_num1 - env_con_num1"
capture label var kld_es_total "KLD-derived: env_kld + emp_kld"

capture {
    replace ceo_gender = "1" if ceo_gender == "MALE"
    replace ceo_gender = "0" if ceo_gender == "FEMALE"
    destring ceo_gender, replace
}

sort gvkey year
by gvkey: gen double _l_she  = she[_n-1]  if year[_n-1] == year - 1
by gvkey: gen double _l_che  = che[_n-1]  if year[_n-1] == year - 1
by gvkey: gen double _l_dltt = dltt[_n-1] if year[_n-1] == year - 1
by gvkey: gen double _l_dlc  = dlc[_n-1]  if year[_n-1] == year - 1
by gvkey: gen double _l_sale = sale[_n-1] if year[_n-1] == year - 1
gen double noa = (_l_she - _l_che + _l_dltt + _l_dlc) / _l_sale ///
    if !missing(_l_she) & !missing(_l_sale) & _l_sale > 0
drop _l_she _l_che _l_dltt _l_dlc _l_sale

by gvkey: gen double _l_sale2 = sale[_n-1] if year[_n-1] == year - 1
bysort sic_2 year: egen double _sic2_total_l_sale = total(_l_sale2)
gen double mkt_share = _l_sale2 / _sic2_total_l_sale if _sic2_total_l_sale > 0
drop _l_sale2 _sic2_total_l_sale

gen byte loss = (ni < 0) if !missing(ni)
bysort sic_2 year: egen double aver_roa = mean(roa)
gen double adj_roa = roa - aver_roa

gen byte industry_type = 0
replace industry_type = 1 if inrange(sic_num, 2100, 2199)
replace industry_type = 1 if inrange(sic_num, 3760, 3769) | sic_num == 3795 | inrange(sic_num, 3480, 3489)
replace industry_type = 1 if inrange(sic_num, 800, 899) | inrange(sic_num, 1000, 1119) | inrange(sic_num, 1400, 1499)
replace industry_type = 1 if sic_num == 2080 | inrange(sic_num, 2082, 2085)
replace industry_type = 1 if culpa == 1

isid gvkey year

compress
save "$PROJ_DATA\playboard_v3.dta", replace
display as text ">>> Part 2 done: playboard_v3.dta"


/* ====================================================================
   PART 3: 控制变量补充 + 最终 gvkey×year 面板（DV 仍为 Part1；ESG IV 已在 Part2）
   ==================================================================== */
display as text _newline ">>> Part 3: Final panel..."

use "$PROJ_DATA\playboard_v3.dta", clear
xtset gvkey year

preserve
use `"`firm_age_file'"', clear
duplicates drop gvkey year, force
tempfile age_temp
save `age_temp'
restore
merge 1:1 gvkey year using `age_temp', keep(1 3 4 5) keepusing(age) nogen

preserve
use `"`duality_file'"', clear
duplicates drop gvkey year, force
tempfile dual_temp
save `dual_temp'
restore
merge 1:1 gvkey year using `dual_temp', keep(1 3) keepusing(duality) update nogen

capture gen big_n = (au > 0 & au < 9) if !missing(au)
capture gen big_4 = (au > 3 & au < 9) if !missing(au)
capture gen firm_age = age

sort gvkey year
by gvkey: gen double _l_at = at[_n-1] if year[_n-1] == year - 1
gen double growth_asset = (at - _l_at) / _l_at if !missing(_l_at) & _l_at > 0
drop _l_at

* 分析用合成：Refinitiv vs_4 + vs_6（不改 vs_4/vs_6 名）；MSCI 支柱仍为独立列
capture drop vs_11
capture confirm variable vs_4
if !_rc {
    capture confirm variable vs_6
    if !_rc gen double vs_11 = vs_4 + vs_6 if !missing(vs_4) & !missing(vs_6)
}
capture label var vs_11 "Refinitiv-derived: vs_4 + vs_6"

sort gvkey year
isid gvkey year

compress
save "$PROJ_DATA\final_analysis_v3.dta", replace
display as text ">>> Part 3 done: final_analysis_v3.dta (firm-year panel)"
display as text ">>> Merge v3 finished: $S_DATE $S_TIME"
log close
