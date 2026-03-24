/* ====================================================================
   MASTER ANALYSIS DO FILE
   Project: Corporate ESG and EM
   Merged from: da_aug.do, merge_aug.do, moderator_sep.do, final_reg.do
   Date: 2026-01-21
   
   Description:
   This Master DO file performs the following steps:
   1. Part 1: Calculates Discretionary Accruals (DA) using the Modified Jones Model, 
      estimated by industry (SIC 2-digit) and year.
   2. Part 2: Merges the DA data with various external datasets (CRSP/Compustat, IO, 
      CEO Compensation, KLD, etc.) to construct the main analysis dataset.
   3. Part 3: Constructs moderator variables (Big N, Firm Age, Growth) and feature 
      engineering for underperformance (Adjusted ROA < 0) and industry culpability.
   4. Part 4: Runs the final regression models to analyze the relationship between 
      ESG/EM and industry types, controlling for firm and CEO characteristics.
   ==================================================================== */

clear all
set more off
capture log close

/* ====================================================================
   0. SETTINGS & PATHS
   ==================================================================== */

* -----------------------------------------------------------------------
* PROJECT PATHS
* ROOT      : 鏈」鐩牴鐩綍锛圡oral Lisensing锛?* RAW_DATA  : D鐩樺叕鍏卞師濮嬫暟鎹洰褰曪紙鍚勯」鐩叡浜級
* PROJ_DATA : 鏈」鐩嫭鏈夋暟鎹紙msci_esg, duality_sup锛?* OUTPUT    : 鍥炲綊缁撴灉杈撳嚭鐩綍
* -----------------------------------------------------------------------
global ROOT      "c:\Users\HuGoL\OneDrive - HKUST (Guangzhou)\PhD\3_Research\Moral Lisensing"
global RAW_DATA  "D:\Research\Data"
global PROJ_DATA "$ROOT\data"
global OUTPUT    "$ROOT\output"

* -----------------------------------------------------------------------
* RAW DATA 鏂囦欢鏄犲皠锛堜粠鏃ц矾寰?E:\empirical_study\data_raw\ 鏇存柊锛?* cmm_raw.dta              鈫?$RAW_DATA\Financials\compustat_80_25.dta
* crsp_merged_final_*.dta  鈫?$RAW_DATA\ESG\kld_zy.dta  锛堥渶鏍稿疄鍙橀噺鍚嶏級
* io.dta                   鈫?$RAW_DATA\Financials\io.dta
* ceo_compensation.dta     鈫?$RAW_DATA\CEO\execucomp_raw.dta 锛堥渶鏍稿疄鍙橀噺鍚嶏級
* firm_age.dta             鈫?$RAW_DATA\firm_age.dta
* -----------------------------------------------------------------------

cd "$ROOT\code"
log using "$ROOT\code\analysis_log.log", replace


/* ====================================================================
   PART 1: DISCRETIONARY ACCRUALS (DA) CALCULATION (from da_aug.do)
   ==================================================================== */
display as text ">>> Starting Part 1: DA Calculation..."

use "$RAW_DATA\Financials\compustat_80_25.dta", clear  // 鍘?cmm_raw.dta

* --- 1.1 Industry Classification (FF48) ---
gen sic_num = sic
gen industry = ""

* (Condensed FF48 Logic)
replace industry = "1 Agric" if inrange(sic_num, 0100, 0199) | inrange(sic_num, 0700, 0799) | inrange(sic_num, 0910, 0919) | sic_num == 2048
replace industry = "2 Food" if inrange(sic_num, 2000, 2099)
replace industry = "3 Soda" if inrange(sic_num, 2064, 2068) | inlist(sic_num, 2086, 2087, 2096, 2097)
replace industry = "4 Beer" if inlist(sic_num, 2080, 2082, 2083, 2084, 2085)
replace industry = "5 Smoke" if inrange(sic_num, 2100, 2199)
replace industry = "6 Toys" if inrange(sic_num, 0920, 0999) | inrange(sic_num, 3650, 3652) | sic_num == 3732 | inrange(sic_num, 3930, 3931) | inrange(sic_num, 3940, 3949)
replace industry = "7 Fun" if inrange(sic_num, 7800, 7841) | inrange(sic_num, 7900, 7999)
replace industry = "8 Books" if inrange(sic_num, 2700, 2799)
replace industry = "9 Hshld" if sic_num == 2047 | inrange(sic_num, 2391, 2392) | inrange(sic_num, 2510, 2519) | inrange(sic_num, 2590, 2599) | inrange(sic_num, 2840, 2844) | inrange(sic_num, 3160, 3269) | inrange(sic_num, 3630, 3639) | inrange(sic_num, 3750, 3751) | inrange(sic_num, 3800, 3995)
replace industry = "10 Clths" if inrange(sic_num, 2300, 2390) | inrange(sic_num, 3020, 3021) | inrange(sic_num, 3100, 3151) | inrange(sic_num, 3963, 3965)
replace industry = "11 Hlth" if inrange(sic_num, 8000, 8099)
replace industry = "12 MedEq" if sic_num == 3693 | inrange(sic_num, 3840, 3851)
replace industry = "13 Drugs" if inrange(sic_num, 2830, 2836)
replace industry = "14 Chems" if inrange(sic_num, 2800, 2899)
replace industry = "15 Rubbr" if inrange(sic_num, 3031, 3099)
replace industry = "16 Txtls" if inrange(sic_num, 2200, 2299)
replace industry = "17 BldMt" if inrange(sic_num, 0800, 0899) | inrange(sic_num, 2400, 2499) | inrange(sic_num, 3420, 3499)
replace industry = "18 Cnstr" if inrange(sic_num, 1500, 1799)
replace industry = "19 Steel" if inrange(sic_num, 3300, 3399)
replace industry = "20 FabPr" if inrange(sic_num, 3400, 3479)
replace industry = "21 Mach" if inrange(sic_num, 3510, 3599)
replace industry = "22 ElcEq" if inrange(sic_num, 3600, 3699)
replace industry = "23 Autos" if inrange(sic_num, 2296, 2396) | inrange(sic_num, 3010, 3799)
replace industry = "24 Aero" if inrange(sic_num, 3720, 3729)
replace industry = "25 Ships" if inrange(sic_num, 3730, 3743)
replace industry = "26 Guns" if inrange(sic_num, 3760, 3769) | sic_num == 3795 | inrange(sic_num, 3480, 3489)
replace industry = "27 Gold" if inrange(sic_num, 1040, 1049)
replace industry = "28 Mines" if inrange(sic_num, 1000, 1499)
replace industry = "29 Coal" if inrange(sic_num, 1200, 1299)
replace industry = "30 Oil" if inrange(sic_num, 1300, 1399) | inrange(sic_num, 2900, 2999)
replace industry = "31 Util" if inrange(sic_num, 4900, 4949)
replace industry = "32 Telcm" if inrange(sic_num, 4800, 4899)
replace industry = "33 PerSv" if inrange(sic_num, 7020, 7699)
replace industry = "34 BusSv" if inrange(sic_num, 2750, 4229)
replace industry = "35 Comps" if inrange(sic_num, 3570, 3695) | sic_num == 7373
replace industry = "36 Chips" if inrange(sic_num, 3622, 3812)
replace industry = "37 LabEq" if inrange(sic_num, 3811, 3839)
replace industry = "38 Paper" if inrange(sic_num, 2520, 3955)
replace industry = "39 Boxes" if inrange(sic_num, 2440, 3412)
replace industry = "40 Trans" if inrange(sic_num, 4000, 4789)
replace industry = "41 Whlsl" if inrange(sic_num, 5000, 5199)
replace industry = "42 Rtail" if inrange(sic_num, 5200, 5999)
replace industry = "43 Meals" if inrange(sic_num, 5800, 7399)
replace industry = "44 Banks" if inrange(sic_num, 6000, 6199)
replace industry = "45 Insur" if inrange(sic_num, 6300, 6411)
replace industry = "46 RlEst" if inrange(sic_num, 6500, 6611)
replace industry = "47 Fin" if inrange(sic_num, 6200, 6799)
replace industry = "48 Other" if inrange(sic_num, 4950, 4991)
replace industry = "48 Other" if industry == ""
rename industry ff48

* --- 1.2 Sample Filtering ---
* Exclude financials (SIC 6000鈥?999)
drop if sic >= 6000 & sic <= 6999
* Note: Utilities (4910-4939) check commented out in original, kept as is.

drop if linkprim == "N" | linkprim == "J"
drop if missing(sale) | missing(at) | missing(oancf) | missing(ni)

gen cusip_8 = substr(cusip, 1, 8)
encode cusip_8, gen(cusip_x)

* --- 1.3 Firm Level Variables ---
gen lev = (dltt + dlc) / at
gen cash_holding = che / at
gen size = ln(at)
gen roa = ni / at
gen mb1 = (prcc_f * csho) / ceq

* Calculate Shareholders Equity (SHE)
gen double she = .
replace she = seq if !missing(seq)
replace she = ceq + pstk if missing(she) & !missing(ceq, pstk)
replace she = at - lt - mib if missing(she) & !missing(at, lt)

* Calculate Preferred Stock (PS)
gen double ps = cond(!missing(pstkrv), pstkrv, ///
                cond(!missing(pstkl), pstkl, ///
                cond(!missing(pstk), pstk, 0)))

* Calculate Book Equity (BE) and Market-to-Book (MB)
gen double be = she - ps
gen mb2 = (prcc_f * csho) / be
gen mv = prcc_f * csho

* Drop small firms (Market Value < $20M)
drop if mv < 20 

* SIC 2-digit code
tostring sic, replace
gen sic_2 = substr(sic, 1, 2)
encode cusip, gen(cusip_n)

* --- 1.4 Modified Jones Model Estimation ---
xtset cusip_n fyear
sort cusip_n fyear

* Calculate accruals
by cusip_n: gen dss_ta = d.act - d.lct - d.che + d.dlc
by cusip_n: gen ko_ta  = d.act - d.lct - d.che + d.dlc - dp
by cusip_n: gen yu_ta  = ni - oancf
by cusip_n: gen ge_ta  = ibc - oancf

* Scaled by lagged assets
by cusip_n: gen dv_ta_dss = dss_ta / l.at
by cusip_n: gen dv_ta_ko  = ko_ta / l.at
by cusip_n: gen dv_ta_yu  = yu_ta / l.at
by cusip_n: gen dv_ta_ge  = ge_ta / l.at

* Regressors
by cusip_n: gen iv_1 = 1 / l.at
by cusip_n: gen iv_2 = d.revt / l.at
by cusip_n: gen iv_22 = (d.revt - d.rect) / l.at
by cusip_n: gen iv_3 = ppegt / l.at

* Keep industries with enough observations
bysort sic_2 fyear: gen count = _N
keep if count >= 15 

* Estimate regressions by SIC-2 and Year
local measures dss ko yu ge
foreach m of local measures {
    bys fyear sic_2: asreg dv_ta_`m' iv_1 iv_2 iv_3
    * Calculate non-discretionary accruals
    gen non_ac = _b_iv_1*iv_1 + _b_iv_2*iv_22 + _b_iv_3*iv_3 + _b_cons
    * Calculate DA (Residuals)
    gen `m'_da_sic = dv_ta_`m' - non_ac
    drop _Nobs _R2 _adjR2 _b_iv_1 _b_iv_2 _b_iv_3 _b_cons non_ac
}

* Estimate regressions by FF48 and Year (Optional, kept from original)
foreach m of local measures {
    bys fyear ff48: asreg dv_ta_`m' iv_1 iv_2 iv_3
    gen non_ac = _b_iv_1*iv_1 + _b_iv_2*iv_22 + _b_iv_3*iv_3 + _b_cons
    gen `m'_da_ff = dv_ta_`m' - non_ac
    drop _Nobs _R2 _adjR2 _b_iv_1 _b_iv_2 _b_iv_3 _b_cons non_ac
}

save "$ROOT\data\dv_em_temp.dta", replace
display as text ">>> Part 1 Completed. Saved dv_em_aug_temp.dta"


/* ====================================================================
   PART 2: MERGING EXTERNAL DATA (from merge_aug.do)
   ==================================================================== */
display as text ">>> Starting Part 2: Merging Datasets..."

use "$ROOT\data\dv_em_temp.dta", clear
gen year = fyear

* --- 2.1 Merging with Raw Datasets ---
* KLD / CRSP Merged锛堝師 crsp_merged_final_zhangyue.dta锛岄渶鏍稿疄鍙橀噺鍚嶄笌 kld_zy.dta 鏄惁涓€鑷达級
merge 1:1 cusip_8 fyear using "$RAW_DATA\ESG\kld_zy.dta", ///
    nogen keep(1 3 4 5) keepusing(state env_* com_* hum_* emp_* div_* pro_* cgov_* alc_* gam_* mil_* nuc_* tob_* kld_* bod_* vs_1-vs_6) update

* IO (Institutional Ownership)
merge 1:1 cusip_8 fyear using "$RAW_DATA\Financials\io.dta", keepus(per_*) keep(1 3) nogen


* Culpability KLD (Constructed from KLD items: Alcohol, Gambling, Military, Nuclear, Tobacco)
* "tobacco鈥? 鈥渇irearms鈥? 鈥渕ilitary鈥? 鈥渁lcohol,鈥?or 鈥済ambling鈥?
* User specified variables: alc_* gam_* mil_* nuc_* tob_* 
gen culpa = 0
foreach v of varlist alc_* gam_* mil_* nuc_* tob_* {
    replace culpa = 1 if `v' == 1
}

* MSCI锛堥」鐩嫭鏈夋暟鎹紝瀛樻斁鍦?data/ 鐩綍锛?capture merge 1:1 cusip_8 year using "$PROJ_DATA\msci_esg.dta", keep(1 3) nogen

* CEO Compensation锛堝師 ceo_compensation.dta锛岄渶鏍稿疄鍙橀噺鍚嶄笌 execucomp_raw.dta 鏄惁涓€鑷达級
merge 1:n cusip_8 year using "$PROJ_DATA\ceo_compensation.dta", nogen keep(1 3)

* --- 2.2 KLD and Variable Construction ---
drop emp
gen emp = emp_str_num1 - emp_con_num1
gen env = env_str_num1 - env_con_num1

gen kld = env_str_num1 - env_con_num1 + com_str_num1 - com_con_num1 + ///
          hum_str_num1 - hum_con_num1 + emp_str_num1 - emp_con_num1 + ///
          div_str_num1 - div_con_num1 + pro_str_num1 - pro_con_num1 + ///
          cgov_str_num1 - cgov_con_num1

gen kldnocg = env_str_num1 - env_con_num1 + com_str_num1 - com_con_num1 + ///
              hum_str_num1 - hum_con_num1 + emp_str_num1 - emp_con_num1 + ///
              div_str_num1 - div_con_num1 + pro_str_num1 - pro_con_num1

gen flammer_str = env_str_num1 + com_str_num1 + emp_str_num1 + pro_str_num1

* Clean CEO Gender
replace ceo_gender = "1" if ceo_gender == "MALE"
replace ceo_gender = "0" if ceo_gender == "FEMALE"
destring ceo_gender, replace

* Adjusted ROA (by sic_2 and year)
sort year sic_2
bys sic_2 year: egen aver_roa = mean(roa)
gen adj_roa = roa - aver_roa

* Handle duplicates
sort cusip_8 year ceo_name 
duplicates drop cusip_8 year, force

xtset cusip_n year
sort cusip_n year

* --- 2.3 Industry Culpability Classification (Sin Industries) ---
gen industry_type = 0
destring sic, replace

* Tobacco
replace industry_type = 1 if inrange(sic, 2100, 2199)
* Guns and Defense
replace industry_type = 1 if inrange(sic, 3760, 3769) | sic == 3795 | inrange(sic, 3480, 3489)
* Natural Resources
replace industry_type = 1 if inrange(sic, 800, 899) | inrange(sic, 1000, 1119) | inrange(sic, 1400, 1499)
* Alcohol
replace industry_type = 1 if sic == 2080 | inrange(sic, 2082, 2085)
* Manual flag from 'culpa' variable
replace industry_type = 1 if culpa == 1

save "$ROOT\data\playboard_temp.dta", replace
display as text ">>> Part 2 Completed. Saved playboard_26_temp.dta"


/* ====================================================================
   PART 3: MODERATOR & FEATURE ENGINEERING (from moderator_sep.do)
   ==================================================================== */
display as text ">>> Starting Part 3: Moderator Construction..."

use "$ROOT\data\playboard_temp.dta", clear
xtset gvkey year // Use consistent ID

* --- 3.1 Big N Auditors & Firm Age ---
* Merge Firm Age
merge 1:1 gvkey year using "$RAW_DATA\firm_age.dta", keep(1 3 4 5) keepusing(age) nogen

* Merge supplementary duality data锛堥」鐩嫭鏈夋暟鎹級
merge 1:1 gvkey year using "$PROJ_DATA\duality_sup.dta", keep(1 3) keepusing(duality) update


gen big_n = au > 0 & au < 9
gen big_4 = au > 3 & au < 9
gen firm_age = age

* --- 3.2 Growth Variables ---
sort gvkey year
bys gvkey: gen l_sale = l.sale
gen growth_sale = (sale - l_sale) / l_sale

bys gvkey: gen l_at = l.at
gen growth_asset = (at - l_at) / l_at

* --- 3.3 Underperformance Variables ---
* [UPDATED] Logic: Underperformance = adj_roa < 0
* This measure identifies firms performing below the industry average (since adj_roa is deviations from industry mean).
xtset gvkey year

* Underperformance Indicator (1 if adj_roa < 0)
gen byte underperform = (adj_roa < 0) if !missing(adj_roa)
label var underperform "1 if Adjusted ROA < 0 (Underperformance)"

* Consecutive Underperformance Duration
* Calculates the number of consecutive years a firm has been underperforming up to the current year.
by gvkey: gen under_duration = underperform if _n == 1 
by gvkey: replace under_duration = ///
    cond(underperform == 1, ///
         cond(_n == 1, 1, cond(underperform[_n-1] == 1, under_duration[_n-1] + 1, 1)), ///
         0) if _n > 1 & !missing(underperform)

label var under_duration "Consecutive years of underperformance"



save "$ROOT\data\final_analysis.dta", replace
display as text ">>> Part 3 Completed. Saved final_26_temp.dta"


/* ====================================================================
   PART 4: REGRESSION ANALYSIS & CONSOLIDATED OUTPUT
   ==================================================================== */
display as text ">>> Starting Part 4: Regression Analysis..."

use "$ROOT\data\final_analysis.dta", clear

* --- 4.1 Variable Preparation & Labeling ---
* Generate composite ESG score before regressions
capture drop vs_11
gen vs_11 = vs_4 + vs_6
label var vs_11 "ES Composite Score"
label var vs_4  "Environmental Score"
label var vs_6  "Social Score"
label var industry_type "Industry Culpability"

* Label Control Variables
label var size "Firm Size"
label var mb2 "Market-to-Book"
label var lev "Debt Ratio"
label var roa "ROA"
label var growth_asset "Asset Growth"
label var cash_holding "Cash Holdings"
label var per_io "Institutional Ownership"
label var big_4 "Big 4 Auditor"
label var firm_age "Firm Age"
label var ceo_age "CEO Age"
label var ceo_gender "CEO Gender"
label var duality "CEO Duality"
label var bod_independence "Board Independence"
label var bod_size "Board Size"

* Define Controls
global ctrl size mb2 lev roa growth_asset cash_holding ///
            per_io big_4 firm_age ceo_age ceo_gender ///
            duality bod_independence bod_size

* Winsorize all key variables (Dependent, Independent, and Controls)
winsor2 ko_da_sic ko_da_ff vs_11 vs_4 vs_6 $ctrl, cuts(0.5 99.5) replace

* --- 4.2 Estimation ---
eststo clear

* Model 1-3: Main Effects
foreach v in vs_11 vs_4 vs_6 {
    quietly reghdfe ko_da_sic `v' 1.industry_type $ctrl, absorb(year gvkey) cluster(gvkey)
    estimates store m_`v'
    quietly eststo m_`v'
    quietly estadd local fe_year "Yes"
    quietly estadd local fe_firm "Yes"
}

* Model 4-6: Interaction Effects
foreach v in vs_11 vs_4 vs_6 {
    quietly reghdfe ko_da_sic c.`v'##i.industry_type $ctrl, absorb(year gvkey) cluster(gvkey)
    estimates store i_`v'
    quietly eststo i_`v'
    quietly estadd local fe_year "Yes"
    quietly estadd local fe_firm "Yes"
}


* --- 4.3 Consolidated Output ---
* Using RTF format for simple and complete output as requested.
* This format is compatible with Microsoft Word and ensures all results are captured.


* --- 4.3 Consolidated Output (Main Table) ---
* Export to RTF (with CEO controls)
esttab m_vs_11 m_vs_4 m_vs_6 i_vs_11 i_vs_4 i_vs_6 using "$OUTPUT\Master_Results.rtf", ///
    replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    label compress nogaps ///
    mtitles("Main" "Main" "Main" "Int" "Int" "Int") ///
    scalars("fe_year Year FE" "fe_firm Firm FE" "N Observations" "r2_a Adj. R-squared") ///
    title("Corporate ESG, Sin Industries, and Earnings Management (Full Controls)") ///
    addnotes("Robust standard errors clustered at firm level." "All models include controls.")

* --- 4.4 Robustness: Regression without CEO Controls ---
global ctrl_no_ceo size mb2 lev roa growth_asset cash_holding ///
                   per_io big_4 firm_age ///
                   duality bod_independence bod_size

eststo clear

* Model 1-3: Main Effects (No CEO controls)
foreach v in vs_11 vs_4 vs_6 {
    quietly reghdfe ko_da_sic `v' 1.industry_type $ctrl_no_ceo, absorb(year gvkey) cluster(gvkey)
    estimates store m_`v'_nc
    quietly eststo m_`v'_nc
    quietly estadd local fe_year "Yes"
    quietly estadd local fe_firm "Yes"
}

* Model 4-6: Interaction Effects (No CEO controls)
foreach v in vs_11 vs_4 vs_6 {
    quietly reghdfe ko_da_sic c.`v'##i.industry_type $ctrl_no_ceo, absorb(year gvkey) cluster(gvkey)
    estimates store i_`v'_nc
    quietly eststo i_`v'_nc
    quietly estadd local fe_year "Yes"
    quietly estadd local fe_firm "Yes"
}

* Export to RTF (Excluding CEO Age and Gender)
esttab m_vs_11_nc m_vs_4_nc m_vs_6_nc i_vs_11_nc i_vs_4_nc i_vs_6_nc using "$OUTPUT\Master_Results_no_CEO.rtf", ///
    replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    label compress nogaps ///
    mtitles("Main" "Main" "Main" "Int" "Int" "Int") ///
    scalars("fe_year Year FE" "fe_firm Firm FE" "N Observations" "r2_a Adj. R-squared") ///
    title("Corporate ESG, Sin Industries, and Earnings Management (Excluding CEO Controls)") ///
    addnotes("Robust standard errors clustered at firm level." "CEO Age and CEO Gender are excluded from these models.")

display as text ">>> Analysis completed. Results saved to Master_Results.rtf and Master_Results_no_CEO.rtf"

/* ====================================================================
   PART 5: ENTROPY BALANCE MATCHING (EBM) ANALYSIS
   ==================================================================== */
display as text ">>> Starting Part 5: Entropy Balance Analysis..."

* Install ebalance if not present
capture which ebalance
if _rc {
    display "Installing ebalance package..."
    ssc install ebalance
}

* Create High/Low groups for vs_4 (Environmental Score)
summarize vs_4, detail
capture drop high_vs4
gen high_vs4 = (vs_4 > r(p50)) if !missing(vs_4)
label var high_vs4 "High Environmental Score (vs_4 > Median)"

* Entropy Balancing
* Characteristics: Size, MB, Leverage, ROA
* Treatment: high_vs4 (High Environmental Score firms)
* We balance the mean (targets(1)) of covariates for treatment and control groups
capture drop _webal
ebalance high_vs4 size mb2 lev roa, targets(1)

* Check matching results
display "Entropy Balance Summary:"
sum _webal if high_vs4 == 0
sum _webal if high_vs4 == 1

eststo clear

* Model 1: Effect of High vs_4 on EM (Entropy Weighted)
quietly reghdfe ko_da_sic 1.high_vs4 $ctrl [iweight=_webal], absorb(year gvkey) cluster(gvkey)
estimates store m1_eb
quietly eststo m1_eb
quietly estadd local fe_year "Yes"
quietly estadd local fe_firm "Yes"
quietly estadd local matching "EBM"

* Model 2: Interaction with Industry Type
quietly reghdfe ko_da_sic 1.high_vs4##1.industry_type $ctrl [iweight=_webal], absorb(year gvkey) cluster(gvkey)
estimates store m2_eb
quietly eststo m2_eb
quietly estadd local fe_year "Yes"
quietly estadd local fe_firm "Yes"
quietly estadd local matching "EBM"

* Export to RTF (Entropy Balance Results)
esttab m1_eb m2_eb using "$OUTPUT\Master_Results_Entropy.rtf", ///
    replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    label compress nogaps ///
    mtitles("Main" "Interaction") ///
    scalars("fe_year Year FE" "fe_firm Firm FE" "matching Matching" "N Observations" "r2_a Adj. R-squared") ///
    title("Corporate ESG, Sin Industries, and Earnings Management (Entropy Balance on vs_4)") ///
    addnotes("Robust standard errors clustered at firm level." "Treatment is High Environmental Score (vs_4 > Median)." "Sample balanced on Size, MB, Lev, and ROA using Entropy Balancing.")

display as text ">>> Entropy Balance Analysis (vs_4 treatment) completed. Results saved to Master_Results_Entropy_vs4.rtf"

/* ====================================================================
   PART 5.5: DESCRIPTIVE STATISTICS (Table 1)
   ==================================================================== */
display as text ">>> Generating Table 1: Descriptive Statistics and Correlations..."

* 1. Descriptive Statistics
eststo clear
estpost summarize ko_da_sic vs_4 vs_6 industry_type under_duration_c $ctrl, listwise
esttab using "$OUTPUT\Table1_Descriptive_Stats.rtf", replace ///
    cells("count mean(fmt(3)) sd(fmt(3)) min(fmt(3)) max(fmt(3))") ///
    noobs label title("Table 1: Descriptive Statistics")

* 2. Correlation Matrix
eststo clear
estpost correlate ko_da_sic vs_4 vs_6 industry_type under_duration_c $ctrl, matrix listwise
esttab using "$OUTPUT\Table1_Correlation_Matrix.rtf", replace ///
    unstack not noobs compress ///
    b(%9.3f) star(* 0.10 ** 0.05 *** 0.01) ///
    label title("Table 1 (Panel B): Correlation Matrix")

display as text ">>> Table 1 generated: Table1_Descriptive_Stats.rtf and Table1_Correlation_Matrix.rtf"


/* ====================================================================
   PART 6: ROBUSTNESS CHECK WITH ALTERNATIVE DV (FF48-BASED DA)
   ==================================================================== */
display as text ">>> Starting Part 6: Robustness with ko_da_ff..."

eststo clear

* Model 1-3: Main Effects (DV: ko_da_ff)
foreach v in vs_11 vs_4 vs_6 {
    quietly reghdfe ko_da_ff `v' 1.industry_type $ctrl, absorb(year gvkey) cluster(gvkey)
    estimates store m_`v'_ff
    quietly eststo m_`v'_ff
    quietly estadd local fe_year "Yes"
    quietly estadd local fe_firm "Yes"
    quietly estadd local dv_type "FF48-based"
}

* Model 4-6: Interaction Effects (DV: ko_da_ff)
foreach v in vs_11 vs_4 vs_6 {
    quietly reghdfe ko_da_ff c.`v'##i.industry_type $ctrl, absorb(year gvkey) cluster(gvkey)
    estimates store i_`v'_ff
    quietly eststo i_`v'_ff
    quietly estadd local fe_year "Yes"
    quietly estadd local fe_firm "Yes"
    quietly estadd local dv_type "FF48-based"
}

* Export to RTF (FF48 Results)
esttab m_vs_11_ff m_vs_4_ff m_vs_6_ff i_vs_11_ff i_vs_4_ff i_vs_6_ff using "$OUTPUT\Master_Results_FF48.rtf", ///
    replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    label compress nogaps ///
    mtitles("Main" "Main" "Main" "Int" "Int" "Int") ///
    scalars("fe_year Year FE" "fe_firm Firm FE" "dv_type DV Type" "N Observations" "r2_a Adj. R-squared") ///
    title("Corporate ESG, Sin Industries, and Earnings Management (Robustness: FF48-based DA)") ///
    addnotes("Robust standard errors clustered at firm level." "The dependent variable (ko_da_ff) is calculated based on Fama-French 48 industry classification.")

display as text ">>> Robustness check with ko_da_ff completed. Results saved to Master_Results_FF48.rtf"

/* ====================================================================
   PART 7: ROBUSTNESS WITH STATE*YEAR FIXED EFFECTS
   ==================================================================== */
display as text ">>> Starting Part 7: Robustness with State*Year FE..."

* Encode state if it's a string
capture confirm numeric variable state
if _rc {
    display "Encoding state variable..."
    capture encode state, gen(state_n)
}
else {
    capture gen state_n = state
}

eststo clear

* Model 1-3: Main Effects (with State*Year FE)
foreach v in vs_11 vs_4 vs_6 {
    quietly reghdfe ko_da_sic `v' 1.industry_type $ctrl, absorb(gvkey state_n#year) cluster(gvkey)
    estimates store m_`v'_sy
    quietly eststo m_`v'_sy
    quietly estadd local fe_firm "Yes"
    quietly estadd local fe_state_year "Yes"
}

* Model 4-6: Interaction Effects (with State*Year FE)
foreach v in vs_11 vs_4 vs_6 {
    quietly reghdfe ko_da_sic c.`v'##i.industry_type $ctrl, absorb(gvkey state_n#year) cluster(gvkey)
    estimates store i_`v'_sy
    quietly eststo i_`v'_sy
    quietly estadd local fe_firm "Yes"
    quietly estadd local fe_state_year "Yes"
}

* Export to RTF (State*Year FE Results)
esttab m_vs_11_sy m_vs_4_sy m_vs_6_sy i_vs_11_sy i_vs_4_sy i_vs_6_sy using "$OUTPUT\Master_Results_StateYear.rtf", ///
    replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    label compress nogaps ///
    mtitles("Main" "Main" "Main" "Int" "Int" "Int") ///
    scalars("fe_firm Firm FE" "fe_state_year State*Year FE" "N Observations" "r2_a Adj. R-squared") ///
    title("Corporate ESG, Sin Industries, and Earnings Management (Robustness: State*Year FE)") ///
    addnotes("Robust standard errors clustered at firm level." "Models include Firm and State*Year fixed effects.")

display as text ">>> Robustness check with State*Year FE completed. Results saved to Master_Results_StateYear.rtf"

/* ====================================================================
   PART 8: EFFECT OF LAGGED EARNINGS MANAGEMENT ON ESG (vs_4)
   ==================================================================== */
display as text ">>> Starting Part 8: Regression of vs_4 on lagged ko_da_sic..."

eststo clear

* Model 1: Regression of Environmental Score on Lagged DA
* Dependent Variable: vs_4 (Environmental Score)
* Independent Variable: l.ko_da_sic (Lagged Earnings Management)
quietly reghdfe vs_4 l.ko_da_sic $ctrl, absorb(year gvkey) cluster(gvkey)
estimates store m_em_esg
quietly eststo m_em_esg
quietly estadd local fe_year "Yes"
quietly estadd local fe_firm "Yes"

* Model 2: Interaction with Industry Type (Optional but consistent with other parts)
quietly reghdfe vs_4 c.l.ko_da_sic##i.industry_type $ctrl, absorb(year gvkey) cluster(gvkey)
estimates store i_em_esg
quietly eststo i_em_esg
quietly estadd local fe_year "Yes"
quietly estadd local fe_firm "Yes"

* Export to RTF
esttab m_em_esg i_em_esg using "$OUTPUT\Master_Results_EM_Lag.rtf", ///
    replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    label compress nogaps ///
    mtitles("Main" "Interaction") ///
    scalars("fe_year Year FE" "fe_firm Firm FE" "N Observations" "r2_a Adj. R-squared") ///
    title("Effect of Lagged Earnings Management on Environmental Score (vs_4)") ///
    addnotes("Robust standard errors clustered at firm level." "IV is lagged ko_da_sic (t-1).")

display as text ">>> Analysis of lagged EM on ESG completed. Results saved to Master_Results_EM_Lag.rtf"
log close


