/* ====================================================================
   SEC 2010 SHIFT-SHARE IV WITH MULTIPLE MATCHING METHODS
   Project: Corporate ESG Engagement and Earnings Management
   Date: 2026-03-25

   Design:
     Shift = SEC 2010 Climate Change Disclosure Guidance (Release 33-9106)
     Share = Pre-determined (2007-2009) firm-level sales exposure
     
   IV Specifications:
     IV1: Fuzzy DID — high_carbon × post_2010 instruments for ESG
     IV2: Sales-weighted Bartik — baseline_mkt_share × high_carbon × post_2010
     IV3: Continuous intensity — baseline_mkt_share × industry_ESG_shift
     
   Matching Methods:
     A. Raw (unmatched)
     B. Entropy Balance
     C. PSM (propensity score matching)
     D. Nearest-neighbor (teffects nnmatch)

   DVs: Signed DA (MJ), Signed DA (Kothari), REM
   ==================================================================== */

version 17
clear all
set more off
set matsize 10000
capture log close

global ROOT      "c:\Users\HuGoL\OneDrive - HKUST (Guangzhou)\PhD\3_Research\Moral Lisensing"
global RAW_DATA  "D:\Research\Data"
global PROJ_DATA "$ROOT\data"
global OUTPUT    "$ROOT\output"

cd "$ROOT\code"
log using "$ROOT\code\sec2010_shiftshare_log.log", replace

foreach pkg in reghdfe estout winsor2 ebalance {
    capture which `pkg'
    if _rc {
        ssc install `pkg'
    }
}
capture which psmatch2
if _rc {
    ssc install psmatch2
}

display as text _newline ">>> SEC 2010 Shift-Share IV: $S_DATE $S_TIME"

global ctrl_core size mb2 lev roa growth_asset cash_holding big_4 noa mkt_share loss


/* ====================================================================
   PART 1: DATA PREPARATION
   ==================================================================== */
display as text _newline ">>> Part 1: Data Prep"

use "$PROJ_DATA\final_analysis_v2.dta", clear

* --- 1.1 Define high-carbon industries ---
gen sic_2_num = real(sic_2)
gen byte high_carbon = 0
replace high_carbon = 1 if inrange(sic_2_num, 10, 14)
replace high_carbon = 1 if sic_2_num == 26
replace high_carbon = 1 if sic_2_num == 28
replace high_carbon = 1 if sic_2_num == 29
replace high_carbon = 1 if sic_2_num == 32
replace high_carbon = 1 if sic_2_num == 33
replace high_carbon = 1 if sic_2_num == 49
label var high_carbon "High-Carbon Industry"

gen byte post_2010 = (fyear >= 2010)
label var post_2010 "Post SEC 2010"

* --- 1.2 Restrict to window around 2010 ---
keep if inrange(fyear, 2005, 2017)
display as text "  Sample restricted to 2005-2017"
quietly count
display as text "  N = " r(N)

tab high_carbon

* --- 1.3 Compute BASELINE (2007-2009) market share ---
* Pre-determined share: average firm sales / industry total, fixed at baseline
preserve
keep if inrange(fyear, 2007, 2009)
bysort sic_2: egen double _ind_sale_tot = total(sale)
gen double _firm_mktshare = sale / _ind_sale_tot
bysort gvkey: egen double base_mktshare = mean(_firm_mktshare)
keep gvkey base_mktshare
duplicates drop gvkey, force
tempfile baseline_shares
save `baseline_shares'
restore

merge m:1 gvkey using `baseline_shares', keep(1 3) nogen
replace base_mktshare = 0 if missing(base_mktshare)
label var base_mktshare "Baseline Market Share (2007-2009)"

* --- 1.4 Compute baseline firm size (for matching) ---
preserve
keep if inrange(fyear, 2007, 2009)
bysort gvkey: egen double base_size = mean(size)
bysort gvkey: egen double base_roa = mean(roa)
bysort gvkey: egen double base_lev = mean(lev)
bysort gvkey: egen double base_mb2 = mean(mb2)
keep gvkey base_size base_roa base_lev base_mb2
duplicates drop gvkey, force
tempfile baseline_chars
save `baseline_chars'
restore

merge m:1 gvkey using `baseline_chars', keep(1 3) nogen

* --- 1.5 Compute industry-level ESG shift ---
* Shift = industry-year average ESG (leave-one-out) minus pre-2010 industry mean
bysort sic_2 fyear: egen double _sum_vs4 = total(vs_4)
bysort sic_2 fyear: egen _cnt_vs4 = count(vs_4)
gen double ind_esg_loo = (_sum_vs4 - vs_4) / (_cnt_vs4 - 1) if _cnt_vs4 > 1 & !missing(vs_4)
drop _sum_vs4 _cnt_vs4

* Pre-2010 industry ESG mean (for shift calculation)
bysort sic_2: egen double _pre_esg = mean(cond(fyear < 2010, ind_esg_loo, .))
gen double esg_shift = ind_esg_loo - _pre_esg
drop _pre_esg
label var esg_shift "Industry ESG Shift (rel. to pre-2010)"

* --- 1.6 Construct IV variants ---

* IV1: Fuzzy DID instrument
gen double iv_fuzzy = high_carbon * post_2010
label var iv_fuzzy "IV1: HighCarbon x Post2010"

* IV2: Sales-weighted Bartik
gen double iv_bartik = base_mktshare * high_carbon * post_2010
label var iv_bartik "IV2: BaseShare x HighCarbon x Post2010"

* IV3: Continuous intensity Bartik
gen double iv_cont = base_mktshare * esg_shift if !missing(esg_shift)
label var iv_cont "IV3: BaseShare x ESG_Shift"

* --- 1.7 Lagged DA ---
sort gvkey fyear
by gvkey: gen L_da_mj = ko_da_sic[_n-1] if fyear[_n-1] == fyear - 1
label var L_da_mj "L.DA (MJ)"

* Winsorize
winsor2 vs_4 ko_da_sic ko_da_kothari rem_heese iv_cont base_mktshare esg_shift, cuts(0.5 99.5) replace

xtset gvkey fyear

display as text "  IV diagnostics:"
foreach v in iv_fuzzy iv_bartik iv_cont {
    quietly count if !missing(`v') & !missing(vs_4) & !missing(ko_da_sic)
    display as text "  `v': " r(N) " usable obs"
}

label var ko_da_sic     "DA (MJ, signed)"
label var ko_da_kothari "DA (Kothari, signed)"
capture label var rem_heese    "REM (Heese)"


/* ====================================================================
   PART 2: FUZZY DID-IV (IV1) — HIGH_CARBON × POST_2010
   Instruments ESG with SEC 2010 shock, then estimates ESG → DA
   ==================================================================== */
display as text _newline "=========================================="
display as text ">>> Part 2: Fuzzy DID-IV (HighCarbon × Post2010)"
display as text "=========================================="

* --- 2A. No matching (raw) ---
eststo clear

* First stage: ESG = f(high_carbon × post_2010)
reghdfe vs_4 iv_fuzzy $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo f1_1st
estadd local fe "Firm+Year"
test iv_fuzzy
estadd scalar F_first = r(F)

* 2SLS: DA (MJ)
capture drop _hat
reghdfe vs_4 iv_fuzzy $ctrl_core, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe ko_da_sic _hat $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo f1_mj
estadd local fe "Firm+Year"
drop _hat

* 2SLS: DA (Kothari)
capture drop _hat
reghdfe vs_4 iv_fuzzy $ctrl_core, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe ko_da_kothari _hat $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo f1_ko
estadd local fe "Firm+Year"
drop _hat

* 2SLS: REM
capture drop _hat
reghdfe vs_4 iv_fuzzy $ctrl_core, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe rem_heese _hat $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo f1_rem
estadd local fe "Firm+Year"
drop _hat

esttab f1_1st f1_mj f1_ko f1_rem using "$OUTPUT\SEC2010_FuzzyDID_Raw.rtf", replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) label compress nogaps mtitles("1st:ESG" "DA(MJ)" "DA(Ko)" "REM") scalars("fe FE" "F_first 1st-Stage F" "N Observations" "r2_a Adj R-sq") title("Fuzzy DID-IV: SEC 2010 -> ESG -> EM (Raw)") addnotes("IV: HighCarbon x Post2010. Signed DA (Heese 2023)." "Sample: 2005-2017. Firm+Year FE. SE clustered at firm.")


/* ====================================================================
   PART 3: SALES-WEIGHTED BARTIK IV (IV2)
   ==================================================================== */
display as text _newline "=========================================="
display as text ">>> Part 3: Sales-Weighted Bartik IV"
display as text "=========================================="

eststo clear

* First stage
reghdfe vs_4 iv_bartik $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo b2_1st
estadd local fe "Firm+Year"
test iv_bartik
estadd scalar F_first = r(F)

* 2SLS: DA (MJ)
capture drop _hat
reghdfe vs_4 iv_bartik $ctrl_core, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe ko_da_sic _hat $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo b2_mj
estadd local fe "Firm+Year"
drop _hat

* 2SLS: DA (Kothari)
capture drop _hat
reghdfe vs_4 iv_bartik $ctrl_core, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe ko_da_kothari _hat $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo b2_ko
estadd local fe "Firm+Year"
drop _hat

* 2SLS: REM
capture drop _hat
reghdfe vs_4 iv_bartik $ctrl_core, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe rem_heese _hat $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo b2_rem
estadd local fe "Firm+Year"
drop _hat

esttab b2_1st b2_mj b2_ko b2_rem using "$OUTPUT\SEC2010_Bartik_Sales.rtf", replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) label compress nogaps mtitles("1st:ESG" "DA(MJ)" "DA(Ko)" "REM") scalars("fe FE" "F_first 1st-Stage F" "N Observations" "r2_a Adj R-sq") title("Sales-Weighted Bartik IV: SEC 2010 Shift-Share") addnotes("IV: BaselineMktShare(07-09) x HighCarbon x Post2010." "Shift=SEC2010; Share=pre-determined sales weight." "Firm+Year FE. SE clustered at firm.")


/* ====================================================================
   PART 4: CONTINUOUS BARTIK IV (IV3)
   ==================================================================== */
display as text _newline "=========================================="
display as text ">>> Part 4: Continuous Bartik (Share × ESG Shift)"
display as text "=========================================="

eststo clear

reghdfe vs_4 iv_cont $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo b3_1st
estadd local fe "Firm+Year"
test iv_cont
estadd scalar F_first = r(F)

capture drop _hat
reghdfe vs_4 iv_cont $ctrl_core, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe ko_da_sic _hat $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo b3_mj
estadd local fe "Firm+Year"
drop _hat

capture drop _hat
reghdfe vs_4 iv_cont $ctrl_core, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe ko_da_kothari _hat $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo b3_ko
estadd local fe "Firm+Year"
drop _hat

capture drop _hat
reghdfe vs_4 iv_cont $ctrl_core, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe rem_heese _hat $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo b3_rem
estadd local fe "Firm+Year"
drop _hat

esttab b3_1st b3_mj b3_ko b3_rem using "$OUTPUT\SEC2010_ContBartik.rtf", replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) label compress nogaps mtitles("1st:ESG" "DA(MJ)" "DA(Ko)" "REM") scalars("fe FE" "F_first 1st-Stage F" "N Observations" "r2_a Adj R-sq") title("Continuous Bartik IV: BaseShare × ESG Industry Shift") addnotes("IV: BaselineMktShare(07-09) x Industry ESG Shift (rel. pre-2010)." "Firm+Year FE. SE clustered at firm.")


/* ====================================================================
   PART 5: MATCHING METHOD A — ENTROPY BALANCE
   Use EBM to reweight control group to match treated (high-carbon) on
   baseline characteristics, then run Fuzzy DID-IV on reweighted sample.
   ==================================================================== */
display as text _newline "=========================================="
display as text ">>> Part 5: Entropy Balance Matching"
display as text "=========================================="

* EBM on baseline characteristics
capture drop _webal
ebalance high_carbon base_size base_roa base_lev base_mb2, targets(1)

display "  EBM weight summary:"
summarize _webal if high_carbon == 0, detail
summarize _webal if high_carbon == 1, detail

eststo clear

* First stage (weighted)
reghdfe vs_4 iv_fuzzy $ctrl_core [aweight=_webal], absorb(gvkey fyear) cluster(gvkey)
eststo eb_1st
estadd local fe "Firm+Year"
estadd local matching "EBM"
test iv_fuzzy
estadd scalar F_first = r(F)

* 2SLS: DA (MJ) weighted
capture drop _hat
reghdfe vs_4 iv_fuzzy $ctrl_core [aweight=_webal], absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe ko_da_sic _hat $ctrl_core [aweight=_webal], absorb(gvkey fyear) cluster(gvkey)
eststo eb_mj
estadd local fe "Firm+Year"
estadd local matching "EBM"
drop _hat

* 2SLS: DA (Kothari) weighted
capture drop _hat
reghdfe vs_4 iv_fuzzy $ctrl_core [aweight=_webal], absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe ko_da_kothari _hat $ctrl_core [aweight=_webal], absorb(gvkey fyear) cluster(gvkey)
eststo eb_ko
estadd local fe "Firm+Year"
estadd local matching "EBM"
drop _hat

* 2SLS: REM weighted
capture drop _hat
reghdfe vs_4 iv_fuzzy $ctrl_core [aweight=_webal], absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe rem_heese _hat $ctrl_core [aweight=_webal], absorb(gvkey fyear) cluster(gvkey)
eststo eb_rem
estadd local fe "Firm+Year"
estadd local matching "EBM"
drop _hat

esttab eb_1st eb_mj eb_ko eb_rem using "$OUTPUT\SEC2010_FuzzyDID_EBM.rtf", replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) label compress nogaps mtitles("1st:ESG" "DA(MJ)" "DA(Ko)" "REM") scalars("fe FE" "matching Matching" "F_first 1st-Stage F" "N Observations" "r2_a Adj R-sq") title("Fuzzy DID-IV with Entropy Balance Matching") addnotes("EBM on baseline (2007-09) Size, ROA, Leverage, MB." "IV: HighCarbon x Post2010. Firm+Year FE.")


/* ====================================================================
   PART 6: MATCHING METHOD B — PSM
   Propensity score matching: match high-carbon to non-high-carbon firms
   on baseline characteristics, then run IV on matched sample.
   ==================================================================== */
display as text _newline "=========================================="
display as text ">>> Part 6: PSM Matching"
display as text "=========================================="

* PSM: propensity of being in high-carbon industry based on baseline chars
* Use LPM to avoid quasi-complete separation in logit/probit
capture drop _pscore _treated _support
regress high_carbon base_size base_roa base_lev base_mb2
predict double _pscore
replace _pscore = max(_pscore, 0.001)
replace _pscore = min(_pscore, 0.999)

* Trim propensity scores to common support
summarize _pscore if high_carbon == 1, detail
local ps_min_t = r(min)
local ps_max_t = r(max)
summarize _pscore if high_carbon == 0, detail
local ps_min_c = r(min)
local ps_max_c = r(max)
local cs_low = max(`ps_min_t', `ps_min_c')
local cs_high = min(`ps_max_t', `ps_max_c')
gen byte _support = inrange(_pscore, `cs_low', `cs_high')
display as text "  Common support: [`cs_low', `cs_high']"
tab high_carbon _support

* Generate IPW weights from propensity score
gen double _ipw = .
replace _ipw = 1 if high_carbon == 1 & _support == 1
replace _ipw = _pscore / (1 - _pscore) if high_carbon == 0 & _support == 1

eststo clear

* First stage (IPW weighted)
reghdfe vs_4 iv_fuzzy $ctrl_core [aweight=_ipw] if _support == 1, absorb(gvkey fyear) cluster(gvkey)
eststo ps_1st
estadd local fe "Firm+Year"
estadd local matching "PS-IPW"
test iv_fuzzy
estadd scalar F_first = r(F)

* 2SLS: DA (MJ)
capture drop _hat
reghdfe vs_4 iv_fuzzy $ctrl_core [aweight=_ipw] if _support == 1, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat if _support == 1, xb
reghdfe ko_da_sic _hat $ctrl_core [aweight=_ipw] if _support == 1, absorb(gvkey fyear) cluster(gvkey)
eststo ps_mj
estadd local fe "Firm+Year"
estadd local matching "PS-IPW"
drop _hat

* 2SLS: DA (Kothari)
capture drop _hat
reghdfe vs_4 iv_fuzzy $ctrl_core [aweight=_ipw] if _support == 1, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat if _support == 1, xb
reghdfe ko_da_kothari _hat $ctrl_core [aweight=_ipw] if _support == 1, absorb(gvkey fyear) cluster(gvkey)
eststo ps_ko
estadd local fe "Firm+Year"
estadd local matching "PS-IPW"
drop _hat

* 2SLS: REM
capture drop _hat
reghdfe vs_4 iv_fuzzy $ctrl_core [aweight=_ipw] if _support == 1, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat if _support == 1, xb
reghdfe rem_heese _hat $ctrl_core [aweight=_ipw] if _support == 1, absorb(gvkey fyear) cluster(gvkey)
eststo ps_rem
estadd local fe "Firm+Year"
estadd local matching "PS-IPW"
drop _hat

esttab ps_1st ps_mj ps_ko ps_rem using "$OUTPUT\SEC2010_FuzzyDID_PSM.rtf", replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) label compress nogaps mtitles("1st:ESG" "DA(MJ)" "DA(Ko)" "REM") scalars("fe FE" "matching Matching" "F_first 1st-Stage F" "N Observations" "r2_a Adj R-sq") title("Fuzzy DID-IV with Propensity Score IPW") addnotes("PS estimated from baseline Size, ROA, Leverage, MB." "IPW: treated weight=1, control weight=p/(1-p)." "Common support restriction applied." "IV: HighCarbon x Post2010. Firm+Year FE.")


/* ====================================================================
   PART 7: TIGHT WINDOW + HIGH-CARBON SUBSAMPLE ANALYSIS
   Restrict to 2007-2013 for cleaner identification.
   Also test within high-carbon industries (intensive margin).
   ==================================================================== */
display as text _newline "=========================================="
display as text ">>> Part 7: Tight Window (2007-2013) + Subsample"
display as text "=========================================="

eststo clear

* --- 7A. Tight window full sample ---
preserve
keep if inrange(fyear, 2007, 2013)

reghdfe vs_4 iv_fuzzy $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo tw_1st
estadd local fe "Firm+Year"
estadd local window "2007-2013"
test iv_fuzzy
estadd scalar F_first = r(F)

capture drop _hat
reghdfe vs_4 iv_fuzzy $ctrl_core, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe ko_da_sic _hat $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo tw_mj
estadd local fe "Firm+Year"
estadd local window "2007-2013"
drop _hat

capture drop _hat
reghdfe vs_4 iv_fuzzy $ctrl_core, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe ko_da_kothari _hat $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo tw_ko
estadd local fe "Firm+Year"
estadd local window "2007-2013"
drop _hat

capture drop _hat
reghdfe vs_4 iv_fuzzy $ctrl_core, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe rem_heese _hat $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo tw_rem
estadd local fe "Firm+Year"
estadd local window "2007-2013"
drop _hat

restore

* --- 7B. High-carbon subsample: intensive margin ---
* Within treated industries, firms with higher baseline ESG should show MORE licensing
preserve
keep if high_carbon == 1 & inrange(fyear, 2005, 2017)

* Use leave-one-out peer ESG as IV within high-carbon
capture drop _sm _cn _loo_esg
bysort sic_2 fyear: egen double _sm = total(vs_4)
bysort sic_2 fyear: egen _cn = count(vs_4)
gen double _loo_esg = (_sm - vs_4) / (_cn - 1) if _cn > 1 & !missing(vs_4)
drop _sm _cn

reghdfe vs_4 _loo_esg $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo hc_1st
estadd local fe "Firm+Year"
estadd local sample "HighCarbon only"
test _loo_esg
estadd scalar F_first = r(F)

capture drop _hat
reghdfe vs_4 _loo_esg $ctrl_core, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe ko_da_sic _hat $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo hc_mj
estadd local fe "Firm+Year"
estadd local sample "HighCarbon only"
drop _hat

capture drop _hat
reghdfe vs_4 _loo_esg $ctrl_core, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe rem_heese _hat $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo hc_rem
estadd local fe "Firm+Year"
estadd local sample "HighCarbon only"
drop _hat

restore

esttab tw_1st tw_mj tw_ko tw_rem hc_1st hc_mj hc_rem using "$OUTPUT\SEC2010_TightWindow_Subsample.rtf", replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) label compress nogaps mtitles("TW:1st" "TW:DA(MJ)" "TW:DA(Ko)" "TW:REM" "HC:1st" "HC:DA(MJ)" "HC:REM") scalars("fe FE" "window Window" "sample Sample" "F_first 1st-Stage F" "N Observations" "r2_a Adj R-sq") title("Tight Window (2007-2013) + High-Carbon Subsample") addnotes("Left: Full sample, tight window 2007-2013." "Right: High-carbon subsample, peer ESG IV, 2005-2017.")


/* ====================================================================
   PART 8: REDUCED FORM + OLS COMPARISON
   Also include L.DA control version
   ==================================================================== */
display as text _newline "=========================================="
display as text ">>> Part 8: Reduced Form & OLS Comparison"
display as text "=========================================="

eststo clear

* OLS: direct ESG -> DA
reghdfe ko_da_sic vs_4 $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo ols_mj
estadd local fe "Firm+Year"
estadd local method "OLS"

reghdfe ko_da_kothari vs_4 $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo ols_ko
estadd local fe "Firm+Year"
estadd local method "OLS"

reghdfe rem_heese vs_4 $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo ols_rem
estadd local fe "Firm+Year"
estadd local method "OLS"

* Reduced form: SEC 2010 -> DA directly
reghdfe ko_da_sic iv_fuzzy $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo rf_mj
estadd local fe "Firm+Year"
estadd local method "Reduced Form"

reghdfe ko_da_kothari iv_fuzzy $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo rf_ko
estadd local fe "Firm+Year"
estadd local method "Reduced Form"

reghdfe rem_heese iv_fuzzy $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo rf_rem
estadd local fe "Firm+Year"
estadd local method "Reduced Form"

* OLS with L.DA control
reghdfe ko_da_sic vs_4 L_da_mj $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo olsL_mj
estadd local fe "Firm+Year"
estadd local method "OLS+L.DA"

esttab ols_mj ols_ko ols_rem rf_mj rf_ko rf_rem olsL_mj using "$OUTPUT\SEC2010_OLS_RF_Comparison.rtf", replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) label compress nogaps mtitles("OLS:DA(MJ)" "OLS:DA(Ko)" "OLS:REM" "RF:DA(MJ)" "RF:DA(Ko)" "RF:REM" "OLS+L.DA") scalars("fe FE" "method Method" "N Observations" "r2_a Adj R-sq") title("OLS vs Reduced Form vs OLS+L.DA: Environmental Score -> EM") addnotes("OLS: direct vs_4 -> DA. RF: high_carbon x post_2010 -> DA." "Sample: 2005-2017. Firm+Year FE. SE clustered at firm.")


/* ====================================================================
   PART 9: COMPREHENSIVE SUMMARY TABLE
   Best spec from each approach in one table
   ==================================================================== */
display as text _newline "=========================================="
display as text ">>> Part 9: Summary Table"
display as text "=========================================="

eststo clear

* Re-run best specs for consolidated output

* (1) OLS baseline
reghdfe ko_da_sic vs_4 $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo sum_ols
estadd local fe "Firm+Year"
estadd local method "OLS"

* (2) Fuzzy DID-IV (raw)
capture drop _hat
reghdfe vs_4 iv_fuzzy $ctrl_core, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe ko_da_sic _hat $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo sum_fdid
estadd local fe "Firm+Year"
estadd local method "FuzzyDID"
drop _hat

* (3) Fuzzy DID-IV (EBM)
capture drop _hat
reghdfe vs_4 iv_fuzzy $ctrl_core [aweight=_webal], absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe ko_da_sic _hat $ctrl_core [aweight=_webal], absorb(gvkey fyear) cluster(gvkey)
eststo sum_ebm
estadd local fe "Firm+Year"
estadd local method "FuzzyDID+EBM"
drop _hat

* (4) Fuzzy DID-IV (PS-IPW)
capture drop _hat
reghdfe vs_4 iv_fuzzy $ctrl_core [aweight=_ipw] if _support == 1, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat if _support == 1, xb
reghdfe ko_da_sic _hat $ctrl_core [aweight=_ipw] if _support == 1, absorb(gvkey fyear) cluster(gvkey)
eststo sum_psm
estadd local fe "Firm+Year"
estadd local method "FuzzyDID+IPW"
drop _hat

* (5) Sales-weighted Bartik
capture drop _hat
reghdfe vs_4 iv_bartik $ctrl_core, absorb(gvkey fyear) cluster(gvkey) resid
predict double _hat, xb
reghdfe ko_da_sic _hat $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo sum_bart
estadd local fe "Firm+Year"
estadd local method "Bartik(Sales)"
drop _hat

* (6) Reduced form
reghdfe ko_da_sic iv_fuzzy $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
eststo sum_rf
estadd local fe "Firm+Year"
estadd local method "Reduced Form"

esttab sum_ols sum_fdid sum_ebm sum_psm sum_bart sum_rf using "$OUTPUT\SEC2010_Summary_AllMethods.rtf", replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) label compress nogaps mtitles("OLS" "FuzzyDID" "FD+EBM" "FD+IPW" "Bartik" "ReducedForm") scalars("fe FE" "method Method" "N Observations" "r2_a Adj R-sq") title("SEC 2010 Shift-Share: All Methods Compared (DV: Signed DA, MJ)") addnotes("Col 1: OLS. Col 2-4: 2SLS with HighCarbon x Post2010 as IV." "Col 3: Entropy balance on baseline chars." "Col 4: PS-IPW on baseline chars, common support." "Col 5: Sales-weighted Bartik." "Col 6: Reduced form (direct DID)." "All: Firm+Year FE, SE clustered at firm.")


/* ====================================================================
   WRAP-UP
   ==================================================================== */
display as text _newline ">>> All SEC 2010 Shift-Share analyses done: $S_DATE $S_TIME"
display as text ">>> Output files:"
display as text "    SEC2010_FuzzyDID_Raw.rtf"
display as text "    SEC2010_Bartik_Sales.rtf"
display as text "    SEC2010_ContBartik.rtf"
display as text "    SEC2010_FuzzyDID_EBM.rtf"
display as text "    SEC2010_FuzzyDID_PSM.rtf"
display as text "    SEC2010_TightWindow_Subsample.rtf"
display as text "    SEC2010_OLS_RF_Comparison.rtf"
display as text "    SEC2010_Summary_AllMethods.rtf"

log close
