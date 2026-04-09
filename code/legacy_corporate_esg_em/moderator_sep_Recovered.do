* =============================================================================
* 【早期版本】来源项目：Corporate ESG and EM
* 现位置：Moral Lisensing/code/legacy_corporate_esg_em/
* 说明：保留作历史对照；路径与变量名可能仍为旧项目设定，运行前请自行核对。
* 主线分析请使用：code/Master_Analysis.do 或 Master_Analysis_v2.do 等。
* 迁入日期：2026-04-01
* =============================================================================
cd "C:\Users\HuGoL\OneDrive - HKUST (Guangzhou)\Data"


use "E:\github\earnings-management-measurement-using-compustat\playboard_aug",clear

xtset gvkey year
sort gvkey year


** code BigN
merge 1:1 gvkey year using "E:\empirical_study\data_raw\firm_age",keep(1 3 4 5) keepusing(age) nogen
gen big_n=au>0&au<9
gen big_4=au>3&au<9
gen firm_age = ln(age)
sort gvkey year
by gvkey: gen l_sale=l.sale
gen growth_sale=(sale-l_sale)/l_sale
by gvkey: gen l_at=l.at
gen growth_asset=(at-l_at)/l_at



***********underperformance
* Step 1: Compute industry-year median ROA (social aspiration)
xtset gvkey year
bysort sic year: egen aspiration_industry = median(roa)  // Industry aspiration at time t

* Step 2: Create social aspiration at t-1 (two-year lag relative to current year)
sort gvkey year
gen aspiration_t1 = L2.aspiration_industry  // Aspiration at t-1 = industry median at t-2

* Step 3: Lagged performance (ROA at t-1)
gen roa_lag = L.roa  // Performance at t-1

* Step 4: Underperformance indicator (1 if ROA at t-1 < social aspiration at t-1)
gen underperform = (roa_lag < aspiration_t1) if !missing(roa_lag, aspiration_t1)

* Step 5: Calculate consecutive underperformance duration
by gvkey: gen under_duration = underperform if _n == 1  // Initialize
by gvkey: replace under_duration = ///
    cond(underperform == 1,            ///
         cond(!missing(under_duration[_n-1]), under_duration[_n-1] + 1, 1), ///
         0) ///
    if _n > 1 & !missing(underperform)

* Label variables
label var aspiration_t1 "Social aspiration at t-1 (industry median ROA at t-2)"
label var underperform "Underperformance indicator at t-1"
label var under_duration "Consecutive years of underperformance up to t-1"


*-----------------------------
* 0. 设定面板
xtset gvkey year

* 1. 行业-年份中位 ROA (行业社会期望)
bysort sic2 year: egen aspiration_ind = median(roa)
sort gvkey year
* 2. t-1 年的行业社会期望 (行业在 t-2 年的中位 ROA)
gen aspiration1_t1 = L2.aspiration_ind
label var aspiration1_t1 "Industry median ROA at t-2"

* 3. t-1 年公司 ROA
gen roa_lag = L.roa
label var roa_lag "Firm ROA at t-1"
sort gvkey year
by gvkey: gen laggard=roa_lag-l.aspiration_ind
* 4. t-1 年是否低于社会期望
gen byte underperform1 = (roa_lag < aspiration1_t1) if !missing(roa_lag, aspiration1_t1)
label var underperform1 "1 if ROA(t-1) < industry median ROA(t-2)"

* 5. 计算连续低绩效年数
by gvkey: gen under_duration1 = underperform1 if _n == 1  // Initialize
bysort gvkey (year): replace under_duration1 = ///
    cond(underperform1==1, ///
         cond(_n==1, 1, cond(underperform1[_n-1]==1, under_duration1[_n-1]+1, 1)), ///
         0)
label var under_duration1 "Consecutive years of underperformance up to t-1"
*-----------------------------



* 行业-年份20分位阈值
bys sic_2 year: egen roap20 = pctile(roa_lag), p(20)

* 是否低于阈值
gen roap20_dum = roa_lag <= roap20 if !missing(roa_lag)

* 计算连续低于20%分位的年数
sort gvkey year
by gvkey: gen worst_duration = .
by gvkey: replace worst_duration = ///
    cond(roap20_dum==1, ///
         cond(_n==1, 1, worst_duration[_n-1] + 1), 0)


bys sic2 year: egen culpability=total(vs_3)

bys year: egen culpability_mean=mean(culpability)

replace culpability=(culpability-culpability_mean)/culpability_mean

xtile culpability_q5 = culpability, nq(5)
xtile culpability_q10 = culpability, nq(10)
xtile culpability_q5 = culpability, nq(5)

*******halo
gen kld_full = env_str_num1+ com_str_num1+ emp_str_num1+ div_str_num1+ pro_str_num1+ hum_str_num1- env_con_num1- com_con_num1- div_con_num1- pro_con_num1- emp_con_num1- hum_con_num1 + cgov_str_num1 - cgov_con_num1
* 生成行业-年份 50 分位阈值
egen p50 = pctile(vs_1), by(sic_2 year) p(50)
egen p90 = pctile(vs_1), by(sic_2 year) p(90)
* 哑元：当年是否前 50%
gen top10_dum = (vs_1 >= p90) if !missing(vs_1)
gen top50_dum = (vs_1 >= p50) if !missing(vs_1)
* 设定面板
sort gvkey year
tsset gvkey year, yearly

* Step 5: Calculate consecutive underperformance duration
by gvkey: gen top_duration = top10_dum if _n == 1  // Initialize
by gvkey: replace top_duration = ///
    cond(top10_dum == 1,            ///
         cond(!missing(top_duration[_n-1]), top_duration[_n-1] + 1, 1), 0) ///
    if _n > 1 & !missing(top10_dum)
	
by gvkey: gen half_duration = top50_dum if _n == 1  // Initialize
by gvkey: replace half_duration = ///
    cond(top50_dum == 1,            ///
         cond(!missing(half_duration[_n-1]), half_duration[_n-1] + 1, 1), 0) ///
    if _n > 1 & !missing(top50_dum)

winsor2 laggard ,cuts(1 99) replace	

gen ln_under=ln(1+under_duration)	
gen ln_under1=ln(1+under_duration1)
gen under_4plus = under_duration>=4

by

sort gvkey year

by gvkey:gen pressure1=l.ni<0
by 


sum per_sri
gen per_sri_c = per_sri - r(mean)


gen pollutive_industry = 0
destring sic_2,replace

replace pollutive_industry = 1 if inrange(sic_2,10,14) | inrange(sic_2,20,39) | inrange(sic_2,40,49) 
replace pollutive_industry = 1 if culpa==1


save final_sep,replace









