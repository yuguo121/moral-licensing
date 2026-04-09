* =============================================================================
* 【早期版本】来源项目：Corporate ESG and EM
* 现位置：Moral Lisensing/code/legacy_corporate_esg_em/
* 说明：保留作历史对照；路径与变量名可能仍为旧项目设定，运行前请自行核对。
* 主线分析请使用：code/Master_Analysis.do 或 Master_Analysis_v2.do 等。
* 迁入日期：2026-04-01
* =============================================================================
cd "D:\OneDrive - HKUST (Guangzhou)\Data"

use final_panel,clear

use final_sep,clear

global ctrl1   size mb1 roa lev growth_asset cash_holding ///
              per_io big_4 firm_age ceo_age ceo_gender ///
              ceo_LogCompensation ceo_per_stock ceo_per_cash ///
              duality bod_independence bod_size 
global ctrl2   size mb2 roa lev growth_asset cash_holding ///
              per_io big_4 firm_age ceo_age ceo_gender ///
              ceo_LogCompensation ceo_per_stock ceo_per_cash ///
              duality bod_independence bod_size  
			 
global ctrl   size mb2 lev growth_asset cash_holding ///
              per_io big_4 firm_age ceo_age ceo_gender ///
              ceo_LogCompensation ceo_per_stock ceo_per_cash ///
              duality bod_independence bod_size  			 
* log using Sep15, append smcl			 
		*_da_* 	  
winsor2  size mb* roa lev growth_asset cash_holding per_io  ceo_age  ceo_LogCompensation ceo_per_stock ceo_per_cash  ,cuts(1 99) replace

replace ceo_age=ln(ceo_age)
 
drop env emp
local var "env emp com div hum pro cgov"

foreach v of local var{
	xtset gvkey year
	sort year
	by year: egen mean_`v'=mean(`v'_str_num1)
	gen `v'=`v'_str_num1-mean_`v'
	sort gvkey year
	by gvkey: gen l_`v'=l.`v'


	* Step 1: Mark non-missing observations
	gen nonmiss = !missing(l_`v')

	* Step 2: Calculate total and count of l_kldnocg per industry-year
	bysort sic_2 year: egen total_l_`v' = total(l_`v')
	bysort sic_2 year: egen count_l_`v' = count(l_`v')

	* Step 3: Compute average el_kldnocgcluding the current firm
	gen industry_avg_`v' = (total_l_`v' - l_`v') / (count_l_`v' - 1) if nonmiss & count_l_`v' > 1
	replace industry_avg_`v' = . if nonmiss & count_l_`v' == 1  // Not defined for single-firm industries

	* Cleanup (optional)
	drop nonmiss total_l_`v' count_l_`v'
	
	xtreg `v' industry_avg_`v' $ctrl i.year, fe vce(robust)
	predict double `v'_hat, xb 
	
	// Store the model for esttab
	est store esg_`v'
	
	// Export ESG regression results to Excel
	esttab esg_`v' using "$out\esg_`v'_results.xlsx", ///
		replace type star(* 0.10 ** 0.05 *** 0.01) ///
		stats(N r2_a, fmt(%9.0f %9.3f) labels("Observations" "R-squared")) ///
		b(%9.3f) se(%9.3f) ///
		title("ESG Analysis: `v'") ///
		nogap compress ///
		note("Standard errors clustered at firm level in parentheses. *** p<0.01, ** p<0.05, * p<0.1")
}

local var "vs_1 vs_4 vs_5 vs_6"

foreach v of local var{

	sort gvkey year
	by gvkey: gen l_`v'=l.`v'


	* Step 1: Mark non-missing observations
	gen nonmiss = !missing(l_`v')

	* Step 2: Calculate total and count of l_kldnocg per industry-year
	bysort sic_2 year: egen total_l_`v' = total(l_`v')
	bysort sic_2 year: egen count_l_`v' = count(l_`v')

	* Step 3: Compute average el_kldnocgcluding the current firm
	gen industry_avg_`v' = (total_l_`v' - l_`v') / (count_l_`v' - 1) if nonmiss & count_l_`v' > 1
	replace industry_avg_`v' = . if nonmiss & count_l_`v' == 1  // Not defined for single-firm industries

	* Cleanup (optional)
	drop nonmiss total_l_`v' count_l_`v'
	
	xtreg `v' industry_avg_`v' $ctrl i.year, fe vce(robust)
	predict double `v'_hat, xb 
	
	// Store the model for esttab
	est store vs_`v'
	
	// Export Value System regression results to Excel
	esttab vs_`v' using "$out\vs_`v'_results.xlsx", ///
		replace type star(* 0.10 ** 0.05 *** 0.01) ///
		stats(N r2_a, fmt(%9.0f %9.3f) labels("Observations" "R-squared")) ///
		b(%9.3f) se(%9.3f) ///
		title("Value System Analysis: `v'") ///
		nogap compress ///
		note("Standard errors clustered at firm level in parentheses. *** p<0.01, ** p<0.05, * p<0.1")
}


local var "vs_1 vs_4 vs_5 vs_6"

foreach v of local var{
	xtset gvkey year
	sort year
	by year: egen mean_`v'_year=mean(`v')
	gen c_`v'=`v'-mean_`v'_year
	drop mean_`v'_year
}


local var "vs_1 vs_4 vs_5 vs_6"

foreach v of local var{
	xtset gvkey year
	sort gvkey year

	* Step 2: Calculate total and count of l_kldnocg per industry-year
	bysort sic_2 year: egen mean_`v'_ind = mean(`v')
	bysort sic_2 year: egen median_`v' = median(`v')

	
	xtreg `v' median_`v' $ctrl i.year, fe vce(robust)
	predict double `v'_hat_new, xb 
}

global out   "D:\OneDrive - HKUST (Guangzhou)\Data\output"   // 自行修改
cap mkdir "$out"
if _rc != 0 {
    display "Output directory already exists or created successfully"
}

// Create summary statistics table
preserve
keep if !missing(yu_da_ff)
summarize yu_da_ff size mb2 lev growth_asset cash_holding per_io big_4 firm_age ceo_age ceo_gender ceo_LogCompensation ceo_per_stock ceo_per_cash duality bod_independence bod_size, detail
putexcel set "$out\summary_statistics.xlsx", replace
putexcel A1 = "Variable"
putexcel B1 = "Obs"
putexcel C1 = "Mean"
putexcel D1 = "Std Dev"
putexcel E1 = "Min"
putexcel F1 = "Max"
putexcel G1 = "P25"
putexcel H1 = "P50"
putexcel I1 = "P75"

local row = 2
foreach var of varlist yu_da_ff size mb2 lev growth_asset cash_holding per_io big_4 firm_age ceo_age ceo_gender ceo_LogCompensation ceo_per_stock ceo_per_cash duality bod_independence bod_size {
    quietly summarize `var', detail
    putexcel A`row' = "`var'"
    putexcel B`row' = r(N)
    putexcel C`row' = r(mean)
    putexcel D`row' = r(sd)
    putexcel E`row' = r(min)
    putexcel F`row' = r(max)
    putexcel G`row' = r(p25)
    putexcel H`row' = r(p50)
    putexcel I`row' = r(p75)
    local row = `row' + 1
}
restore

gen kld5=emp+env+com+hum+div
gen kld7=emp+env+com+hum+div+pro+cgov
local x "kld5 kld7"

encode state,gen(state_id)

local var_region "env emp com div hum pro cgov vs_1 vs_4 vs_5 vs_6"

foreach v of local var_region{

	* Step 1: Mark non-missing observations
	gen nonmiss = !missing(`v')

	* Step 2: Calculate total and count of l_kldnocg per industry-year
	bysort state_id year: egen total_`v' = total(`v')
	bysort state_id year: egen count_`v' = count(`v')

	* Step 3: Compute average el_kldnocgcluding the current firm
	gen state_avg_`v' = (total_`v' - `v') / (count_`v' - 1) if nonmiss & count_`v' > 1
	replace state_avg_`v' = . if nonmiss & count_`v' == 1  // Not defined for single-firm industries

	* Cleanup (optional)
	drop nonmiss total_`v' count_`v'
	
	//xtreg `v' state_avg_`v' $ctrl i.year, fe vce(robust)
	//predict double `v'_hat, xb 
}

local x "vs_1 vs_4 vs_5 vs_6"
// 初始化 RTF 文件（如果已存在则删除）

foreach v of local x {
    est clear
    quietly {
        reghdfe yu_da_ff $ctrl , absorb(year gvkey) cluster(gvkey)
        est store m1
        reghdfe yu_da_ff $ctrl `v' , absorb(year gvkey) cluster(gvkey)
        est store m2
        
        // IV regression using industry average as instrument
        ivreghdfe yu_da_ff $ctrl (`v' = industry_avg_`v') , absorb(year gvkey) cluster(gvkey)
        estadd scalar waldF = e(widstat)
        estadd scalar sarganP = e(sarganp)
        est store m3
    }

    // 使用 esttab 输出到 Excel 并追加
    if "`v'" == "vs_1" {
		esttab m1 m2 m3 using `"$out\da_full_916.xlsx"', ///
			replace type star(* 0.10 ** 0.05 *** 0.01) ///
			stats(N r2_a waldF sarganP, fmt(%9.0f %9.3f %9.3f %9.3f) ///
			      labels("Observations" "R-squared" "Weak ID F-stat" "Sargan P-value")) ///
			b(%9.3f) se(%9.3f) ///
			title("Table: Discretionary Accruals on `v'") ///
			mtitle("OLS" "OLS+`v'" "IV") ///
			nogap compress ///
			note("Standard errors clustered at firm level in parentheses. *** p<0.01, ** p<0.05, * p<0.1")
    }
    else {
        esttab m1 m2 m3 using "$out\da_full_916.xlsx", ///
            append /// 后续表追加到文件
            star(* 0.10 ** 0.05 *** 0.01) ///
            stats(N r2_a waldF sarganP, fmt(%9.0f %9.3f %9.3f %9.3f) ///
                  labels("Observations" "R-squared" "Weak ID F-stat" "Sargan P-value")) ///
            b(%9.3f) se(%9.3f) ///
            title("Table: Discretionary Accruals on `v'") ///
            mtitle("OLS" "OLS+`v'" "IV") ///
			nogap compress ///
            note("Standard errors clustered at firm level in parentheses. *** p<0.01, ** p<0.05, * p<0.1")
    }
    
  
}



