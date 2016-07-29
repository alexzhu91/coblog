/* this is monthly data, no xueqiu data yet
2016/7/5
data has lots of dup
*/
cd F:\work\coblog\
dir
use reg1.dta,clear  //from reg3 there's dup
duplicates rep stkcd year month,g(dup)

use F:\work\coblog\reg5.dta,clear //syn is not right from summary
duplicates tag stkcd year month,g(dup)
br date monret num_blogger if  dup==2
format date %td
br date monret num_blogger if  dup==2


use H:\crash\qtr_crash_0311.dta
use H:\crash\qtr_crash_ss.dta,clear //this has miss_x

cd H:\crash\
drop _merge
merge 1:1 stkcd year month using input\amihud, keep(match using) 
drop _TYPE_

mkdir output
cd .\output
log using 0705.txt,t       


replace syn_lead=-syn_lead
replace syn=-syn
*Olympics 2012-8
g olympic=(mdate==ym(2012,8))
//g summer=(mdate==ym(2013,8)) *this placebo don't work

g p=(_merge==
global fe turnover lnsize lnbm TotInsHoldper mretwd ret6_0  mkt lmkt i.mdate,fe vce(cluster id)
global fe blogger_p1 blogger_x1 book_lev turnover mb , a(id quarter) cluster(id quarter)
global fe turnover lnsize lnbm TotInsHoldper mretwd ret6_0  mkt lmkt , abs(id year month) cluster(id mdate)  //not cluster id is same
gl drop turnover lnsize lnbm TotInsHoldper mretwd ret6_0  mkt lmkt
gl option p not obs b(a2) drop($drop) stats(r2 F N, labels(R2 F "No. of obs")) legend varlabels(_cons Constant) star(* 0.10 ** 0.05 *** 0.01)  
gl outregopt merge addrows(""\"Clusters","Time and Firm"\"Fixed Effect","Time and Firm"\"Control","Yes")  landscape plain coljust(lc)  sdec(3)  stats(b p) starlevels(10 5 1) starloc(1) nolegend blankrows     nocons nodisplay sq

qui eststo: reghdfe qcrash2 miss_x l.(c.co_x1##ss ) $fe

reghdfe beta_lead  co_rank_wechat co_rank wechat $fe 
reghdfe beta_lead   c.co_rank##1.wechat $fe 
outreg,$outregopt

*---------------Which measure is sig after clustering-----------------------------------
preserve
keep  if mdate>600 //&  coblog ==1
fvset base 601 mdate
foreach a of varlist beta {
eststo clear
outreg,clear
foreach i of varlist co_rank co_demean lnco {
qui eststo: reghdfe `a'_lead  `i'  $fe
outreg ,$outregopt
}
outreg using beta,$outregopt
}

*---------------Automatic interaction-----------------------------------

foreach a of varlist beta {
eststo clear
outreg,clear
foreach i of varlist co_rank {
foreach b of varlist wechat google olympic{  
fvset base 0 `b'
qui eststo: reghdfe `a'_lead  `b'##c.`i' $fe 
outreg ,$outregopt
}
outreg using beta,$outregopt
}
}
*---------------Manual interaction-----------------------------------
foreach a of varlist beta {
eststo clear
*outreg,clear
foreach i of varlist co_rank {
foreach b of varlist wechat google olympic summer {  
g `b'_co=`b'*`i'
qui eststo: reghdfe `a'_lead  `b' `i'  `b'_co $fe 
outreg ,$outregopt
drop `b'_co
}
outreg using manual,$outregopt
}
}

********************ordinary esttab
preserve
keep  if mdate>600 //&  coblog ==1
fvset base 601 mdate
foreach a of varlist beta {
eststo clear
foreach i of varlist co_rank co_demean lnco {
qui eststo: reghdfe `a'_lead  `i'  $fe
foreach b of varlist wechat google olympic{  
qui eststo: reghdfe `a'_lead  `b'#c.`i' $fe 
}
}
esttab using beta_fe.csv , $option   replace
}


foreach a of varlist  syn {
eststo clear
foreach i of varlist co_rank co_demean lnco {
foreach b of varlist wechat google olympic{  
qui eststo: reghdfe `a'_lead  c.`i'  $fe
qui eststo: reghdfe `a'_lead  c.`i'##`b' $fe 
}
}
esttab using beta_fe.csv , $option   append
}

