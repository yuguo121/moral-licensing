* =============================================================================
* 【早期版本】来源项目：Corporate ESG and EM
* 现位置：Moral Lisensing/code/legacy_corporate_esg_em/
* 说明：保留作历史对照；路径与变量名可能仍为旧项目设定，运行前请自行核对。
* 主线分析请使用：code/Master_Analysis.do 或 Master_Analysis_v2.do 等。
* 迁入日期：2026-04-01
* =============================================================================
// Set working directory
cd "C:\Users\Yuguo\OneDrive - HKUST (Guangzhou)\Research Project\Corporate ESG and EM"

// Load the dataset
use final_sep, clear

/*
================================================================================
SECTION 1: DATA PREPARATION
================================================================================
*/

// Define control variables (will add lagged DA later)
global ctrl   size mb2 lev roa growth_asset cash_holding ///
              per_io big_4 firm_age ceo_age ceo_gender ///
              ceo_LogCompensation ceo_per_stock ceo_per_cash ///
              duality bod_independence bod_size

// Winsorize controls
winsor2  size mb* roa lev growth_asset cash_holding per_* big_4 firm_age ceo_age ///
         ceo_gender ceo_LogCompensation ceo_per_stock ceo_per_cash duality ///
         bod_independence bod_size, cuts(1 99) replace

// Winsorize vs_3, vs_5 and DA measure
winsor2 ko_da_sic, cuts(1 99) replace


// Firm level 
reghdfe ko_da_sic c.vs_4##i.industry_t size mb2 lev roa growth_asset cash_holding per_io big_4 firm_age duality bod_independence bod_size, absorb(year gvkey) cluster(gvkey)

// add CEO
reghdfe ko_da_sic c.vs_4##i.industry_t size mb2 lev roa growth_asset cash_holding per_io big_4 firm_age duality bod_independence bod_size ceo_age ceo_gender ceo_LogCompensation ceo_per_stock ceo_per_cash, absorb(year gvkey) cluster(gvkey)