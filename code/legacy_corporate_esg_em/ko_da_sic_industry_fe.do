* =============================================================================
* 【早期版本】来源项目：Corporate ESG and EM
* 现位置：Moral Lisensing/code/legacy_corporate_esg_em/
* 说明：保留作历史对照；路径与变量名可能仍为旧项目设定，运行前请自行核对。
* 主线分析请使用：code/Master_Analysis.do 或 Master_Analysis_v2.do 等。
* 迁入日期：2026-04-01
* =============================================================================
/*
================================================================================
STATA DO FILE: Multi-ESG Dimension Analysis with Industry Fixed Effects
================================================================================
Purpose: Test vs_1 (ESG), vs_4 (Env), vs_6 (Soc) size-free scores with ko_da_sic
         Using MEAN-CENTERED under_duration to preserve main effects
         WITHOUT SRI ownership variable and interactions
         Using INDUSTRY FIXED EFFECTS instead of firm fixed effects

Key Updates: 
- Using mean-centered under_duration to solve multicollinearity
- Removed SRI ownership variable (dum_per_sri) and its interactions
- **Using Industry (sic_2) fixed effects instead of firm (gvkey) fixed effects**
- **Two specifications for each ESG dimension:**
  1. Year FE + Industry FE (absorb(year industry))
  2. Year×Industry FE (absorb(year#industry))

DA Measure:
- ko_da_sic - Kothari et al. (2005) SIC-adjusted

Models (for each ESG dimension × 2 specifications = 6 tables total):
Specification A: Year FE + Industry FE + Firm FE
Specification B: Year×Industry FE + Firm FE

For each specification:
M1 = Baseline (vs_X_residual + vs_3 + vs_5)
M2 = + Culpable Industry
M3 = + Mean-Centered Underperf. Duration
M4 = xtabond2 Dynamic Panel (with lagged DV)
M5 = Full model with both moderators (Industry + Duration)
M6 = With vs_X Persistence Measure (3-year persistence dummy)

Author: Analysis Script
Date: October 14, 2025 (Industry FE version)
Output: test_3 subfolder
================================================================================
*/

// Set working directory
cd "C:\Users\HuGoL\OneDrive - HKUST (Guangzhou)\Research Project\Corporate ESG and EM"

// Load the dataset
use final_sep, clear

// Set output directory
global out "C:\Users\HuGoL\OneDrive - HKUST (Guangzhou)\Research Project\Corporate ESG and EM"

/*
================================================================================
SECTION 1: DATA PREPARATION
================================================================================
*/

display ""
display "======================================================================"
display "PREPARING INDUSTRY VARIABLE (sic_2)"
display "======================================================================"

// Generate 2-digit SIC code if not already present
capture confirm variable sic_2
if _rc != 0 {
    display "Creating sic_2 from sic variable..."
    gen sic_2 = floor(sic/100)
    label variable sic_2 "2-digit SIC code"
}

// Check if sic_2 is string or numeric
capture confirm numeric variable sic_2
if _rc != 0 {
    display "sic_2 is string, encoding..."
    encode sic_2, gen(industry)
    label variable industry "Industry (encoded from sic_2)"
} 
else {
    display "sic_2 is numeric, using as industry..."
    gen industry = sic_2
    label variable industry "Industry (2-digit SIC)"
}

display "Industry variable prepared successfully"
tab industry, missing

// Define control variables
global ctrl   size mb2 lev roa growth_asset cash_holding ///
              per_io big_4 firm_age ceo_age ceo_gender ///
              ceo_LogCompensation ceo_per_stock ceo_per_cash ///
              duality bod_independence bod_size

// Transform CEO age
replace ceo_age = ln(ceo_age)

// Winsorize controls
winsor2  size mb* roa lev growth_asset cash_holding per_* big_4 firm_age ceo_age ///
         ceo_gender ceo_LogCompensation ceo_per_stock ceo_per_cash duality ///
         bod_independence bod_size, cuts(1 99) replace

// Winsorize vs_3, vs_5 and DA measure
winsor2 ko_da_sic, cuts(1 99) replace

// Label vs_5 as Gov
label variable vs_5 "Gov (Governance)"

/*
================================================================================
SECTION 2: GENERATE SIZE-FREE COMPONENTS FOR VS_1, VS_4, VS_6
================================================================================
*/

display ""
display "======================================================================"
display "GENERATING SIZE-FREE COMPONENTS FOR ESG DIMENSIONS"
display "======================================================================"

// Set panel structure (using gvkey for panel, but will use industry FE)
xtset gvkey year

// Define size control variables
global size_ctrl mb2 lev roa

// Loop through vs_1 (ESG), vs_4 (Env), vs_6 (Soc) to create size-free components
foreach vs_var in vs_1 vs_4 vs_6 {
    
    display ""
    display "Processing `vs_var'..."
    
    // Auxiliary regression: vs_var ~ size + size_controls + FE
    quietly: reghdfe `vs_var' size $size_ctrl, absorb(year industry gvkey) cluster(gvkey) resid
    
    // Generate residual (size-free component)
    capture drop `vs_var'_residual
    predict `vs_var'_residual, residuals
    label variable `vs_var'_residual "`vs_var' residual (size-free component)"
    
    // Generate predicted value (size-explained component)
    capture drop `vs_var'_predicted
    predict `vs_var'_predicted, xbd
    label variable `vs_var'_predicted "`vs_var' predicted (size-explained component)"
    
    display "  - Created `vs_var'_residual (size-free)"
    display "  - Created `vs_var'_predicted (size-explained)"

    // ------------------------------------------------------------------
    // Generate IVs: Peer Effects (Industry and Region)
    // ------------------------------------------------------------------
    
    // 1. Industry Peer IV: Mean of peers in same industry (sic_2), same year
    // Formula: (Sum_Ind - Self) / (N_Ind - 1)
    bysort year industry: egen double temp_sum_ind = total(`vs_var'_residual)
    bysort year industry: egen long temp_n_ind = count(`vs_var'_residual)
    
    capture drop `vs_var'_iv_ind
    gen `vs_var'_iv_ind = (temp_sum_ind - `vs_var'_residual) / (temp_n_ind - 1)
    label variable `vs_var'_iv_ind "Industry IV: Mean of peers in same sic_2"
    drop temp_sum_ind temp_n_ind

    // 2. Region Peer IV: Mean of peers in same region (state), same year, EXCLUDING same industry
    // Formula: (Sum_State - Sum_State_Ind) / (N_State - N_State_Ind)
    // This removes the contribution of the specific industry within that state.
    
    capture confirm variable state
    if _rc == 0 {
        // Total for State-Year
        bysort year state: egen double temp_sum_st = total(`vs_var'_residual)
        bysort year state: egen long temp_n_st = count(`vs_var'_residual)
        
        // Total for State-Industry-Year
        bysort year state industry: egen double temp_sum_st_ind = total(`vs_var'_residual)
        bysort year state industry: egen long temp_n_st_ind = count(`vs_var'_residual)
        
        // Calculate IV
        capture drop `vs_var'_iv_reg
        gen `vs_var'_iv_reg = (temp_sum_st - temp_sum_st_ind) / (temp_n_st - temp_n_st_ind)
        label variable `vs_var'_iv_reg "Region IV: Mean of peers in same state (excl. same sic_2)"
        
        drop temp_sum_st temp_n_st temp_sum_st_ind temp_n_st_ind
        display "  - Created `vs_var'_iv_ind and `vs_var'_iv_reg"
    }
    else {
        display "  - Warning: 'state' variable not found. Region IV skipped."
        display "  - Created `vs_var'_iv_ind"
    }
}

display ""
display "All size-free components created successfully"

/*
================================================================================
SECTION 3: CREATE MODERATOR VARIABLES
================================================================================
*/

display ""
display "======================================================================"
display "CREATING MODERATOR VARIABLES"
display "======================================================================"

// 1. industry_type (1=culpable industry, 0=non-culpable)
display "1. industry_type: 1=culpable industry, 0=non-culpable"
capture confirm variable industry_type
if _rc != 0 {
    display "Creating industry_type based on common Sin/Polluting industries (Tobacco, Chemicals, Petroleum, Metal)..."
    // SIC 2 codes: 21 (Tobacco), 28 (Chemicals), 29 (Petroleum), 33 (Primary Metal)
    gen industry_type = 0
    replace industry_type = 1 if inlist(sic_2, 21, 28, 29, 33)
    label variable industry_type "Culpable Industry (Sin/Polluting)"
}

// 2. Create MEAN-CENTERED under_duration
display "2. under_duration: mean-centered (to preserve main effects)"
sum under_duration, detail
scalar mean_under = r(mean)
gen under_duration_c = under_duration - mean_under
label variable under_duration_c "Underperformance duration (mean-centered)"
display "   - Mean of under_duration: " mean_under
display "   - Created under_duration_c (mean-centered)"
sum under_duration_c, detail

// 3. Create persistence measures (last 3 years > yearly median)
display ""
display "3. Creating persistence measures (last 3 years > yearly median)..."

// Generate lagged values for vs_1, vs_4, vs_6
sort gvkey year
foreach vs in vs_1 vs_4 vs_6 {
    capture drop L1_`vs' L2_`vs' L3_`vs'
    by gvkey: gen L1_`vs' = L.`vs'
    by gvkey: gen L2_`vs' = L2.`vs'
    by gvkey: gen L3_`vs' = L3.`vs'
}

// Calculate yearly median for each ESG dimension and create lagged medians
foreach vs in vs_1 vs_4 vs_6 {
    // Calculate yearly median
    capture drop `vs'_median_temp
    bysort year: egen `vs'_median_temp = median(`vs')
    
    // Sort before creating lags
    sort gvkey year
    
    // Create lagged yearly medians
    capture drop L1_`vs'_median L2_`vs'_median L3_`vs'_median
    by gvkey: gen L1_`vs'_median = `vs'_median_temp[_n-1]
    by gvkey: gen L2_`vs'_median = `vs'_median_temp[_n-2]
    by gvkey: gen L3_`vs'_median = `vs'_median_temp[_n-3]
    
    drop `vs'_median_temp
}

// Create persistence dummies for each ESG dimension
foreach vs in vs_1 vs_4 vs_6 {
    capture drop `vs'_persist
    gen `vs'_persist = 0
    replace `vs'_persist = 1 if L1_`vs' > L1_`vs'_median & L2_`vs' > L2_`vs'_median & L3_`vs' > L3_`vs'_median ///
        & !missing(L1_`vs') & !missing(L2_`vs') & !missing(L3_`vs') ///
        & !missing(L1_`vs'_median) & !missing(L2_`vs'_median) & !missing(L3_`vs'_median)
    label variable `vs'_persist "Dummy: 1 if `vs' > yearly median for last 3 years"
    display "   - Created `vs'_persist (based on yearly median threshold)"
}

display ""
display "Summary of persistence measures (yearly median-based):"
sum vs_1_persist vs_4_persist vs_6_persist, detail

/*
================================================================================
SECTION 4: MAIN REGRESSION ANALYSIS - OLS + IV
================================================================================
Models:
1. OLS Base: ko_da_sic ~ vs_residual + vs_5 + Controls
2. OLS Mod 1: Base + vs_residual * industry_type
3. OLS Mod 2: Base + vs_residual * under_duration_c
4. OLS Full: Base + Both Interactions
5. IV Base: Instrument vs_residual with Peer IVs (Ind + Reg)
6. IV Full: Instrument vs_residual and interactions with Peer IV interactions
================================================================================
*/

display ""
display "======================================================================"
display "RUNNING REGRESSIONS: OLS + IV (Firm FE + Year FE)"
display "======================================================================"

// Define variables
local vs_vars "vs_1 vs_4 vs_6"
local vs_1_fullname "ESG Score"
local vs_4_fullname "Environmental Score"
local vs_6_fullname "Social Score"

// Loop through each ESG dimension
// Label variables to match the target Table format
label variable size "Firm Size"
label variable lev "Debt Ratio"
label variable cash_holding "Cash ratio"
label variable roa "ROA"
label variable mb2 "Tobin's Q"
label variable per_io "Institutional Ownership"
label variable bod_size "Board Size"
label variable bod_independence "Board Independence"
label variable duality "CEO Duality"
label variable ceo_gender "CEO Gender"
label variable ceo_age "CEO Age"
label variable ceo_LogCompensation "CEO Total Compensation"
label variable ceo_per_cash "% Cash in Compensation"
label variable ceo_per_stock "% Stock in Compensation"
label variable growth_asset "Growth Rate"
label variable big_4 "Big Auditors"
label variable firm_age "Firm Age"
label variable industry_type "Industrial Culpability"
label variable under_duration_c "Underperformance Duration"

// Generate combined score
capture drop es
gen es = vs_4 + vs_6

// Loop through each score to generate separate tables
foreach var in vs_4 vs_6 es {
    
    // Clear stored estimates
    eststo clear
    
    // Define label based on current variable
    if "`var'" == "vs_4" local lbl "Environmental Score"
    if "`var'" == "vs_6" local lbl "Social Score"
    if "`var'" == "es"   local lbl "Combined ESG Score"
    
    // Set label for the current main variable
    label variable `var' "`lbl'"
    
    // Model 1: Base + Controls + Moderators (Main Effects)
    eststo m1: reghdfe ko_da_sic `var' under_duration_c industry_type $ctrl, a(year gvkey) cluster(gvkey)
    
    // Model 2: Moderation 1 (Industrial Culpability)
    eststo m2: reghdfe ko_da_sic c.`var'##c.industry_type under_duration_c $ctrl, a(year gvkey) cluster(gvkey)
    
    // Model 3: Moderation 2 (Underperformance Duration)
    eststo m3: reghdfe ko_da_sic c.`var'##c.under_duration_c industry_type $ctrl, a(year gvkey) cluster(gvkey)
    
    // Model 4: Full Model
    eststo m4: reghdfe ko_da_sic c.`var'##c.industry_type c.`var'##c.under_duration_c $ctrl, a(year gvkey) cluster(gvkey)
    
    // Define interaction labels
    local lbl_ind "`lbl' x Industrial Culpability"
    local lbl_dur "`lbl' x Underperformance Duration"
    
    // Export to RTF
    // Added firm_age to order
    esttab m1 m2 m3 m4 using "$out/Table_`var'.rtf", replace ///
        b(%9.3f) p(%9.3f) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        stats(r2_a N, fmt(3 0) labels("Adj. R-square" "Observations")) ///
        label varlabels(_cons "Constant") ///
        coeflabels(c.`var'#c.industry_type "`lbl_ind'" c.`var'#c.under_duration_c "`lbl_dur'") ///
        title("Effect of `lbl' on Discretionary Accruals") ///
        mtitles("Model 1" "Model 2" "Model 3" "Model 4") ///
        order(size lev cash_holding roa mb2 per_io bod_size bod_independence duality ceo_gender ceo_age ceo_LogCompensation ceo_per_cash ceo_per_stock growth_asset big_4 firm_age industry_type under_duration_c `var' c.`var'#c.industry_type c.`var'#c.under_duration_c) ///
        addnote("Note: p-values in parentheses (* 0.10 ** 0.05 *** 0.01)")
        
    display "Generated table for `var' -> Table_`var'.rtf"
}


/*
================================================================================
SECTION 5: OUTPUT TABLES
================================================================================
*/

display ""
display "======================================================================"
display "GENERATING OUTPUT TABLES"
display "======================================================================"

foreach vs_var of local vs_vars {
    
    display "Creating table for `vs_var'..."
    
    esttab `vs_var'_ols_base `vs_var'_ols_mod1 `vs_var'_ols_mod2 `vs_var'_ols_full `vs_var'_iv_base `vs_var'_iv_full ///
        using "$out/`vs_var'_ols_iv_results.tex", ///
        replace type star(* 0.10 ** 0.05 *** 0.01) ///
        keep(`vs_var'_residual vs_5 industry_type under_duration_c ///
             c.`vs_var'_residual#c.industry_type c.`vs_var'_residual#c.under_duration_c) ///
        order(`vs_var'_residual c.`vs_var'_residual#c.industry_type c.`vs_var'_residual#c.under_duration_c ///
              vs_5 industry_type under_duration_c) ///
        stats(true_N true_r2_a f_stat, fmt(%9.0fc %9.3f %9.2f) ///
        labels("Observations" "Adj. R-squared" "Kleibergen-Paap F")) ///
        b(%9.4f) se(%9.4f) ///
        coeflabels(`vs_var'_residual "``vs_var'_fullname' (Size-Free)" ///
                  vs_5 "Governance Score" ///
                  industry_type "Culpable Industry" ///
                  under_duration_c "Underperf. Duration (Mean-C)" ///
                  c.`vs_var'_residual#c.industry_type "``vs_var'_fullname' x Culpable Ind" ///
                  c.`vs_var'_residual#c.under_duration_c "``vs_var'_fullname' x Duration") ///
        title("OLS and IV Results for ``vs_var'_fullname'") ///
        mtitle("OLS Base" "OLS Mod 1" "OLS Mod 2" "OLS Full" "IV Base" "IV Full") ///
        compress nonumbers
        
     display "   - Saved: `vs_var'_ols_iv_results.tex"
}

display ""
display "Analysis Complete."
capture log close
