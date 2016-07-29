/* this is quarterly data*/
cd H:\crash
use qtr_crash_0311.dta

cap log close
log using .\log\0704,t append


sort id quarter
g crash=qcrash2[_n+1]
gl crash crash
format quarter %tq
global fe , abs(id year qtr) cluster(id quarter)
*reghdfe $crash miss_x c.co_x1##ss ) $fe

**********************use short sell dummy interaction
****************************Firm FE
gl control mb lnsales book_lev roa ret  turnover

eststo clear
qui eststo: reghdfe $crash miss_x c.co_x1##ss blogger_x1 $control $fe
qui eststo: reghdfe $crash miss_x c.co_x1##ss c.blogger_x1##ss $control $fe
esttab using crash_ss0705.csv , p not obs b(a2) stats(r2 F N, labels(R2 F "No. of obs")) legend varlabels(_cons Constant) star(* 0.10 ** 0.05 *** 0.01)  replace

qui eststo: reghdfe $crash miss_p c.co_p1##ss blogger_p1 $control $fe
qui eststo: reghdfe $crash miss_p c.co_p1##ss c.blogger_p1##ss $control $fe

qui eststo: reghdfe $crash miss_p c.tot_ask1##ss  delay1 $control $fe
qui eststo: reghdfe $crash miss_p tot_ask1  c.delay1##ss $control $fe



save H:\crash\qtr_crash_0311.dta

**********************replicate economic letters
g dshort=d.short
g dlong=d.longamt
bys id:g crash_led=$crash[_n+1]
xtfmb crash_led ss dshort  $control 
eststo clear
qui eststo: xtreg f.$crash ss longamt short  $control $fe
qui eststo: xtreg f.$crash ss miss_p co_p1 longamt short  $control $fe
qui eststo: xtreg f.$crash  longamt short  $control i.quarter if ss==1, fe vce(cluster id)
qui eststo: xtreg f.$crash  dshort  $control i.quarter if ss==1, fe vce(cluster id)
qui eststo: xtreg f.$crash  dshort dlong  $control i.quarter if ss==1, fe vce(cluster id)
*same if include ss dummy
xtreg f.$crash ss miss_p  dshort dlong  $control $fe

xtreg f.$crash ss miss_p c.dlong##c.dshort  $control $fe
*cor long*short & short =0.93, so not surprising to find negative interaction
preserve 
keep stkcd year qtr ss longamt short  dshort dlong
save for_ni
esttab using crash_short.csv , p not obs b(a2) stats(r2 F N, labels(R2 F "No. of obs")) legend varlabels(_cons Constant) star(* 0.10 ** 0.05 *** 0.01)  replace
**********************use short sell value data,;can short/long as the only var; split large firms to see, if information is at work, ;
******split delay
sum delay if miss_p==0,d
g asym=(delay>0.96) if miss_p ==0 //median


sort id quarter
gl control mb size book_lev roa ret  turnover
g short_add=(dshort>0)
g short_dec=(dshort<0)
eststo clear
fvset base 192 quarter
********************short add lead to crash?
qui eststo: xtreg f.$crash ss miss_x c.co_x1##short_add c.co_x1##short_dec blogger_x1 $control $fe
qui eststo: xtreg f.$crash ss miss_x c.co_x1##short_add c.co_x1##short_dec c.blogger_x1##short_add c.blogger_x1##short_dec $control $fe

qui eststo: xtreg f.$crash ss miss_p c.co_p1##short_add c.co_p1##short_dec blogger_p1 $control $fe
qui eststo: xtreg f.$crash ss miss_p c.co_p1##short_add c.co_p1##short_dec c.blogger_p1##short_add c.blogger_p1##short_dec $control $fe

qui eststo: xtreg f.$crash ss miss_p c.tot_ask1##short_add c.tot_ask1##short_dec  delay1 $control $fe
qui eststo: xtreg f.$crash ss miss_p tot_ask1  c.delay1##short_add c.delay1##short_dec $control $fe
***********ret copy above
qui eststo: xtreg f.ret ss miss_x c.co_x1##short_add c.co_x1##short_dec blogger_x1 $control $fe
qui eststo: xtreg f.ret ss miss_x c.co_x1##short_add c.co_x1##short_dec c.blogger_x1##short_add c.blogger_x1##short_dec $control $fe

qui eststo: xtreg f.ret ss miss_p c.co_p1##short_add c.co_p1##short_dec blogger_p1 $control $fe
qui eststo: xtreg f.ret ss miss_p c.co_p1##short_add c.co_p1##short_dec c.blogger_p1##short_add c.blogger_p1##short_dec $control $fe

qui eststo: xtreg f.ret ss miss_p c.tot_ask1##short_add c.tot_ask1##short_dec  delay1 $control $fe
qui eststo: xtreg f.ret ss miss_p tot_ask1  c.delay1##short_add c.delay1##short_dec $control $fe
******** longamt or short * co_x & single
qui eststo: xtreg f.$crash ss miss_x c.co_x1##c.short c.single_x1##c.short c.co_p1##c.short c.single_p1##c.short $control $fe
xtreg f.$crash ss miss_p c.co_p1##c.short c.single_p1##c.short $control $fe
xtreg f.$crash ss miss_p  c.blogger_x1##c.short $control $fe
******** short * co_x & co_p together
eststo clear
foreach i of varlist short longamt dshort dlong {
qui eststo: xtreg f.$crash ss miss_p  c.blogger_x1##c.`i' c.blogger_p1##c.`i'  $control $fe
qui eststo: xtreg f.$crash ss miss_p  c.co_x1##c.`i' c.co_p1##c.`i'  $control $fe
qui eststo: xtreg f.$crash ss miss_p  c.single_x1##c.`i' c.single_p1##c.`i'  $control $fe
}
********delay group
preserve
keep if asym==1
qui eststo: xtreg f.qcrash1 ss miss_p  co_x1 co_p1 $control $fe
restore
preserve
keep if asym==0
qui eststo: xtreg f.qcrash1 ss miss_p  co_x1 co_p1  $control $fe

qui eststo: xtreg f.qcrash1 ss miss_p  c.co_x1##asym c.co_p1##asym  $control $fe
qui eststo: xtreg f.qcrash1 ss miss_p  c.blogger_x1##asym c.blogger_p1##asym  $control $fe

xtreg f.$crash ss miss_p  c.dshort##asym c.dlong##asym  $control $fe
eststo clear
preserve
keep if asym==1
qui eststo: xtreg f.$crash ss miss_p  blogger_x1 blogger_p1 $control $fe
foreach i of varlist short longamt dshort dlong {
qui eststo: xtreg f.$crash ss miss_p  c.blogger_x1##c.`i' c.blogger_p1##c.`i'  $control $fe
}
restore
preserve
keep if asym==0
qui eststo: xtreg f.$crash ss miss_p  blogger_x1 blogger_p1 $control $fe
foreach i of varlist short longamt dshort dlong {
qui eststo: xtreg f.$crash ss miss_p  c.blogger_x1##c.`i' c.blogger_p1##c.`i'  $control $fe
}
esttab using delay_group.csv , p not obs b(a2) stats(r2 F N, labels(R2 F "No. of obs")) legend varlabels(_cons Constant) star(* 0.10 ** 0.05 *** 0.01)  replace

qui eststo: xtreg f.$crash ss miss_p  c.co_x1##c.`i' c.co_p1##c.`i'  $control $fe
qui eststo: xtreg f.$crash ss miss_p  c.single_x1##c.`i' c.single_p1##c.`i'  $control $fe


********change in short,can  replace longamt or short
qui eststo: xtreg f.$crash ss miss_x c.co_x1##c.dshort blogger_x1 $control $fe
qui eststo: xtreg f.$crash ss miss_x c.co_x1##c.dshort c.blogger_x1##c.dshort $control $fe

qui eststo: xtreg f.$crash ss miss_p c.co_p1##c.dshort blogger_p1 $control $fe
qui eststo: xtreg f.$crash ss miss_p c.co_p1##c.dshort c.blogger_p1##c.dshort $control $fe

qui eststo: xtreg f.$crash ss miss_p c.tot_ask1##c.dshort  delay1 $control $fe
qui eststo: xtreg f.$crash ss miss_p tot_ask1  c.delay1##c.dshort $control $fe

qui eststo: xtreg f.$crash ss miss_x c.co_x1##c.dlong blogger_x1 $control $fe
qui eststo: xtreg f.$crash ss miss_x c.co_x1##c.dlong c.blogger_x1##c.dlong $control $fe

qui eststo: xtreg f.$crash ss miss_p c.co_p1##c.dlong blogger_p1 $control $fe
qui eststo: xtreg f.$crash ss miss_p c.co_p1##c.dlong c.blogger_p1##c.dlong $control $fe

qui eststo: xtreg f.$crash ss miss_p c.tot_ask1##c.dlong  delay1 $control $fe
qui eststo: xtreg f.$crash ss miss_p tot_ask1  c.delay1##c.dlong $control $fe
*******************************what determines the characters;can analyze concurrent relations
qui eststo: xtreg f.tot_ask1 ss longamt short  $control $fe
qui eststo: xtreg f.blogger_x1 ss longamt short  $control $fe
qui eststo: xtreg f.blogger_p1 ss longamt short  $control $fe
qui eststo: xtreg f.tot_ask1 ss dlong dshort  $control $fe
qui eststo: xtreg f.blogger_x1 ss dlong dshort  $control $fe
qui eststo: xtreg f.blogger_p1 ss dlong dshort  $control $fe
eststo clear

qui eststo: xtreg f.blogger_x1 ss f.dlong f.dshort dlong dshort $control $fe
qui eststo: xtreg f.blogger_p1 ss f.dlong f.dshort dlong dshort  $control $fe
qui eststo: xtreg f.dif_x ss f.dlong f.dshort dlong dshort $control $fe
qui eststo: xtreg f.dif_p ss f.dlong f.dshort dlong dshort  $control $fe

*******************************try bloggerx&p dif
eststo clear
qui eststo: xtreg $crash l.ss miss_p c.co_x1##c.longamt c.co_p1##c.longamt $control $fe
qui eststo: xtreg $crash l.ss miss_p c.blogger_x1##c.longamt c.blogger_p1##c.longamt $control $fe

***is it short actually the size indicator?
g size=ln(mv)
xtreg short l.size ss i.quar,fe

esttab using crash_value.csv , p not obs b(a2) stats(r2 F N, labels(R2 F "No. of obs")) legend varlabels(_cons Constant) star(* 0.10 ** 0.05 *** 0.01)  replace




qui eststo: xtreg qcrash1 miss_p miss_x co_x1 blogger_x1 co_p1 blogger_p1  tot_ask2  delay1 $control $fe
qui eststo: xtreg $crash miss_p miss_x co_x1 blogger_x1 co_p1 blogger_p1 tot_ask2  delay1 $control $fe


eststo clear
qui eststo: xtreg $crash c.co_x1##ss blogger_x1 mb lnsales book_lev roa) i.quarter, fe
qui eststo: xtreg $crash co_x1 c.blogger_x1##ss mb lnsales book_lev roa) i.quarter, fe

qui eststo: xtreg $crash c.co_p1##ss blogger_p1 mb lnsales book_lev roa) i.quarter, fe
qui eststo: xtreg $crash co_p1 c.blogger_p1##ss mb lnsales book_lev roa) i.quarter, fe
