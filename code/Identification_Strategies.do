/* ====================================================================
   IDENTIFICATION STRATEGIES DO FILE
   Project: Corporate ESG Engagement and Earnings Management
   Date: 2026-03-25

   Description:
     Strategy 1: SEC 2010 Climate Change Disclosure DID
     Strategy 2: MSCI 2012 ESG Rating Coverage Expansion DID
     Strategy 3: MSCI ESG Rating Upgrade Stacked DID
     Strategy 4: MSCI Industry-Adjusted Score Threshold RDD
     Strategy 5: Bartik/Shift-Share IV
     Strategy 6: Placebo Test (Governance) + Mechanism (DA+ vs DA-)

   Prerequisite: Run Master_Analysis_v2.do first to generate
                 $PROJ_DATA\final_analysis_v2.dta
   ==================================================================== */

version 17
clear all
set more off
set matsize 10000
capture log close

/* ====================================================================
   PART 0: SETTINGS, PATHS & INFRASTRUCTURE
   ==================================================================== */

global ROOT      "c:\Users\HuGoL\OneDrive - HKUST (Guangzhou)\PhD\3_Research\Moral Lisensing"
global RAW_DATA  "D:\Research\Data"
global PROJ_DATA "$ROOT\data"
global OUTPUT    "$ROOT\output"

cd "$ROOT\code"
log using "$ROOT\code\identification_log.log", replace

foreach pkg in reghdfe estout winsor2 rdrobust rddensity ebalance {
    capture which `pkg'
    if _rc {
        display as error "  Package `pkg' not found. Installing..."
        ssc install `pkg'
    }
}

display as text _newline ">>> Identification Strategies started: $S_DATE $S_TIME"

global ctrl_core size mb2 lev roa growth_asset cash_holding ///
                 big_4 noa mkt_share loss


/* ====================================================================
   STRATEGY 1: SEC 2010 CLIMATE CHANGE DISCLOSURE DID
   ====================================================================
   SEC Release 33-9106 (Feb 2010): Commission Guidance Regarding
   Disclosure Related to Climate Change.
   Reference: Kim, Wang & Wu (2022, Review of Accounting Studies)
   ==================================================================== */
display as text _newline ">>> STRATEGY 1: SEC 2010 Climate Disclosure DID"

use "$PROJ_DATA\final_analysis_v2.dta", clear

* --- 1.1 Define Treatment: High-Carbon/Climate-Risk Industries ---
* Based on SIC-2 codes following Kim et al. (2022) and EPA GHG categories:
*   Mining (10-14), Paper (26), Chemicals (28), Petroleum (29),
*   Stone/Clay/Glass (32), Primary Metals (33), Utilities (49)
gen sic_2_num = real(sic_2)
gen byte high_carbon = 0
replace high_carbon = 1 if inrange(sic_2_num, 10, 14)
replace high_carbon = 1 if sic_2_num == 26
replace high_carbon = 1 if sic_2_num == 28
replace high_carbon = 1 if sic_2_num == 29
replace high_carbon = 1 if sic_2_num == 32
replace high_carbon = 1 if sic_2_num == 33
replace high_carbon = 1 if sic_2_num == 49
label var high_carbon "High-Carbon Industry (Treatment)"

tab high_carbon
display as text "  [INFO] High-carbon obs: " _continue
count if high_carbon == 1

* Note: financial firms (SIC 60-69) already dropped in Master_Analysis_v2.do
* Utilities (SIC 49) kept as treatment since SEC guidance targets them directly

gen byte post_2010 = (fyear >= 2010)
label var post_2010 "Post SEC 2010 Guidance"

* --- 1.2 Main DID Regression ---
display as text "  Running SEC 2010 DID regressions..."
eststo clear

* (1) Full sample, DA (Modified Jones)
capture noisily reghdfe ko_da_sic c.high_carbon#c.post_2010 $ctrl_core, ///
    absorb(gvkey fyear) cluster(gvkey)
if !_rc {
    eststo sec_da
    estadd local fe_firm "Yes"
    estadd local fe_year "Yes"
}

* (2) DA+ (income-increasing only)
capture noisily reghdfe ko_da_sic_plus c.high_carbon#c.post_2010 $ctrl_core, ///
    absorb(gvkey fyear) cluster(gvkey)
if !_rc {
    eststo sec_dap
    estadd local fe_firm "Yes"
    estadd local fe_year "Yes"
}

* (3) Heese DA
capture noisily reghdfe dss_da_heese c.high_carbon#c.post_2010 $ctrl_core, ///
    absorb(gvkey fyear) cluster(gvkey)
if !_rc {
    eststo sec_hda
    estadd local fe_firm "Yes"
    estadd local fe_year "Yes"
}

* (4) REM (Heese composite)
capture noisily reghdfe rem_heese c.high_carbon#c.post_2010 $ctrl_core, ///
    absorb(gvkey fyear) cluster(gvkey)
if !_rc {
    eststo sec_rem
    estadd local fe_firm "Yes"
    estadd local fe_year "Yes"
}

capture noisily esttab sec_da sec_dap sec_hda sec_rem ///
    using "$OUTPUT\Strategy1_SEC2010_DID.rtf", ///
    replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    label compress nogaps ///
    mtitles("DA(MJ)" "DA+" "DA(Heese)" "REM(Heese)") ///
    scalars("fe_firm Firm FE" "fe_year Year FE" "N Observations" "r2_a Adj. R-sq") ///
    title("Strategy 1: SEC 2010 Climate Disclosure DID") ///
    addnotes("Treatment: High-carbon industries (SIC 10-14, 26, 28, 29, 32, 33, 49)." ///
             "Post: fiscal years >= 2010." ///
             "Firm and Year FE absorbed; high_carbon and post_2010 main effects subsumed." ///
             "Robust SE clustered at firm level.")

* --- 1.3 Event Study (Dynamic DID) ---
display as text "  Running SEC 2010 Event Study..."

* Restrict sample to 2005-2015 for clean event window
preserve
keep if inrange(fyear, 2005, 2015)

* Event time relative to 2010
gen event_time = fyear - 2010

* Generate event-time indicators (base = -1)
forvalues t = -5/5 {
    if `t' == -1 continue
    local tlab = cond(`t' < 0, "m" + string(abs(`t')), "p" + string(`t'))
    gen byte et_`tlab' = (event_time == `t') * high_carbon
}

eststo clear
capture noisily reghdfe ko_da_sic et_m5 et_m4 et_m3 et_m2 ///
    et_p0 et_p1 et_p2 et_p3 et_p4 et_p5 $ctrl_core, ///
    absorb(gvkey fyear) cluster(gvkey)
if !_rc {
    eststo sec_es
    estadd local fe_firm "Yes"
    estadd local fe_year "Yes"
}

capture noisily esttab sec_es ///
    using "$OUTPUT\Strategy1_SEC2010_EventStudy.rtf", ///
    replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    label compress nogaps ///
    mtitles("DA (Event Study)") ///
    scalars("fe_firm Firm FE" "fe_year Year FE" "N Observations" "r2_a Adj. R-sq") ///
    title("Strategy 1: SEC 2010 Event Study (Pre-Trend Check)") ///
    addnotes("Omitted category: t = -1 (2009)." ///
             "Coefficients: interaction of High-Carbon x Event-Time dummies.")

restore

display as text ">>> Strategy 1 Completed."


/* ====================================================================
   STRATEGY 2: MSCI 2012 ESG COVERAGE EXPANSION DID
   ====================================================================
   MSCI coverage jumped from 2,093 (2011) to 9,329 (2012) firms.
   Treatment = firms first rated in 2012; Control = already rated.
   ==================================================================== */
display as text _newline ">>> STRATEGY 2: MSCI 2012 Coverage Expansion DID"

use "$PROJ_DATA\final_analysis_v2.dta", clear

* --- 2.1 Merge MSCI Ratings and Identify First-Rated Year ---
preserve
use "$RAW_DATA\ESG\msci_ratings_clean.dta", clear
gen cusip_8 = substr(issuer_cusip, 1, 8) if strlen(issuer_cusip) >= 8
keep if cusip_8 != ""

* Keep one obs per cusip_8-year (take latest rating if duplicates)
duplicates drop cusip_8 year, force

* Identify first rated year for each firm
bys cusip_8 (year): gen first_rated_year = year[1]

keep cusip_8 year first_rated_year iva_company_rating industry_adjusted_score
rename year fyear
tempfile msci_rated
save `msci_rated'
restore

merge 1:1 cusip_8 fyear using `msci_rated', keep(1 3) nogen

* --- 2.2 Propagate first_rated_year to ALL firm-years ---
* After merge, first_rated_year only has values for matched (MSCI) obs.
* Propagate to all observations of the same firm so pre-treatment years
* of treated firms are correctly identified as treated.
bys cusip_8: egen _fr_yr = min(first_rated_year)
drop first_rated_year
rename _fr_yr first_rated_year

* --- 2.3 Construct Treatment/Control ---
gen byte newly_rated_2012 = (first_rated_year == 2012) if !missing(first_rated_year)
gen byte already_rated     = (first_rated_year < 2012)  if !missing(first_rated_year)
gen byte post_2012 = (fyear >= 2012)
gen byte msci_sample = (!missing(first_rated_year))
label var newly_rated_2012 "Newly Rated in 2012 (Treatment)"
label var already_rated "Already Rated Pre-2012 (Control)"

display as text "  [INFO] MSCI 2012 Expansion sample:"
tab newly_rated_2012 if msci_sample == 1
tab first_rated_year if msci_sample == 1

* --- 2.4 Main DID ---
* Treatment = firms first rated in 2012; Control = never-rated firms.
* Using full Compustat panel ensures pre-treatment DA data for treated firms.
display as text "  Running MSCI 2012 DID regressions..."

gen byte treat_2012 = (first_rated_year == 2012) if !missing(first_rated_year)
replace treat_2012 = 0 if missing(first_rated_year)
gen byte post_treat_2012 = (fyear >= 2012) * treat_2012
label var treat_2012 "Firm First Rated by MSCI in 2012"
label var post_treat_2012 "Treated x Post (MSCI 2012 Expansion)"

preserve
keep if inrange(fyear, 2009, 2016)
keep if treat_2012 == 1 | missing(first_rated_year)

eststo clear

capture noisily reghdfe ko_da_sic post_treat_2012 $ctrl_core, ///
    absorb(gvkey fyear) cluster(gvkey)
if !_rc {
    eststo msci12_da
    estadd local fe_firm "Yes"
    estadd local fe_year "Yes"
    estadd local sample "Treated + Never-rated"
}

capture noisily reghdfe ko_da_sic_plus post_treat_2012 $ctrl_core, ///
    absorb(gvkey fyear) cluster(gvkey)
if !_rc {
    eststo msci12_dap
    estadd local fe_firm "Yes"
    estadd local fe_year "Yes"
    estadd local sample "Treated + Never-rated"
}

capture noisily reghdfe rem_heese post_treat_2012 $ctrl_core, ///
    absorb(gvkey fyear) cluster(gvkey)
if !_rc {
    eststo msci12_rem
    estadd local fe_firm "Yes"
    estadd local fe_year "Yes"
    estadd local sample "Treated + Never-rated"
}

capture noisily esttab msci12_da msci12_dap msci12_rem ///
    using "$OUTPUT\Strategy2_MSCI2012_DID.rtf", ///
    replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    label compress nogaps ///
    mtitles("DA(MJ)" "DA+" "REM(Heese)") ///
    scalars("fe_firm Firm FE" "fe_year Year FE" "sample Sample" ///
            "N Observations" "r2_a Adj. R-sq") ///
    title("Strategy 2: MSCI 2012 Coverage Expansion DID") ///
    addnotes("Treatment: Firms first receiving MSCI ESG rating in 2012." ///
             "Control: Firms never rated by MSCI." ///
             "post_treat_2012 = Treated x Post(2012+): DID estimator." ///
             "Firm and Year FE absorbed (treat_2012 main effect subsumed)." ///
             "Sample restricted to 2009-2016." ///
             "Robust SE clustered at firm level.")

* --- 2.4 Event Study around 2012 ---
display as text "  Running MSCI 2012 Event Study..."
gen event_time_12 = fyear - 2012

forvalues t = -3/4 {
    if `t' == -1 continue
    local tlab = cond(`t' < 0, "m" + string(abs(`t')), "p" + string(`t'))
    gen byte et12_`tlab' = (event_time_12 == `t') * treat_2012
}

eststo clear
capture noisily reghdfe ko_da_sic et12_m3 et12_m2 ///
    et12_p0 et12_p1 et12_p2 et12_p3 et12_p4 $ctrl_core, ///
    absorb(gvkey fyear) cluster(gvkey)
if !_rc {
    eststo msci12_es
    estadd local fe_firm "Yes"
    estadd local fe_year "Yes"
}

capture noisily esttab msci12_es ///
    using "$OUTPUT\Strategy2_MSCI2012_EventStudy.rtf", ///
    replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    label compress nogaps ///
    mtitles("DA (Event Study)") ///
    scalars("fe_firm Firm FE" "fe_year Year FE" "N Observations" "r2_a Adj. R-sq") ///
    title("Strategy 2: MSCI 2012 Expansion Event Study") ///
    addnotes("Omitted: t = -1 (2011). Window: 2009-2016." ///
             "Coefficients: Treat2012 x EventTime dummies.")

* --- 2.5 Entropy Balance for MSCI 2012 ---
display as text "  Running Entropy Balance for MSCI 2012..."

capture drop _webal
capture ebalance treat_2012 size mb2 lev roa, targets(1)

capture {
    eststo clear
    reghdfe ko_da_sic post_treat_2012 $ctrl_core [iweight=_webal], ///
        absorb(gvkey fyear) cluster(gvkey)
    eststo msci12_eb
    estadd local fe_firm "Yes"
    estadd local fe_year "Yes"
    estadd local matching "EBM"

    esttab msci12_eb using "$OUTPUT\Strategy2_MSCI2012_EBM.rtf", ///
        replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
        label compress nogaps ///
        mtitles("DA(MJ) + EBM") ///
        scalars("fe_firm Firm FE" "fe_year Year FE" "matching Matching" ///
                "N Observations" "r2_a Adj. R-sq") ///
        title("Strategy 2: MSCI 2012 DID with Entropy Balance") ///
        addnotes("Entropy balance on Size, MB, Leverage, ROA.")
}

restore
display as text ">>> Strategy 2 Completed."


/* ====================================================================
   STRATEGY 3: MSCI ESG RATING UPGRADE STACKED DID
   ====================================================================
   Treatment = year of MSCI rating upgrade; Control = stable-rated.
   Stacked DID: cohort-specific sub-experiments per upgrade year.
   ==================================================================== */
display as text _newline ">>> STRATEGY 3: MSCI Upgrade Stacked DID"

use "$PROJ_DATA\final_analysis_v2.dta", clear

* --- 3.1 Merge MSCI Rating Changes ---
preserve
use "$RAW_DATA\ESG\msci_ratings_clean.dta", clear
gen cusip_8 = substr(issuer_cusip, 1, 8) if strlen(issuer_cusip) >= 8
keep if cusip_8 != ""

* Encode ratings numerically
gen rating_num = .
replace rating_num = 1 if iva_company_rating == "CCC"
replace rating_num = 2 if iva_company_rating == "B"
replace rating_num = 3 if iva_company_rating == "BB"
replace rating_num = 4 if iva_company_rating == "BBB"
replace rating_num = 5 if iva_company_rating == "A"
replace rating_num = 6 if iva_company_rating == "AA"
replace rating_num = 7 if iva_company_rating == "AAA"

gen prev_rating_num = .
replace prev_rating_num = 1 if iva_previous_rating == "CCC"
replace prev_rating_num = 2 if iva_previous_rating == "B"
replace prev_rating_num = 3 if iva_previous_rating == "BB"
replace prev_rating_num = 4 if iva_previous_rating == "BBB"
replace prev_rating_num = 5 if iva_previous_rating == "A"
replace prev_rating_num = 6 if iva_previous_rating == "AA"
replace prev_rating_num = 7 if iva_previous_rating == "AAA"

gen byte upgrade = (rating_num > prev_rating_num) if !missing(rating_num) & !missing(prev_rating_num)

* Deduplicate: keep one obs per firm-year
duplicates drop cusip_8 year, force

keep cusip_8 year rating_num prev_rating_num upgrade iva_company_rating
rename year fyear

tempfile msci_changes
save `msci_changes'
restore

merge 1:1 cusip_8 fyear using `msci_changes', keep(1 3) nogen

* --- 3.2 Build Stacked Sub-Experiments ---
* For each cohort year c (2016-2022), create [-3, +3] sub-experiment
* Treatment: firms upgrading in year c
* Control: firms with stable rating throughout [c-3, c+3]

display as text "  Building stacked sub-experiments..."

* First: identify first upgrade year per firm
bys gvkey (fyear): gen _first_upgrade_yr = fyear if upgrade == 1
bys gvkey: egen first_upgrade_year = min(_first_upgrade_yr)
drop _first_upgrade_yr

tempfile stacked_data
local first_cohort = 1

forvalues c = 2016/2022 {
    preserve

    * Treatment: firms upgrading in year c
    gen byte treat_c = (first_upgrade_year == `c')

    * Control: firms that NEVER upgrade in [c-3, c+3] window
    * Must have rating_num in all years of window (active in MSCI)
    gen byte _in_window = inrange(fyear, `c' - 3, `c' + 3)

    bys gvkey: egen _any_upgrade_window = max(upgrade * _in_window)
    bys gvkey: egen _has_rating_window = total(!missing(rating_num) * _in_window)

    gen byte control_c = (_any_upgrade_window == 0 & _has_rating_window >= 4) ///
                         if !missing(rating_num)

    * Keep only treatment and control firms within the window
    keep if (treat_c == 1 | control_c == 1) & _in_window == 1

    gen cohort = `c'
    gen event_time_s = fyear - `c'
    gen byte treated = treat_c
    gen byte post_s = (fyear >= `c')

    keep gvkey fyear cohort event_time_s treated post_s ///
         ko_da_sic ko_da_sic_plus dss_da_heese dss_da_heese_plus rem_heese ///
         $ctrl_core

    quietly count
    if r(N) > 0 {
        if `first_cohort' == 1 {
            save `stacked_data', replace
            local first_cohort = 0
        }
        else {
            append using `stacked_data'
            save `stacked_data', replace
        }
    }

    restore
}

* --- 3.3 Estimate Stacked DID ---
display as text "  Estimating Stacked DID..."

use `stacked_data', clear

* Create cohort-firm and cohort-year identifiers for FE
egen firm_cohort = group(gvkey cohort)
egen year_cohort = group(fyear cohort)

eststo clear

* (1) Static DID
capture noisily reghdfe ko_da_sic c.treated#c.post_s $ctrl_core, ///
    absorb(firm_cohort year_cohort) cluster(gvkey)
if !_rc {
    eststo stack_da
    estadd local fe_firm_cohort "Yes"
    estadd local fe_year_cohort "Yes"
}

capture noisily reghdfe ko_da_sic_plus c.treated#c.post_s $ctrl_core, ///
    absorb(firm_cohort year_cohort) cluster(gvkey)
if !_rc {
    eststo stack_dap
    estadd local fe_firm_cohort "Yes"
    estadd local fe_year_cohort "Yes"
}

capture noisily reghdfe rem_heese c.treated#c.post_s $ctrl_core, ///
    absorb(firm_cohort year_cohort) cluster(gvkey)
if !_rc {
    eststo stack_rem
    estadd local fe_firm_cohort "Yes"
    estadd local fe_year_cohort "Yes"
}

* (2) Dynamic Event Study
forvalues t = -3/3 {
    if `t' == -1 continue
    local tlab = cond(`t' < 0, "m" + string(abs(`t')), "p" + string(`t'))
    gen byte es_`tlab' = (event_time_s == `t') * treated
}

capture noisily reghdfe ko_da_sic es_m3 es_m2 es_p0 es_p1 es_p2 es_p3 $ctrl_core, ///
    absorb(firm_cohort year_cohort) cluster(gvkey)
if !_rc {
    eststo stack_es
    estadd local fe_firm_cohort "Yes"
    estadd local fe_year_cohort "Yes"
}

capture noisily esttab stack_da stack_dap stack_rem ///
    using "$OUTPUT\Strategy3_StackedDID.rtf", ///
    replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    label compress nogaps ///
    mtitles("DA(MJ)" "DA+" "REM(Heese)") ///
    scalars("fe_firm_cohort Firm*Cohort FE" "fe_year_cohort Year*Cohort FE" ///
            "N Observations" "r2_a Adj. R-sq") ///
    title("Strategy 3: MSCI Upgrade Stacked DID") ///
    addnotes("Treatment: MSCI ESG rating upgrade (first upgrade year)." ///
             "Control: Firms with stable rating throughout cohort window." ///
             "Stacked DID with cohort-specific firm and year FE." ///
             "Cohort years: 2016-2022. Window: [-3, +3]." ///
             "Robust SE clustered at firm level.")

capture noisily esttab stack_es ///
    using "$OUTPUT\Strategy3_StackedDID_EventStudy.rtf", ///
    replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    label compress nogaps ///
    mtitles("DA (Event Study)") ///
    scalars("fe_firm_cohort Firm*Cohort FE" "fe_year_cohort Year*Cohort FE" ///
            "N Observations" "r2_a Adj. R-sq") ///
    title("Strategy 3: MSCI Upgrade Stacked DID - Event Study") ///
    addnotes("Omitted: t = -1. Coefficients: Treated x EventTime.")

display as text ">>> Strategy 3 Completed."


/* ====================================================================
   STRATEGY 4: MSCI INDUSTRY-ADJUSTED SCORE THRESHOLD RDD
   ====================================================================
   Running variable: industry_adjusted_score (0-10)
   Cutoff: rating boundaries (e.g., BBB->A threshold)
   ==================================================================== */
display as text _newline ">>> STRATEGY 4: MSCI Threshold RDD"

use "$PROJ_DATA\final_analysis_v2.dta", clear

* --- 4.1 Merge MSCI Scores and Ratings ---
preserve
use "$RAW_DATA\ESG\msci_ratings_clean.dta", clear
gen cusip_8 = substr(issuer_cusip, 1, 8) if strlen(issuer_cusip) >= 8
keep if cusip_8 != ""
duplicates drop cusip_8 year, force

gen rating_num = .
replace rating_num = 1 if iva_company_rating == "CCC"
replace rating_num = 2 if iva_company_rating == "B"
replace rating_num = 3 if iva_company_rating == "BB"
replace rating_num = 4 if iva_company_rating == "BBB"
replace rating_num = 5 if iva_company_rating == "A"
replace rating_num = 6 if iva_company_rating == "AA"
replace rating_num = 7 if iva_company_rating == "AAA"

keep cusip_8 year rating_num industry_adjusted_score iva_company_rating
rename year fyear
tempfile msci_scores
save `msci_scores'
restore

merge 1:1 cusip_8 fyear using `msci_scores', keep(1 3) nogen

* --- 4.2 Identify Thresholds ---
* Empirical approach: for each rating boundary, find the midpoint between
* the max score of the lower rating and the min score of the upper rating

display as text "  Identifying rating thresholds empirically..."

* Pool across all years and compute boundary statistics
preserve
keep if !missing(rating_num) & !missing(industry_adjusted_score)

* For each adjacent pair, compute the boundary region
forvalues r = 1/6 {
    local r1 = `r' + 1
    quietly summarize industry_adjusted_score if rating_num == `r', detail
    local max_lower = r(max)
    local p90_lower = r(p90)
    quietly summarize industry_adjusted_score if rating_num == `r1', detail
    local min_upper = r(min)
    local p10_upper = r(p10)
    local midpoint = (`p90_lower' + `p10_upper') / 2
    display as text "  Threshold `r'->`r1': lower p90 = `p90_lower', upper p10 = `p10_upper', midpoint = `midpoint'"
}
restore

* --- 4.3 RDD at BBB->A Threshold (Rating 4->5) ---
* This is the most policy-relevant boundary ("investment grade" ESG)
display as text "  Running RDD at BBB->A boundary..."

preserve
keep if !missing(industry_adjusted_score) & !missing(ko_da_sic)
keep if inlist(rating_num, 4, 5)

* Center running variable at estimated threshold
* Use empirical approach: midpoint of overlap zone
quietly summarize industry_adjusted_score if rating_num == 4, detail
local max_bbb = r(p90)
quietly summarize industry_adjusted_score if rating_num == 5, detail
local min_a = r(p10)
local cutoff_bbb_a = (`max_bbb' + `min_a') / 2
display as text "  BBB->A cutoff estimated at: `cutoff_bbb_a'"

gen ias_centered = industry_adjusted_score - `cutoff_bbb_a'
gen byte above_cutoff = (industry_adjusted_score >= `cutoff_bbb_a')
label var above_cutoff "Above BBB->A Threshold"

* RDD: local polynomial
capture noisily rdrobust ko_da_sic industry_adjusted_score, c(`cutoff_bbb_a') ///
    covs($ctrl_core) kernel(triangular) bwselect(mserd)
if !_rc {
    local rdd_coef = e(tau_cl)
    local rdd_se   = e(se_tau_cl)
    local rdd_pval = e(pv_cl)
    local rdd_bw   = e(h_l)
    local rdd_N    = e(N_h_l) + e(N_h_r)
    display as text "  RDD estimate: coef = `rdd_coef', se = `rdd_se', p = `rdd_pval'"
    display as text "  Bandwidth: `rdd_bw', Effective N: `rdd_N'"
}

* McCrary density test
display as text "  Running McCrary density test..."
capture noisily rddensity industry_adjusted_score, c(`cutoff_bbb_a')
if !_rc {
    display as text "  McCrary test p-value: " e(pv_q)
}

* Bandwidth sensitivity: try multiple bandwidths
eststo clear
foreach bw in 0.5 1.0 1.5 2.0 {
    capture noisily rdrobust ko_da_sic industry_adjusted_score, c(`cutoff_bbb_a') ///
        covs($ctrl_core) h(`bw') kernel(triangular)
    if !_rc {
        local bw_label = subinstr("`bw'", ".", "_", .)
        matrix b_`bw_label' = e(tau_cl)
        matrix se_`bw_label' = e(se_tau_cl)
        display as text "  BW=`bw': coef = " e(tau_cl) ", se = " e(se_tau_cl)
    }
}

* Also try RDD for DA+ and REM
capture noisily rdrobust ko_da_sic_plus industry_adjusted_score, c(`cutoff_bbb_a') ///
    covs($ctrl_core) kernel(triangular) bwselect(mserd)
if !_rc {
    display as text "  RDD (DA+): coef = " e(tau_cl) ", p = " e(pv_cl)
}

capture noisily rdrobust rem_heese industry_adjusted_score, c(`cutoff_bbb_a') ///
    covs($ctrl_core) kernel(triangular) bwselect(mserd)
if !_rc {
    display as text "  RDD (REM): coef = " e(tau_cl) ", p = " e(pv_cl)
}

restore

* --- 4.4 RDD at BB->BBB Threshold (Rating 3->4) ---
display as text "  Running RDD at BB->BBB boundary..."

preserve
keep if !missing(industry_adjusted_score) & !missing(ko_da_sic)
keep if inlist(rating_num, 3, 4)

quietly summarize industry_adjusted_score if rating_num == 3, detail
local max_bb = r(p90)
quietly summarize industry_adjusted_score if rating_num == 4, detail
local min_bbb = r(p10)
local cutoff_bb_bbb = (`max_bb' + `min_bbb') / 2
display as text "  BB->BBB cutoff estimated at: `cutoff_bb_bbb'"

capture noisily rdrobust ko_da_sic industry_adjusted_score, c(`cutoff_bb_bbb') ///
    covs($ctrl_core) kernel(triangular) bwselect(mserd)
if !_rc {
    display as text "  RDD (BB->BBB): coef = " e(tau_cl) ", p = " e(pv_cl)
}

capture noisily rddensity industry_adjusted_score, c(`cutoff_bb_bbb')
if !_rc {
    display as text "  McCrary test (BB->BBB) p-value: " e(pv_q)
}

restore

display as text ">>> Strategy 4 Completed."


/* ====================================================================
   STRATEGY 5: BARTIK / SHIFT-SHARE IV
   ====================================================================
   Instrument: Leave-one-out industry-average ESG score.
   Industry-level ESG variation is plausibly exogenous to individual
   firm EM decisions.
   ==================================================================== */
display as text _newline ">>> STRATEGY 5: Bartik IV"

use "$PROJ_DATA\final_analysis_v2.dta", clear

* --- 5.1 Construct Leave-One-Out Industry-Year ESG Mean ---
* For each firm i in industry j, year t:
*   IV = (sum of vs_4 in j,t excluding firm i) / (N_jt - 1)

foreach esvar in vs_4 vs_6 {
    bysort sic_2 fyear: egen _sum_`esvar' = total(`esvar')
    bysort sic_2 fyear: egen _n_`esvar'   = count(`esvar')
    gen iv_bartik_`esvar' = (_sum_`esvar' - `esvar') / (_n_`esvar' - 1) ///
        if _n_`esvar' > 1 & !missing(`esvar')
    drop _sum_`esvar' _n_`esvar'
    label var iv_bartik_`esvar' "Bartik IV: Leave-Out Industry Avg `esvar'"
}

* --- 5.2 First Stage and 2SLS ---
display as text "  Running 2SLS with Bartik IV..."
eststo clear

* First stage diagnostic
capture noisily reghdfe vs_4 iv_bartik_vs_4 $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
if !_rc {
    eststo iv_1st
    estadd local fe_firm "Yes"
    estadd local fe_year "Yes"
    test iv_bartik_vs_4
    estadd scalar F_first = r(F)
    display as text "  First-stage F-stat: " r(F)
}

* 2SLS: DA
capture noisily ivreghdfe ko_da_sic (vs_4 = iv_bartik_vs_4) $ctrl_core, ///
    absorb(gvkey fyear) cluster(gvkey)
if !_rc {
    eststo iv_da
    estadd local fe_firm "Yes"
    estadd local fe_year "Yes"
}
else {
    * Fallback: manual 2SLS via reghdfe if ivreghdfe not installed
    display as text "  ivreghdfe not available, using manual 2SLS..."
    capture noisily reghdfe vs_4 iv_bartik_vs_4 $ctrl_core, absorb(gvkey fyear) cluster(gvkey) resid
    if !_rc {
        predict vs_4_hat, xb
        capture noisily reghdfe ko_da_sic vs_4_hat $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
        if !_rc {
            eststo iv_da
            estadd local fe_firm "Yes"
            estadd local fe_year "Yes"
            estadd local method "Manual 2SLS"
        }
        drop vs_4_hat
    }
}

* 2SLS: DA+
capture noisily ivreghdfe ko_da_sic_plus (vs_4 = iv_bartik_vs_4) $ctrl_core, ///
    absorb(gvkey fyear) cluster(gvkey)
if !_rc {
    eststo iv_dap
    estadd local fe_firm "Yes"
    estadd local fe_year "Yes"
}
else {
    capture noisily reghdfe vs_4 iv_bartik_vs_4 $ctrl_core, absorb(gvkey fyear) cluster(gvkey) resid
    if !_rc {
        predict vs_4_hat, xb
        capture noisily reghdfe ko_da_sic_plus vs_4_hat $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
        if !_rc {
            eststo iv_dap
            estadd local fe_firm "Yes"
            estadd local fe_year "Yes"
            estadd local method "Manual 2SLS"
        }
        drop vs_4_hat
    }
}

* 2SLS: REM
capture noisily ivreghdfe rem_heese (vs_4 = iv_bartik_vs_4) $ctrl_core, ///
    absorb(gvkey fyear) cluster(gvkey)
if !_rc {
    eststo iv_rem
    estadd local fe_firm "Yes"
    estadd local fe_year "Yes"
}
else {
    capture noisily reghdfe vs_4 iv_bartik_vs_4 $ctrl_core, absorb(gvkey fyear) cluster(gvkey) resid
    if !_rc {
        predict vs_4_hat, xb
        capture noisily reghdfe rem_heese vs_4_hat $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
        if !_rc {
            eststo iv_rem
            estadd local fe_firm "Yes"
            estadd local fe_year "Yes"
            estadd local method "Manual 2SLS"
        }
        drop vs_4_hat
    }
}

capture noisily esttab iv_1st iv_da iv_dap iv_rem ///
    using "$OUTPUT\Strategy5_BartikIV.rtf", ///
    replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    label compress nogaps ///
    mtitles("1st Stage" "DA(MJ)" "DA+" "REM(Heese)") ///
    scalars("fe_firm Firm FE" "fe_year Year FE" "F_first First-Stage F" ///
            "N Observations" "r2_a Adj. R-sq") ///
    title("Strategy 5: Bartik IV (Leave-One-Out Industry ESG)") ///
    addnotes("IV: Leave-one-out industry-year average Environmental Score." ///
             "Robust SE clustered at firm level.")

display as text ">>> Strategy 5 Completed."


/* ====================================================================
   STRATEGY 6: PLACEBO TEST + MECHANISM TESTS
   ====================================================================
   6A: Placebo — Governance dimension should NOT trigger moral licensing
   6B: Mechanism — DA+ vs DA-: licensing predicts only DA+
   ==================================================================== */
display as text _newline ">>> STRATEGY 6: Placebo & Mechanism Tests"

use "$PROJ_DATA\final_analysis_v2.dta", clear

capture drop vs_11
gen vs_11 = vs_4 + vs_6 if !missing(vs_4) & !missing(vs_6)
label var vs_11 "ES Composite Score"

* --- 6A. Placebo: Governance vs Environmental/Social ---
display as text "  Running Placebo tests (Governance vs E/S)..."
eststo clear

* Environmental -> DA (expected: significant)
capture noisily reghdfe ko_da_sic vs_4 $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
if !_rc {
    eststo plac_env
    estadd local fe_firm "Yes"
    estadd local fe_year "Yes"
    estadd local dimension "Environmental"
}

* Social -> DA (expected: significant)
capture noisily reghdfe ko_da_sic vs_6 $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
if !_rc {
    eststo plac_soc
    estadd local fe_firm "Yes"
    estadd local fe_year "Yes"
    estadd local dimension "Social"
}

* Governance -> DA (expected: INSIGNIFICANT = placebo confirmed)
capture noisily reghdfe ko_da_sic vs_gov $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
if !_rc {
    eststo plac_gov
    estadd local fe_firm "Yes"
    estadd local fe_year "Yes"
    estadd local dimension "Governance"
}

* Repeat for DA+
capture noisily reghdfe ko_da_sic_plus vs_4 $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
if !_rc {
    eststo plac_env_p
    estadd local fe_firm "Yes"
    estadd local fe_year "Yes"
    estadd local dimension "Environmental"
}

capture noisily reghdfe ko_da_sic_plus vs_6 $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
if !_rc {
    eststo plac_soc_p
    estadd local fe_firm "Yes"
    estadd local fe_year "Yes"
    estadd local dimension "Social"
}

capture noisily reghdfe ko_da_sic_plus vs_gov $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
if !_rc {
    eststo plac_gov_p
    estadd local fe_firm "Yes"
    estadd local fe_year "Yes"
    estadd local dimension "Governance"
}

capture noisily esttab plac_env plac_soc plac_gov plac_env_p plac_soc_p plac_gov_p ///
    using "$OUTPUT\Strategy6A_Placebo_Governance.rtf", ///
    replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    label compress nogaps ///
    mtitles("DA:Env" "DA:Soc" "DA:Gov" "DA+:Env" "DA+:Soc" "DA+:Gov") ///
    scalars("fe_firm Firm FE" "fe_year Year FE" "dimension ESG Dimension" ///
            "N Observations" "r2_a Adj. R-sq") ///
    title("Strategy 6A: Placebo Test (Governance vs Environmental/Social)") ///
    addnotes("Moral licensing theory predicts E and S dimensions trigger licensing," ///
             "while Governance improvements should NOT." ///
             "Governance insignificance = placebo confirmed.")

* --- 6B. Mechanism: DA+ vs DA- Decomposition ---
display as text "  Running Mechanism tests (DA+ vs DA-)..."

* Generate DA- = min(DA, 0) as income-decreasing accruals
gen ko_da_sic_minus = min(ko_da_sic, 0)
label var ko_da_sic_minus "DA- (Income-Decreasing)"
gen dss_da_heese_minus = min(dss_da_heese, 0) if !missing(dss_da_heese)
label var dss_da_heese_minus "DA- (Heese, Income-Decreasing)"

eststo clear

* ES Composite -> DA+
capture noisily reghdfe ko_da_sic_plus vs_11 $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
if !_rc {
    eststo mech_da_plus
    estadd local fe_firm "Yes"
    estadd local fe_year "Yes"
    estadd local dv "DA+"
}

* ES Composite -> DA-
capture noisily reghdfe ko_da_sic_minus vs_11 $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
if !_rc {
    eststo mech_da_minus
    estadd local fe_firm "Yes"
    estadd local fe_year "Yes"
    estadd local dv "DA-"
}

* Environmental -> DA+
capture noisily reghdfe ko_da_sic_plus vs_4 $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
if !_rc {
    eststo mech_env_plus
    estadd local fe_firm "Yes"
    estadd local fe_year "Yes"
    estadd local dv "DA+"
}

* Environmental -> DA-
capture noisily reghdfe ko_da_sic_minus vs_4 $ctrl_core, absorb(gvkey fyear) cluster(gvkey)
if !_rc {
    eststo mech_env_minus
    estadd local fe_firm "Yes"
    estadd local fe_year "Yes"
    estadd local dv "DA-"
}

* Environmental -> DA+ with interaction
capture noisily reghdfe ko_da_sic_plus c.vs_4##i.industry_type $ctrl_core, ///
    absorb(gvkey fyear) cluster(gvkey)
if !_rc {
    eststo mech_env_plus_int
    estadd local fe_firm "Yes"
    estadd local fe_year "Yes"
    estadd local dv "DA+ (Int)"
}

* Environmental -> DA- with interaction
capture noisily reghdfe ko_da_sic_minus c.vs_4##i.industry_type $ctrl_core, ///
    absorb(gvkey fyear) cluster(gvkey)
if !_rc {
    eststo mech_env_minus_int
    estadd local fe_firm "Yes"
    estadd local fe_year "Yes"
    estadd local dv "DA- (Int)"
}

capture noisily esttab mech_da_plus mech_da_minus mech_env_plus mech_env_minus ///
    mech_env_plus_int mech_env_minus_int ///
    using "$OUTPUT\Strategy6B_Mechanism_DA_Decomposition.rtf", ///
    replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    label compress nogaps ///
    mtitles("DA+:ES" "DA-:ES" "DA+:Env" "DA-:Env" "DA+:Int" "DA-:Int") ///
    scalars("fe_firm Firm FE" "fe_year Year FE" "dv DV Type" ///
            "N Observations" "r2_a Adj. R-sq") ///
    title("Strategy 6B: Mechanism Test (DA+ vs DA- Decomposition)") ///
    addnotes("Moral licensing predicts ESG -> DA+ (income-increasing) only." ///
             "DA- (income-decreasing) should be unaffected." ///
             "Asymmetric effect supports the licensing mechanism.")

display as text ">>> Strategy 6 Completed."


/* ====================================================================
   WRAP-UP
   ==================================================================== */
display as text _newline ">>> All Identification Strategies completed: $S_DATE $S_TIME"
display as text ">>> Output files saved to: $OUTPUT"

display as text _newline "  Output summary:"
display as text "    Strategy1_SEC2010_DID.rtf"
display as text "    Strategy1_SEC2010_EventStudy.rtf"
display as text "    Strategy2_MSCI2012_DID.rtf"
display as text "    Strategy2_MSCI2012_EventStudy.rtf"
display as text "    Strategy2_MSCI2012_EBM.rtf"
display as text "    Strategy3_StackedDID.rtf"
display as text "    Strategy3_StackedDID_EventStudy.rtf"
display as text "    Strategy5_BartikIV.rtf"
display as text "    Strategy6A_Placebo_Governance.rtf"
display as text "    Strategy6B_Mechanism_DA_Decomposition.rtf"

log close
