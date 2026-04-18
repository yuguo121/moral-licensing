/* ====================================================================
   MASTER MERGE v3 — 原始 Compustat / 外部表 →  firm-year 分析面板

   下游：Master_Analysis_v3.do 读取 final_analysis_v3.dta。

   先决条件：Refinitiv V2 ESG Scores.dta 位于 $ESG_DATA。

   --------------------------------------------------------------------
   数据流与产出（细节见各 SECTION）
   --------------------------------------------------------------------
     SECTION 0 — 路径、输入文件检查、小工具程序
     SECTION 1 — Compustat 单表：筛选、应计/REM（DV），→ dv_em_v3.dta
     SECTION 2 — 在 DV 上 merge KLD / IO / Refinitiv / MSCI / CEO，
                 派生 KLD 净分、culpa、industry_type 等，→ playboard_v3.dta
     SECTION 3 — firm age、duality、growth_asset、big_4、vs_11，
                 → final_analysis_v3.dta

   合并键：cusip_8 + fyear（或 year）；panel_zy 为 cusip + fyear；最终 xtset 为 gvkey × year。

   名称提醒：Part1 中 iv_1 iv_22 iv_3 为 Modified Jones 回归元（文献记号），
   不是 ESG 工具变量。ESG 来自 KLD / Asset4 / MSCI合并列。
   ==================================================================== */

version 19.0
clear all
set more off
capture log close

/* ====================================================================
   SECTION 0 — 全局路径、日志、asreg、输入文件检查

   (0.1) 定义 ROOT、RAW_ROOT、FIN_DATA、CEO_DATA、ESG_DATA、PROJ_DATA；cd code；开 log。
   (0.2) 安装/确认 asreg（SIC-2×year 内 asreg 求 DA/REM 残差）。
   (0.3) 定义程序 log_sample：在关键步骤后仅打印当前 N。
   (0.4) 本地宏 comp_file … duality_file 指向各输入；foreach 用 ``_f'' 二次展开路径，
         缺失则 exit 601。
   ==================================================================== */

global ROOT         "c:\Users\HuGoL\OneDrive - HKUST (Guangzhou)\PhD\3_Research\Moral Licensing"
global RAW_ROOT     "D:\Research\Data"
global FIN_DATA     "$RAW_ROOT\Financials"
global CEO_DATA     "$RAW_ROOT\CEO"
global ESG_DATA     "$RAW_ROOT\ESG"
global PROJ_DATA    "$ROOT\data\processed"

cd "$ROOT\code"
log using "$ROOT\code\merge_v3_log.log", replace

capture program drop log_sample
program define log_sample
    * 在关键筛选/合并后打印当前样本量（仅日志，不改数据）。
    syntax , Step(string)
    quietly count
    display as text "  [SAMPLE] `step': " r(N) " observations"
end

local comp_file     "$FIN_DATA\compustat_80_25.dta"
local io_file       "$FIN_DATA\io.dta"
local kld_file      "$ESG_DATA\kld_zy.dta"
local refinitiv_file "$ESG_DATA\V2 Refinitiv ESG Scores.dta"
local msci_file     "$PROJ_DATA\msci_esg.dta"
local duality_file  "$PROJ_DATA\duality_sup.dta"
local execucomp_file "$CEO_DATA\execucomp_10_25.dta"
local ibes_file     "$FIN_DATA\ibes_sum_raw.dta"
local panel_zy_file "$FIN_DATA\panel_zy.dta"

foreach _f in comp_file io_file kld_file refinitiv_file msci_file duality_file execucomp_file ibes_file panel_zy_file {
    local _path ``_f''
    capture confirm file `"`_path'"'
    if _rc {
        display as error "Required file not found: `_path'"
        exit 601
    }
}

display as text _newline ">>> Merge v3 started: $S_DATE $S_TIME"


/* ====================================================================
   SECTION 1 — Compustat → 应计 DA + Heese REM（仅本表，无 ESG）

   (1.1) 读入 compustat；SIC、金融与公用事业（Ni 2020 等常用设定）/链接筛选；核心会计变量非缺失；去重 gvkey×fyear；
         year 与 fyear 对齐；xtset。
   (1.2) 杠杆、现金、规模、ROA；账面权益 she /优先股 ps / mb2；市值与微盘过滤。
   (1.3) 滞后总资产 l_at；要求有上一年 AT（删首年等）。
   (1.4) 构造 Jones 自变量 iv_1–iv_3 与 iv_4（ROA_{t−1}）；TA：heese_ta（原 WC dss）、
         dss_ta（原 ko=heese−dp）、ali/yu/ge；scaled 为 dv_ta_*。
   (1.5) da_heese/da_dss/da_ali/da_yu/da_ge：SIC-2×year 内 asreg 于 iv_1 iv_22 iv_3（Modified Jones），
         因变量为 dv_ta_heese、dv_ta_dss、dv_ta_ali、dv_ta_yu、dv_ta_ge。
         da_ko：同组内 asreg dv_ta_dss 于 iv_1 iv_22 iv_3 iv_4 与常数项（与 da_dss 同 TA、多 L.ROA）。
   (1.6) REM：prod_scaled、disexp_scaled 在 SIC-2×year 内 asreg（组内 n≥10），
         残差 ab_prod、ab_disexp；ab_disexp_neg = −ab_disexp；
         rem_heese = ab_prod + ab_disexp_neg。
   产出：$PROJ_DATA\dv_em_v3.dta
   ==================================================================== */

display as text _newline ">>> Part 1: Heese-aligned EM from raw Compustat..."

use `"`comp_file'"', clear

capture confirm numeric variable sic
if _rc {
    destring sic, replace force
}
gen sic_num = sic

drop if inrange(sic_num, 6000, 6999)
* Utilities (e.g. Ni, 2020; SIC 4910–4939)
//drop if inrange(sic_num, 4910, 4939)
* Regulated (Zang, 2012)
//drop if inrange(sic_num, 4400,4999)

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

bysort gvkey: egen int _first_year = min(fyear)
gen firm_age = fyear - _first_year
drop _first_year

log_sample, step("After base Compustat filters")

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
replace she = ceq if missing(she) & !missing(ceq)
replace she = at - lt - mib if missing(she) & !missing(at) & !missing(lt) & !missing(mib)
replace she = at - lt if missing(she) & !missing(at) & !missing(lt)

gen double ps = .
capture replace ps = pstkrv if !missing(pstkrv)
capture replace ps = pstkl if missing(ps) & !missing(pstkl)
capture replace ps = pstk if missing(ps) & !missing(pstk)
replace ps = 0 if missing(ps)

gen double txditc_fill = txditc
replace txditc_fill = 0 if missing(txditc_fill)

gen double be = she + txditc_fill - ps
drop txditc_fill
gen double mb2 = (prcc_f * csho) / be if !missing(prcc_f) & !missing(csho) & !missing(be) & be > 0
gen mv  = prcc_f * csho

drop if missing(mv) | mv < 10
log_sample, step("After market-value filter")

tostring sic_num, gen(sic_str) format(%04.0f)
gen sic_2 = substr(sic_str, 1, 2)

sort gvkey year
by gvkey: gen double l_at = at[_n-1] if year[_n-1] == year - 1
quietly count if missing(l_at)
display as text "  [INFO] Dropping obs with no prior-year AT (incl. first firm-year): " r(N)
drop if missing(l_at)
log_sample, step("After lagged-assets requirement")

capture confirm variable txp
if _rc {
    display as error "Compustat file must include txp (TXP) for d_txp / ali_ta."
    exit 601
}

by gvkey: gen double d_act  = act  - act[_n-1]  if year[_n-1] == year - 1
by gvkey: gen double d_lct  = lct  - lct[_n-1]  if year[_n-1] == year - 1
by gvkey: gen double d_che  = che  - che[_n-1]  if year[_n-1] == year - 1
by gvkey: gen double d_dlc  = dlc  - dlc[_n-1]  if year[_n-1] == year - 1
by gvkey: gen double d_revt = revt - revt[_n-1] if year[_n-1] == year - 1
by gvkey: gen double d_rect = rect - rect[_n-1] if year[_n-1] == year - 1
by gvkey: gen double d_txp  = txp  - txp[_n-1]  if year[_n-1] == year - 1
label var d_txp "Δ Income taxes payable (txp)"

gen double heese_ta = d_act - d_lct - d_che + d_dlc if !missing(d_act, d_lct, d_che, d_dlc)
label var heese_ta "WC accrual (prior dss_ta / Heese base)"

gen double dss_ta = heese_ta - dp if !missing(heese_ta) & !missing(dp)
label var dss_ta "WC accrual − dp (prior ko_ta)"

gen double ali_ta = heese_ta + d_txp - dp if !missing(heese_ta, d_txp, dp)
label var ali_ta "heese_ta + d_txp − dp"

gen double yu_ta = ni - oancf if !missing(ni) & !missing(oancf)
label var yu_ta "CF accruals: NI - OANCF"

gen double ge_ta = ibc - oancf if !missing(ibc) & !missing(oancf)
label var ge_ta "CF accruals: IBC - OANCF (IS-CF match)"

gen double dv_ta_heese = heese_ta / l_at if !missing(heese_ta) & !missing(l_at)
gen double dv_ta_dss   = dss_ta   / l_at if !missing(dss_ta)   & !missing(l_at)
gen double dv_ta_ali   = ali_ta   / l_at if !missing(ali_ta)   & !missing(l_at)
gen double dv_ta_yu    = yu_ta    / l_at if !missing(yu_ta)    & !missing(l_at)
gen double dv_ta_ge    = ge_ta    / l_at if !missing(ge_ta)    & !missing(l_at)

label var dv_ta_heese "heese_ta / lag AT"
label var dv_ta_dss   "dss_ta / lag AT"
label var dv_ta_ali   "ali_ta / lag AT"
label var dv_ta_yu    "yu_ta / lag AT"
label var dv_ta_ge    "ge_ta / lag AT"

gen double iv_1 = 1 / l_at
gen double iv_22 = (d_revt - d_rect) / l_at if !missing(d_revt) & !missing(d_rect) & !missing(l_at)
gen double iv_3 = ppegt / l_at

sort gvkey year
by gvkey: gen double iv_4 = roa[_n-1] if year[_n-1] == year - 1
label var iv_4 "L.ROA (ROA_{t−1}) for da_ko asreg"

foreach stub in heese dss ali yu ge {
    local dv dv_ta_`stub'
    display as text "  DA (`stub'): modified Jones on `dv' (SIC-2 × year)..."
    // asreg 默认含截距（同 regress；勿加 nocons）；残差用 _b_cons
    bys year sic_2: asreg `dv' iv_1 iv_22 iv_3
    gen double da_`stub' = `dv' - (_b_iv_1 * iv_1 + _b_iv_22 * iv_22 + _b_iv_3 * iv_3 + _b_cons)
    drop _Nobs _R2 _adjR2 _b_iv_1 _b_iv_22 _b_iv_3 _b_cons
}

* da_ko：asreg 默认含截距；残差式含 _b_cons
display as text "  DA (ko): asreg on dv_ta_dss with iv_1–iv_4 (SIC-2 × year)..."
bys year sic_2: asreg dv_ta_dss iv_1 iv_22 iv_3 iv_4
gen double da_ko = dv_ta_dss - ///
    (_b_iv_1 * iv_1 + _b_iv_22 * iv_22 + _b_iv_3 * iv_3 + _b_iv_4 * iv_4 + _b_cons)
drop _Nobs _R2 _adjR2 _b_iv_1 _b_iv_22 _b_iv_3 _b_iv_4 _b_cons

sort gvkey year

label var da_heese "Modified-Jones DA; TA=dv_ta_heese (heese WC / lag AT)"
label var da_dss   "Modified-Jones DA; TA=dv_ta_dss (dss_ta / lag AT)"
label var da_ko    "Residual DA; norm on dv_ta_dss with iv_1–iv_4 + const (SIC-2×year)"
label var da_ali   "Modified-Jones DA; TA=dv_ta_ali (heese+Δtxp−dep)"
label var da_yu    "Modified-Jones DA; TA=dv_ta_yu (NI-OANCF)"
label var da_ge    "Modified-Jones DA; TA=dv_ta_ge (IBC-OANCF)"

drop d_act d_lct d_che d_dlc d_revt d_rect d_txp

gen double sale_scaled = sale / l_at
by gvkey: gen double d_sale_scaled = (sale - sale[_n-1]) / l_at if year[_n-1] == year - 1
by gvkey: gen double l_d_sale_scaled = d_sale_scaled[_n-1] if year[_n-1] == year - 1
by gvkey: gen double l_sale_scaled = sale_scaled[_n-1] if year[_n-1] == year - 1

replace invch = 0 if missing(invch)
gen double prod_scaled = (cogs + invch) / l_at if !missing(cogs)

replace xrd = 0 if missing(xrd)
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
   SECTION 2 — Merge 外部表、派生变量 → final_analysis_v3.dta

   Step 1  KLD        (cusip_8 × fyear)  → KLD strengths / concerns
   Step 2  IO         (cusip_8 × fyear)  → per_* 机构持股
   Step 2b panel_zy   (cusip × fyear)   → bod_*、com_*（temp 内先 drop com_str/com_con 再 unab）
   Step 3  Refinitiv V2 (cusip_8 × year) → fid{1-16,200,206,239,269,422}_{value,vscore}
   Step 4  MSCI       (cusip_8 × year)   → issuer/IVA、支柱与主题分等（见 keepusing）
   Step 5  Duality    (gvkey   × year)   → duality
   Step 6  ExecuComp  (gvkey   × year)  → CEO/CFO controls, interim flags
   Step 7  IBES       (cusip_8 × year)  → numest, numup, numdown (analyst coverage / revisions)

   派生：culpa、industry_type、emp_kld/env_kld/kld_es_total、
         loss、adj_roa、big_4、growth_asset、env_soc_score。
   ==================================================================== */

display as text _newline ">>> Part 2: Merges, derived variables, final panel..."

use "$PROJ_DATA\dv_em_v3.dta", clear
replace year = fyear if missing(year)

* --- Step 1: KLD (cusip_8 × fyear) → strengths / concerns -----------------
preserve
use `"`kld_file'"', clear
gen cusip_8 = substr(cusip, 1, 8)
duplicates drop cusip_8 fyear, force
tempfile kld_temp
save `kld_temp'
restore

merge 1:1 cusip_8 fyear using `kld_temp', ///
    nogen keep(1 3) ///
    keepusing(env_str_* env_con_* com_str_* com_con_* hum_str_* hum_con_* ///
              emp_str_* emp_con_* div_str_* div_con_* pro_str_* pro_con_* ///
              cgov_str_* cgov_con_* alc_con_* gam_con_* mil_con_* nuc_con_* tob_con_*)
log_sample, step("Step 1: KLD merge")

* --- Step 2: IO (cusip_8 × fyear) → per_* ---------------------------------
preserve
use `"`io_file'"', clear
duplicates drop cusip_8 fyear, force
tempfile io_temp
save `io_temp'
restore

merge 1:1 cusip_8 fyear using `io_temp', keep(1 3) nogen keepusing(per_*)
log_sample, step("Step 2: IO merge")

* --- Step 2b: panel_zy (cusip × fyear) → bod_* com_* ------------------------
preserve
use `"`panel_zy_file'"', clear
capture drop com_str_* com_con_*
unab _bod : bod_*
unab _com : com_*
local pzy_keep `_bod' `_com'
local pzy_keep : list retokenize pzy_keep
local pzy_keep : list uniq pzy_keep
keep cusip fyear `pzy_keep'
duplicates drop cusip fyear, force
tempfile panel_zy_temp
save `panel_zy_temp'
restore

merge 1:1 cusip fyear using `panel_zy_temp', keep(1 3) nogen keepusing(`pzy_keep')
log_sample, step("Step 2b: panel_zy bod_/com_ merge")

* --- Step 3: Refinitiv V2 ESG (cusip_8 × year) → fid*_value / fid*_vscore ---
preserve
use `"`refinitiv_file'"', clear
keep if inlist(fieldid, 1,2,3,4,5,6,7,8,9,10) | ///
    inlist(fieldid, 11,12,13,14,15,16,200,206,239,263) | ///
    inlist(fieldid, 269, 422)
drop if cusip == ""
gen cusip_8 = substr(cusip, 1, 8)
duplicates drop cusip_8 year fieldid, force
keep cusip_8 year fieldid fieldname value valuescore

foreach fid in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 200 206 239 263 269 422 {
    quietly levelsof fieldname if fieldid == `fid', local(_fn) clean
    local label_`fid' `"`_fn'"'
}
tempfile ref_all
save `ref_all'
restore

foreach fid in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 200 206 239 263 269 422 {
    preserve
    use `ref_all', clear
    keep if fieldid == `fid'
    rename value     fid`fid'_value
    rename valuescore fid`fid'_vscore
    label var fid`fid'_value  `"`label_`fid''"'
    label var fid`fid'_vscore `"`label_`fid'' (score)"'
    duplicates drop cusip_8 year, force
    keep cusip_8 year fid`fid'_value fid`fid'_vscore
    tempfile _ref`fid'
    save `_ref`fid''
    restore
    merge 1:1 cusip_8 year using `_ref`fid'', keep(1 3) nogen
}
log_sample, step("Step 3: Refinitiv V2 ESG merge")

* --- Step 4: MSCI (cusip_8 × year) → issuer / IVA / pillars / themes -------
merge 1:1 cusip_8 year using `"`msci_file'"', keep(1 3) nogen ///
    keepusing(issuer_name issuerid issuer_ticker issuer_cusip issuer_sedol issuer_isin ///
        issuer_cntry_domicile iva_industry iva_rating_date iva_company_rating ///
        iva_previous_rating iva_rating_trend industry_adjusted_score ///
        weighted_average_score environmental_pillar_score environmental_pillar_weight ///
        social_pillar_score social_pillar_weight governance_pillar_score ///
        governance_pillar_weight climate_change_theme_score climate_change_theme_weight ///
        natural_res_use_theme_score natural_res_use_theme_weight ///
        waste_mgmt_theme_score waste_mgmt_theme_weight ///
        environmental_opps_theme_score environmental_opps_theme_weight ///
        human_capital_theme_score human_capital_theme_weight ///
        product_safety_theme_score product_safety_theme_weight ///
        social_opps_theme_score social_opps_theme_weight ///
        corporate_gov_theme_score corporate_gov_theme_weight ///
        business_ethics_theme_score business_ethics_theme_weight ///
        stakeholder_opposit_theme_score stakeholder_opposit_theme_weight ///
        carbon_emissions_score carbon_emissions_weight carbon_emissions_exp_score ///
        carbon_emissions_mgmt_score)
log_sample, step("Step 4: MSCI merge")

* --- Step 5: Duality (gvkey × year) → duality -----------------------------
preserve
use `"`duality_file'"', clear
duplicates drop gvkey year, force
tempfile dual_temp
save `dual_temp'
restore

merge 1:1 gvkey year using `dual_temp', keep(1 3) keepusing(duality) update nogen
log_sample, step("Step 5: Duality merge")

* --- Step 6: ExecuComp CEO/CFO (gvkey × year) → controls + interim flags ----

* 6a — CEO-level variables
preserve
use `"`execucomp_file'"', clear
keep if ceoann == "CEO"

gen byte interim_ceo = regexm(lower(titleann), "(interim|acting).*(chief executive|\bceo\b|principal executive)")

bysort co_per_rol (year): gen int ceo_tenure = _n

rename age ceo_age
gen byte ceo_female = (lower(gender) == "female") if gender != ""

gen double ceo_cash_comp    = total_curr
gen double ceo_option_fv    = option_awards_fv
gen double ceo_stock_fv     = stock_awards_fv
gen double ceo_option_ratio = option_awards_fv / tdc1 if !missing(option_awards_fv) & tdc1 > 0
gen double ceo_ownership    = shrown_excl_opts

gen double ceo_tdc1 = tdc1

gsort gvkey year -ceo_tdc1
duplicates drop gvkey year, force

keep gvkey year interim_ceo ceo_tenure ceo_age ceo_female ///
    ceo_cash_comp ceo_option_fv ceo_stock_fv ceo_option_ratio ///
    ceo_ownership ceo_tdc1
tempfile ceo_temp
save `ceo_temp'

* 6b — CFO interim flag
use `"`execucomp_file'"', clear
keep if inlist(cfoann, "CFO", "CfO")

gen byte interim_cfo = regexm(lower(titleann), "(interim|acting).*(chief financial|\bcfo\b|principal financial)")

bysort co_per_rol (year): gen int cfo_tenure = _n
rename age cfo_age
gen byte cfo_female = (lower(gender) == "female") if gender != ""

gsort gvkey year -tdc1
duplicates drop gvkey year, force

keep gvkey year interim_cfo cfo_tenure cfo_age cfo_female
tempfile cfo_temp
save `cfo_temp'
restore

merge 1:1 gvkey year using `ceo_temp', keep(1 3) nogen
merge 1:1 gvkey year using `cfo_temp', keep(1 3) nogen
log_sample, step("Step 6: ExecuComp CEO/CFO merge")

* --- Step 7: IBES Summary (cusip_8 × year) → numest, numup, numdown ---------
preserve
use `"`ibes_file'"', clear

keep if measure == "EPS" & fpi == 1

gen long stata_statpers = date(statpers, "YMD")
gen long stata_fpedats  = date(fpedats, "YMD")
format stata_statpers stata_fpedats %td

drop if missing(stata_statpers) | missing(stata_fpedats)
keep if stata_statpers < stata_fpedats

bysort cusip fpedats (stata_statpers): keep if _n == _N

gen year = year(stata_fpedats)
rename cusip cusip_8

gsort cusip_8 year -numest
duplicates drop cusip_8 year, force

keep cusip_8 year numest numup numdown
tempfile ibes_temp
save `ibes_temp'
restore

merge 1:1 cusip_8 year using `ibes_temp', keep(1 3) nogen keepusing(numest numup numdown)
log_sample, step("Step 7: IBES analyst coverage merge")

* --- Derived variables -----------------------------------------------------

gen emp_kld = emp_str_num1 - emp_con_num1
gen env_kld = env_str_num1 - env_con_num1
gen kld_es_total = env_kld + emp_kld

gen byte culpa = 0
unab sinvars : alc_con_* gam_con_* mil_con_* nuc_con_* tob_con_*
foreach v of local sinvars {
    replace culpa = 1 if `v' == 1
}

gen byte industry_type = 0
replace industry_type = 1 if inrange(sic_num, 2100, 2199)
replace industry_type = 1 if inrange(sic_num, 3760, 3769) | sic_num == 3795 | inrange(sic_num, 3480, 3489)
replace industry_type = 1 if inrange(sic_num, 800, 899) | inrange(sic_num, 1000, 1119) | inrange(sic_num, 1400, 1499)
replace industry_type = 1 if sic_num == 2080 | inrange(sic_num, 2082, 2085)
replace industry_type = 1 if culpa == 1

gen byte loss = (ni < 0) if !missing(ni)
bysort sic_2 year: egen double aver_roa = mean(roa)
gen double adj_roa = roa - aver_roa

gen big_4 = inlist(au, 4, 5, 6, 7) if !missing(au)

sort gvkey year
by gvkey: gen double _l_at = at[_n-1] if year[_n-1] == year - 1
gen double growth_asset = (at - _l_at) / _l_at if !missing(_l_at) & _l_at > 0
drop _l_at

gen double env_soc_score = fid4_vscore + fid6_vscore if !missing(fid4_vscore) & !missing(fid6_vscore)
label var env_soc_score "Environment + Social pillar score"

sort gvkey year
isid gvkey year

compress
save "$PROJ_DATA\final_analysis_v3.dta", replace
display as text ">>> Part 2 done: final_analysis_v3.dta (firm-year panel)"
display as text ">>> Merge v3 finished: $S_DATE $S_TIME"
log close
