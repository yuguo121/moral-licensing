* =============================================================================
* 【早期版本】来源项目：Corporate ESG and EM
* 现位置：Moral Lisensing/code/legacy_corporate_esg_em/
* 说明：保留作历史对照；路径与变量名可能仍为旧项目设定，运行前请自行核对。
* 主线分析请使用：code/Master_Analysis.do 或 Master_Analysis_v2.do 等。
* 迁入日期：2026-04-01
* =============================================================================
/*
thie do file is to compute discretionary accruals (DA)
the challenge here is variety of the measurement of DA 
with different measures for dependent variable, the robustness is in doubt if the results are not consistent
so making sure of a right way to compute this var is important
*/

cd "C:\Users\HuGoL\OneDrive - HKUST (Guangzhou)\Data"

use "E:\empirical_study\data_raw\cmm_raw.dta",clear


*****ff48*****
gen sic_num=sic

gen industry = ""
replace industry = "1 Agric" if sic_num >= 0100 & sic_num <= 0199 | sic_num >= 0700 & sic_num <= 0799 | ///
                 sic_num >= 0910 & sic_num <= 0919 | sic_num == 2048
replace industry = "2 Food" if sic_num >= 2000 & sic_num <= 2099
replace industry = "3 Soda" if sic_num >= 2064 & sic_num <= 2068 | sic_num == 2086 | ///
                 sic_num == 2087 | sic_num == 2096 | sic_num == 2097
replace industry = "4 Beer" if sic_num == 2080 | sic_num == 2082 | sic_num == 2083 | ///
                 sic_num == 2084 | sic_num == 2085
replace industry = "5 Smoke" if sic_num >= 2100 & sic_num <= 2199
replace industry = "6 Toys" if sic_num >= 0920 & sic_num <= 0999 | sic_num >= 3650 & sic_num <= 3651 | ///
                 sic_num == 3652 | sic_num == 3732 | sic_num >= 3930 & sic_num <= 3931 | ///
                 sic_num >= 3940 & sic_num <= 3949
replace industry = "7 Fun" if sic_num >= 7800 & sic_num <= 7829 | sic_num >= 7830 & sic_num <= 7833 | ///
                 sic_num >= 7840 & sic_num <= 7841 | sic_num == 7900 | sic_num >= 7910 & sic_num <= 7911 | ///
                 sic_num >= 7920 & sic_num <= 7929 | sic_num >= 7930 & sic_num <= 7933 | ///
                 sic_num >= 7940 & sic_num <= 7949 | sic_num == 7980 | sic_num >= 7990 & sic_num <= 7999
replace industry = "8 Books" if sic_num >= 2700 & sic_num <= 2799
replace industry = "9 Hshld" if sic_num == 2047 | sic_num >= 2391 & sic_num <= 2392 | ///
                 sic_num >= 2510 & sic_num <= 2519 | sic_num >= 2590 & sic_num <= 2599 | ///
                 sic_num >= 2840 & sic_num <= 2843 | sic_num == 2844 | sic_num >= 3160 & sic_num <= 3161 | ///
                 sic_num >= 3170 & sic_num <= 3171 | sic_num == 3172 | sic_num >= 3190 & sic_num <= 3199 | ///
                 sic_num == 3229 | sic_num >= 3260 & sic_num <= 3269 | sic_num >= 3230 & sic_num <= 3231 | ///
                 sic_num >= 3630 & sic_num <= 3639 | sic_num >= 3750 & sic_num <= 3751 | sic_num == 3800 | ///
                 sic_num >= 3860 & sic_num <= 3861 | sic_num >= 3870 & sic_num <= 3873 | sic_num >= 3910 & sic_num <= 3911 | ///
                 sic_num == 3914 | sic_num == 3915 | sic_num >= 3960 & sic_num <= 3962 | sic_num == 3991 | sic_num == 3995
replace industry = "10 Clths" if sic_num >= 2300 & sic_num <= 2390 | sic_num >= 3020 & sic_num <= 3021 | ///
                 sic_num >= 3100 & sic_num <= 3111 | sic_num >= 3130 & sic_num <= 3131 | ///
                 sic_num >= 3140 & sic_num <= 3149 | sic_num >= 3150 & sic_num <= 3151 | ///
                 sic_num >= 3963 & sic_num <= 3965
replace industry = "11 Hlth" if sic_num >= 8000 & sic_num <= 8099
replace industry = "12 MedEq" if sic_num == 3693 | sic_num >= 3840 & sic_num <= 3849 | ///
                 sic_num >= 3850 & sic_num <= 3851
replace industry = "13 Drugs" if sic_num == 2830 | sic_num == 2831 | sic_num == 2833 | ///
                 sic_num == 2834 | sic_num == 2835 | sic_num == 2836
replace industry = "14 Chems" if sic_num >= 2800 & sic_num <= 2899
replace industry = "15 Rubbr" if sic_num >= 3031 & sic_num <= 3099
replace industry = "16 Txtls" if sic_num >= 2200 & sic_num <= 2299
replace industry = "17 BldMt" if sic_num >= 0800 & sic_num <= 0899 | sic_num >= 2400 & sic_num <= 2499 | ///
                 sic_num >= 3420 & sic_num <= 3499
replace industry = "18 Cnstr" if sic_num >= 1500 & sic_num <= 1799
replace industry = "19 Steel" if sic_num >= 3300 & sic_num <= 3399
replace industry = "20 FabPr" if sic_num >= 3400 & sic_num <= 3479
replace industry = "21 Mach" if sic_num >= 3510 & sic_num <= 3599
replace industry = "22 ElcEq" if sic_num >= 3600 & sic_num <= 3699
replace industry = "23 Autos" if sic_num >= 2296 & sic_num <= 2396 | sic_num >= 3010 & sic_num <= 3799
replace industry = "24 Aero" if sic_num >= 3720 & sic_num <= 3729
replace industry = "25 Ships" if sic_num >= 3730 & sic_num <= 3743
replace industry = "26 Guns" if sic_num >= 3760 & sic_num <= 3769 | sic_num == 3795 | ///
                 sic_num >= 3480 & sic_num <= 3489
replace industry = "27 Gold" if sic_num >= 1040 & sic_num <= 1049
replace industry = "28 Mines" if sic_num >= 1000 & sic_num <= 1499
replace industry = "29 Coal" if sic_num >= 1200 & sic_num <= 1299
replace industry = "30 Oil" if sic_num >= 1300 & sic_num <= 1399 | sic_num >= 2900 & sic_num <= 2999
replace industry = "31 Util" if sic_num >= 4900 & sic_num <= 4949
replace industry = "32 Telcm" if sic_num >= 4800 & sic_num <= 4899
replace industry = "33 PerSv" if sic_num >= 7020 & sic_num <= 7699
replace industry = "34 BusSv" if sic_num >= 2750 & sic_num <= 4229
replace industry = "35 Comps" if sic_num >= 3570 & sic_num <= 3695 | sic_num == 7373
replace industry = "36 Chips" if sic_num >= 3622 & sic_num <= 3812
replace industry = "37 LabEq" if sic_num >= 3811 & sic_num <= 3839
replace industry = "38 Paper" if sic_num >= 2520 & sic_num <= 3955
replace industry = "39 Boxes" if sic_num >= 2440 & sic_num <= 3412
replace industry = "40 Trans" if sic_num >= 4000 & sic_num <= 4789
replace industry = "41 Whlsl" if sic_num >= 5000 & sic_num <= 5199
replace industry = "42 Rtail" if sic_num >= 5200 & sic_num <= 5999
replace industry = "43 Meals" if sic_num >= 5800 & sic_num <= 7399
replace industry = "44 Banks" if sic_num >= 6000 & sic_num <= 6199
replace industry = "45 Insur" if sic_num >= 6300 & sic_num <= 6411
replace industry = "46 RlEst" if sic_num >= 6500 & sic_num <= 6611
replace industry = "47 Fin" if sic_num >= 6200 & sic_num <= 6799
replace industry = "48 Other" if sic_num >= 4950 & sic_num <= 4991
replace industry = "48 Other" if industry == ""
ren industry ff48

*****drop missing obs*****
//exclude companies from the financial (SIC 6000–6999) and utility (SIC 4910–4939) industries. questionable for the later coding method
drop if sic >= 6000 & sic <=6999
// drop if sic >= 4910 & sic <=3939
drop if linkprim == "N" | linkprim == "J"
drop if missing(sale)
drop if missing(at)
drop if missing(oancf)
drop if missing(ni)

gen cusip_8=substr(cusip,1,8)
encode cusip_8,gen(cusip_x)

*****firm level var*****
gen lev = (dltt + dlc) / at
gen cash_holding = che / at
gen size = ln(at)
gen roa = ni/at

gen mb1 = (prcc_f * csho)/ceq  //one of many

* 1) 先算 SHE — 逐层 fallback
gen double she = .
replace she = seq                               if !missing(seq)
replace she = ceq + pstk                        if missing(she) & !missing(ceq,pstk)
replace she = at - lt - mib                     if missing(she) & !missing(at,lt)

* 2) 再算优先股价值（按赎回、清算、账面顺序）
gen double ps = cond(!missing(pstkrv), pstkrv, ///
                cond(!missing(pstkl),  pstkl,  ///
                cond(!missing(pstk),   pstk,   0)))

* 3) 最后得到账面权益
gen double be = she - ps
gen mb2= (prcc_f * csho) / be


gen mv = prcc_f * csho
// firms with a market value of less than $10 million;
drop if mv<20 // 10 in yu's
tostring(sic),replace
gen sic_2=substr(sic,1,2)
encode cusip, gen(cusip_n)

*****modified jones*****
xtset cusip_n fyear
sort cusip_n fyear

by cusip_n:gen dss_ta=d.act-d.lct-d.che+d.dlc
by cusip_n:gen ko_ta=d.act-d.lct-d.che+d.dlc-dp
by cusip_n:gen yu_ta = ni - oancf
by cusip_n:gen ge_ta = ibc - oancf

by cusip_n:gen dv_ta_dss = dss_ta / l.at
by cusip_n:gen dv_ta_ko = ko_ta / l.at
by cusip_n:gen dv_ta_yu = yu_ta / l.at
by cusip_n:gen dv_ta_ge = ge_ta / l.at

by cusip_n:gen iv_1 = 1 / l.at
by cusip_n:gen iv_2 = d.sale / l.at
by cusip_n:gen iv_22 = (d.sale - d.rect) / l.at
by cusip_n:gen iv_3 = ppegt / l.at

bysort sic_2 fyear:gen count = _N
keep if count >= 15 



//I estimate the cross sectional models separately for each combination of calendar year and two-digit SIC code with a minimum of 15 observations.   

bys fyear sic_2: asreg dv_ta_dss iv_1 iv_2 iv_3
gen non_ac = _b_iv_1*iv_1 + _b_iv_2*iv_22 + _b_iv_3*iv_3 +_b_cons
gen dss_da_sic = dv_ta_dss - non_ac
drop _Nobs _R2 _adjR2 _b_iv_1 _b_iv_2 _b_iv_3 _b_cons non_ac

bys fyear sic_2: asreg dv_ta_ko iv_1 iv_2 iv_3
gen non_ac = _b_iv_1*iv_1 + _b_iv_2*iv_22 + _b_iv_3*iv_3 +_b_cons
gen ko_da_sic = dv_ta_ko - non_ac
drop _Nobs _R2 _adjR2 _b_iv_1 _b_iv_2 _b_iv_3 _b_cons non_ac

bys fyear sic_2: asreg dv_ta_yu iv_1 iv_2 iv_3
gen non_ac = _b_iv_1*iv_1 + _b_iv_2*iv_22 + _b_iv_3*iv_3 +_b_cons
gen yu_da_sic = dv_ta_yu - non_ac
drop _Nobs _R2 _adjR2 _b_iv_1 _b_iv_2 _b_iv_3 _b_cons non_ac

bys fyear sic_2: asreg dv_ta_ge iv_1 iv_2 iv_3
gen non_ac = _b_iv_1*iv_1 + _b_iv_2*iv_22 + _b_iv_3*iv_3 +_b_cons
gen ge_da_sic = dv_ta_ge - non_ac
drop _Nobs _R2 _adjR2 _b_iv_1 _b_iv_2 _b_iv_3 _b_cons non_ac

bys fyear ff48: asreg dv_ta_dss iv_1 iv_2 iv_3
gen non_ac = _b_iv_1*iv_1 + _b_iv_2*iv_22 + _b_iv_3*iv_3 +_b_cons
gen dss_da_ff = dv_ta_dss - non_ac
drop _Nobs _R2 _adjR2 _b_iv_1 _b_iv_2 _b_iv_3 _b_cons non_ac

bys fyear ff48: asreg dv_ta_ko iv_1 iv_2 iv_3
gen non_ac = _b_iv_1*iv_1 + _b_iv_2*iv_22 + _b_iv_3*iv_3 +_b_cons
gen ko_da_ff = dv_ta_ko - non_ac
drop _Nobs _R2 _adjR2 _b_iv_1 _b_iv_2 _b_iv_3 _b_cons non_ac

bys fyear ff48: asreg dv_ta_yu iv_1 iv_2 iv_3
gen non_ac = _b_iv_1*iv_1 + _b_iv_2*iv_22 + _b_iv_3*iv_3 +_b_cons
gen yu_da_ff = dv_ta_yu - non_ac
drop _Nobs _R2 _adjR2 _b_iv_1 _b_iv_2 _b_iv_3 _b_cons non_ac

bys fyear ff48: asreg dv_ta_ge iv_1 iv_2 iv_3
gen non_ac = _b_iv_1*iv_1 + _b_iv_2*iv_22 + _b_iv_3*iv_3 +_b_cons
gen ge_da_ff = dv_ta_ge - non_ac
drop _Nobs _R2 _adjR2 _b_iv_1 _b_iv_2 _b_iv_3 _b_cons non_ac




save dv_em_aug, replace










