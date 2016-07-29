/* this is C_S data, so every merge shld lag 1 
maybe get an average of previous 3 months?
2016/7/21
year is from ym(which is 2 month before repdt), so shld use repdt4 year!
newdata: vol_earning, skew, ivol_unr, ivol_res
*/
cd H:\crash\
cd .\log
cap log close
log using anc.txt,t append

cd ..\input
/*
preserve
use anc,clear //only annual report
winsor2 car1_1 car5_1 runup_1 markup_1,replace
logout, save(stat)  excel replace:tabstat car1_1 car5_1 runup_1 markup_1 ,stat(n mean sd min max)
*/

use anc_full,clear

/*duplicates rep stkcd repdt4,g(dup)
gen mdate = mofd(ym)
format mdate %tm
format date %td
*/
encode stkcd, gen(id)
encode indcd, gen(ind)
*replace year=year(repdt4)
g qq=qofd(repdt4)-1
format qq %tq
*g qtr=quarter(dofq(qq-1))
replace year=year(repdt4)-1 //yofd(dofq(qq-1)), year is FY previously, so shldn't use previous qtr
*br year qtr repdt4
g report_year=year(repdt4)-1
/*above qtr year is 1 qtr before the repdt, so it's right to merge with year and qtrly data
preserve 
use E:\data\insti_hlding\inst_hld,clear
g qq=yq(year, qtr)
save,replace
restore
*/
merge m:1 stkcd qq using E:\data\insti_hlding\inst_hld,keepusing( stkcd qq TotInsHoldper TotInsHoldperA TotInsHoldperURA) nogenerate  keep(match master)


merge m:1 stkcd year using soe,nogenerate  keep(match master)

merge m:1 stkcd report_year using anal_yr,nogenerate  keep(match master)
replace coverage=0 if coverage==. 
g overperform=1 if eps>avgforecast & avgforecast !=.
replace overperform=0 if eps<=avgforecast & avgforecast !=.


*Define those w/o questions, or at least define a dummy
g noq=num_user_p5w==0
g nox=num_user_xq==0
/*ta noq
ta nox year
replace co_p_r=0 if co_p_r==.
*/
//don't need winsor original value like co*
 winsor2 beta syn amihud tot_vol idrisk_std pricedelay skew ivol_unr ivol_res, replace
//sum co_*  beta syn amihud tot_vol idrisk_std pricedelay


/*g amihud=amihud*1000
replace amihud_led=amihud_led*1000
*/
rename  co_p5w co_p
*g lnbm=ln(bm)
*bm shld use dynamic monthly!
g bm_month=equity/(size*10^3)
drop if bm_month<0

egen co_mean=mean(co_p)
g co_demean=co_p-co_mean
*since co_mean can be 0,so use substract 
g lnco=ln(co_p+1)
g dist_stk_p=ln(dist_stk_p5w+1)
g lnuser_p=ln(num_user_p5w+1)

cumul(co_p), gen(co_rank) equal
//bys mdate: cumul(co_xq), gen(co_rank_x) equal
g single_p=num_user_p5w-co_p
sum single_p
//g single_p_r=1-co_p_r
cumul(single_p), gen(single_rank) equal
cumul(co_xq), gen(co_x_rank) equal


gl control   turnover lnsize bm_month TotInsHoldper ret ret_6  coverage 
gl beta beta syn amihud pricedelay tot_vol idrisk_std skew
global less $control ,  absorb(ind year) //cluster(year) 
global full noq dist_stk_p $control , absorb(ind year) //cluster(year)  
gl option_noctrl p not obs b(a2)  stats(r2 F N, labels(R2 F "No. of obs")) legend varlabels(_cons Constant) star(* 0.10 ** 0.05 *** 0.01)  
gl option p not obs b(a2) drop($control ) stats(r2 F N, labels(R2 F "No. of obs")) legend varlabels(_cons Constant) star(* 0.10 ** 0.05 *** 0.01)  
gl outregopt merge drop($control )  addrows(""\"Clusters","Time"\"Fixed Effect","Time and Firm"\"Control","Yes")  landscape plain coljust(lc)  sdec(3)  stats(b p) starlevels(10 5 1) starloc(1) nolegend blankrows     nocons nodisplay sq

gl car  car1_1 car5_1 runup_1 markup_1 caraft_1 carbef_1
winsor2 $control $car, trim //shld not replace


cd ..\output
gl cop co_rank co_p_r lnco lnuser_p
//gl car car1_0 car1_1 car1_2 car5_0 car5_1 car5_2 runup_0 runup_1 runup_2 markup_0 markup_1 markup_2
eststo clear
foreach a of varlist $car {
qui eststo: reghdfe `a'  noq##soe ,  absorb(ind year) 
foreach b of varlist $cop {
qui eststo: reghdfe `a'  `b' ,  absorb(ind year) 
qui eststo: reghdfe `a'  c.`b'##1.soe soe ,  absorb(ind year) 
}
}
esttab using anc.csv , $option_noctrl  replace

eststo clear
foreach a of varlist $car {
qui eststo: reghdfe `a'  noq##soe $less
}
esttab using anc.csv , $option append
*********************get annual report only, winsored already
preserve
keep if month(repdt4)<6
eststo clear
foreach b of varlist $cop {
foreach a of varlist $car {
qui eststo: reghdfe `a'  `b'   $less
qui eststo: reghdfe `a' `b'   $full
qui eststo: reghdfe `a' `b'  aveforecasterror dispersionforecast overperform  $full
}
}
esttab using anc.csv , $option  append


logout, save(stat)  excel replace:tabstat $car ,stat(n mean sd min max)
***for firms with analyst coverage
reg  beta co_p_r $full
