/* this is monthly data, no xueqiu data yet
2016/7/7
data has lots of dup
*/
cd H:\crash\
cd .\log
cap log close
log using 0710.txt,t append
cd ..\       
cd .\input
use coblog,clear
duplicates rep stkcd ym,g(dup)
encode stkcd, gen(id)
gen mdate = mofd(ym)
format mdate %tm
xtset id mdate
replace year=year(ym)
g qtr=quarter(ym)
format date %td
*br year* qtr* date mdate
*use 09 stock to exclude newly listed effect
g bef_10=(year<2010)
bys  id: egen _tmp1=sum(bef_10)
g _tmp2=substr(stkcd,1,1) 
keep if _tmp1>1  & _tmp2 !="2" & _tmp2 !="9" 
drop _tmp1 _tmp2 
keep if year>2009
merge m:1 stkcd year qtr using E:\data\insti_hlding\inst_hld,keepusing( stkcd year qtr TotInsHoldper TotInsHoldperA TotInsHoldperURA) nogenerate  keep(match master)

merge m:1 stkcd year using "F:\work\Fiscal\soe_new",nogenerate  keep(match master)
egen soe_static=max(soe_holder),by( id)
*some are missing

*need analyst dispersion for vol
*merge 1:1 stkcd year using "F:\work\Fiscal\analyst",nogenerate  keep(match master)
g report_year=year-1
merge m:1 stkcd report_year using anal_yr,nogenerate  keep(match master)
replace coverage=0 if coverage==. 
*Define those w/o questions, or at least define a dummy
g noq=co_p_r==.
ta noq coblog
//replace co_p_r=0 if co_p_r==.

//don't need winsor original value like co*
 winsor2 beta syn amihud tot_vol idrisk_std pricedelay, replace
sum co_*,d

cd ../output
loc var co_p_r  //co_x_r
preserve
collapse (mean) avg=`var' (median) med=`var', by( mdate)
tsset mdate
twoway (tsline avg, yaxis(1)) (tsline med, yaxis(2)), name(factors, replace) ///
tlabel(,angle(forty_five) format(%tm)) xtitle("`var' if replace missing with 0")
graph export "TS_`var'1.pdf", as(pdf) 

preserve
collapse (mean) beta=beta syn=syn amihud=amihud if year>2009, by( mdate)
tsset mdate
twoway (tsline amihud, yaxis(1)) (tsline beta, yaxis(2)) (tsline syn, yaxis(2)), name(factors, replace) ///
tlabel(,angle(forty_five) format(%tm)) xtitle("`var'")
graph export "TS_y.pdf", as(pdf) 

preserve
collapse (mean) tot_vol=tot_vol tot_vol_mv=tot_vol_mv idrisk_std=idrisk_std if year>2009, by( mdate)
tsset mdate
twoway (tsline idrisk_std, yaxis(1)) (tsline tot_vol_mv, yaxis(2)) (tsline tot_vol , yaxis(2)), name(factors, replace) ///
tlabel(,angle(forty_five) format(%tm)) xtitle("average Volatility")
graph export "TS_vol.pdf", as(pdf) 

*g lnbm=ln(bm)
*bm shld use dynamic monthly!
g lmkt=l.mktret

bys mdate: egen co_mean=mean(co_num)
*since co_mean can be 0,so use substract 
sort id mdate
g co_demean=co_num-co_mean
g lnco=ln(co_p+1)

g lnnum_blogger=ln(num_blogger+1)

by mdate: cumul(co_p), gen(co_rank) equal
******************g google&law dummy***
g google=(date>mdy(6,1,2014))
g wechat=(date>mdy(8,1,2013))
g placebo=(date>mdy(1,1,2015))
g

use H:\crash\qtr_crash_0311.dta
use H:\crash\qtr_crash_ss.dta,clear //this has miss_x

drop _merge
merge 1:1 stkcd year month using input\amihud, keep(match using) 
drop _TYPE_

mkdir output


replace syn_lead=-syn_lead
replace syn=-syn
*Olympics 2012-8
g olympic=(mdate==ym(2012,8))
g summer=(month<9 & month>6)) 
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

