* =============================================================================
* 【早期版本】来源项目：Corporate ESG and EM
* 现位置：Moral Lisensing/code/legacy_corporate_esg_em/
* 说明：保留作历史对照；路径与变量名可能仍为旧项目设定，运行前请自行核对。
* 主线分析请使用：code/Master_Analysis.do 或 Master_Analysis_v2.do 等。
* 迁入日期：2026-04-01
* =============================================================================
cd "C:\Users\HuGoL\OneDrive - HKUST (Guangzhou)\Data"
log using Mar25, append smcl


use dv_em_aug,clear
gen year = fyear


merge 1:1 cusip_8 fyear using "E:\empirical_study\data_raw\crsp_merged_final_zhangyue.dta",nogen keep(1 3 4 5) keepusing(env_* com_* hum_* emp_* div_* pro_* cgov_* alc_* gam_* mil_* nuc_* tob_* kld_* v_* vs_* bod_*) update

merge 1:1 cusip_8 fyear using "E:\empirical_study\data_raw\io.dta", keepus(per_*) keep(1 3) nogen

merge 1:1 cusip_8 year using "E:\empirical_study\data_raw\firm_compensation_flammer.dta",nogen keep(1 3) 

merge 1:1 year cusip_8 using asset4_independence,keep(1 3) nogen 

merge 1:1 cusip_8 year using "E:\empirical_study\data_raw\refinitiv_csr_compensation.dta",nogen keep(1 3) 

merge 1:1 cusip_8 year using culpability_kld, keep(1 3) keepusing(culpa) nogen
merge 1:1 cusip_8 year using msci_aug, keep(1 3)  nogen

merge 1:n cusip_8 year using "E:\empirical_study\data_raw\ceo_compensation.dta",nogen keep(1 3)


drop emp

gen emp= emp_str_num1 -emp_con_num1
gen env= env_str_num1 -env_con_num1

gen kld = env_str_num1 - env_con_num1 + com_str_num1 - com_con_num1 + hum_str_num1 - hum_con_num1 + emp_str_num1 - emp_con_num1 + div_str_num1 - div_con_num1 + pro_str_num1 - pro_con_num1 + cgov_str_num1 - cgov_con_num1
gen kldnocg = env_str_num1 - env_con_num1 + com_str_num1 - com_con_num1 + hum_str_num1 - hum_con_num1 + emp_str_num1 - emp_con_num1 + div_str_num1 - div_con_num1 + pro_str_num1 - pro_con_num1 

gen flammer_str = env_str_num1 + com_str_num1 + emp_str_num1 + pro_str_num1
replace ceo_gender = "1" if ceo_gender=="MALE"
replace ceo_gender = "0" if ceo_gender=="FEMALE"
destring(ceo_gender),replace

sort year sic_2
bys sic_2 year: egen aver_roa=mean(roa)
gen adj_roa = roa - aver_roa


sort cusip_8 year ceo_name 
duplicates drop cusip_8 year,force

xtset cusip_n year
sort cusip_n year

*  mark industry cupability 2024/11/3***********************************************
gen industry_type = 0
* Classify tobacco industries
destring sic,replace
replace industry_type = 1 if inrange(sic, 2100, 2199)
* Classify guns and defense industries
replace industry_type = 1 if inrange(sic, 3760, 3769) | sic == 3795 | inrange(sic, 3480, 3489)
* Classify natural resources industries
replace industry_type = 1 if inrange(sic, 800, 899) | inrange(sic, 1000, 1119) | inrange(sic, 1400, 1499)
* Classify alcohol industries
replace industry_type = 1 if sic == 2080 | inrange(sic, 2082, 2085)
* Check the results
list sic industry_type if industry_type != 0
replace industry_type = 1 if culpa==1
*************************************************************************************



save playboard_aug,replace
