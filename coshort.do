cd H:\coshort

use "H:\coshort\coshort.dta",clear

merge 1:1 stkcd year month using H:\coshort\control,keep(match master) nogen
encode stkcd,g(id)
gen time=ym(year,month)
g lnsize=ln(size)
xtset id time
winsor2 co_rank co_demean lnco short_cor long_cor short_beta long_beta co_p co_x lnsize mretwd turnover lev bm,replace
bys id: g cshort_led=short_cor[_n+1]
bys id: g clong_led=long_cor[_n+1]
bys id: g bshort_led=short_beta[_n+1]
bys id: g blong_led=long_beta[_n+1]
bys id: g cop_led=co_p[_n+1]
bys id: g cox_led=co_x[_n+1]
bys id: g ret_led=mretwd[_n+1]
bys time: egen co_mean=mean(co_p)
*since co_mean can be 0,so use substract 
g co_demean=co_p-co_mean
g lnco=ln(co_p+1)
by time: cumul(co_p), gen(co_rank) equal
sort id time

sort id time

save coshort1
*****************************************************
xtreg short co_p co_x
xtreg short co_p co_x,fe
xtreg short co_p co_x i.time,fe
xtfmb short_cor co_p co_x
xtfmb bshort_led co_x,lag(4)
xtfmb short blogger_p


eststo clear
preserve 
keep if p==1
qui eststo: xtfmb cshort_led  lnco lnsize mretwd turnover lev bm
qui eststo: xtfmb bshort_led  lnco lnsize mretwd turnover lev bm
qui eststo: xtfmb clong_led  lnco lnsize mretwd turnover lev bm
qui eststo: xtfmb blong_led  lnco lnsize mretwd turnover lev bm

qui eststo: xtreg cshort_led  lnco lnsize mretwd turnover lev bm i.time,fe vce(cluster id)
qui eststo: xtreg bshort_led  lnco lnsize mretwd turnover lev bm i.time,fe vce(cluster id)
qui eststo: xtreg clong_led  lnco lnsize mretwd turnover lev bm i.time,fe vce(cluster id)
qui eststo: xtreg blong_led  lnco lnsize mretwd turnover lev bm i.time,fe vce(cluster id)
**************drop time FE
*eststo clear
qui eststo: xtreg cshort_led lnco lnsize mretwd turnover lev bm,fe vce(cluster id)
qui eststo: xtreg clong_led lnco lnsize mretwd turnover lev bm,fe vce(cluster id)
qui eststo: xtfmb ret_led lnco lnsize mretwd turnover lev bm
esttab using coshort.csv , p not obs b(a2) stats(r2 F N, labels(R2 F "No. of obs")) legend varlabels(_cons Constant) star(* 0.10 ** 0.05 *** 0.01)  replace

****************co_x
qui eststo: xtfmb cshort_led co_x lnsize mretwd turnover lev bm
qui eststo: xtfmb bshort_led co_x lnsize mretwd turnover lev bm
qui eststo: xtfmb clong_led co_x lnsize mretwd turnover lev bm
qui eststo: xtfmb blong_led co_x lnsize mretwd turnover lev bm
xtfmb cshort_led co_p co_x lnsize mretwd turnover lev bm

xtfmb long_led co_p co_x lnsize mretwd turnover lev bm if year>2011

xtfmb long_led co_p co_x

xtreg short_led co_p lnsize mretwd turnover lev bm i.time,fe









preserve 
keep if p==1
eststo clear
foreach i of varlist co_rank co_demean lnco {
qui eststo: xtfmb cshort_led  `i' lnsize mretwd turnover lev bm
qui eststo: xtfmb clong_led  `i' lnsize mretwd turnover lev bm

qui eststo: xtreg cshort_led  `i' lnsize mretwd turnover lev bm i.time,fe vce(cluster id)
qui eststo: xtreg clong_led  `i' lnsize mretwd turnover lev bm i.time,fe vce(cluster id)
**************drop time FE
*eststo clear
qui eststo: xtreg cshort_led `i' lnsize mretwd turnover lev bm,fe vce(cluster id)
qui eststo: xtreg clong_led `i' lnsize mretwd turnover lev bm,fe vce(cluster id)
qui eststo: xtfmb ret_led `i' lnsize mretwd turnover lev bm
}
esttab using coshort.csv , p not obs b(a2) stats(r2 F N, labels(R2 F "No. of obs")) legend varlabels(_cons Constant) star(* 0.10 ** 0.05 *** 0.01)  replace
logout, save(summary) word replace:tabstat short_cor long_co short_beta long_beta co_rank co_demean lnco, stat(n mean min p5 p25 p50 p75 p95 max)
