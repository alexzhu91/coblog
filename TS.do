/* try to see the TS of 1 stock, get idea how to detrend
problem is that its variation is very low, and btw month has no autocorrletion
2016/7/23
*/
cd H:\crash\
cd .\log
cap log close
log using ts.txt,t append

cd ..\input
use coblog,clear
g noq=num_user_p5w==0

foreach i of numlist 1/4 {
g rep`i'=(repdt`i'_ ~=.)
}
gen mdate = mofd(ym)
format mdate %tm
encode stkcd, gen(id)
xtset id mdate
g aft_rep=l.rep4

cd ../output
preserve
keep if !noq
keep if stkcd=="002495" 
tsset mdate
winsor2 num_user_p5w,trim
keep if year>2011 //& !rep4 & !rep2 & !aft_rep
twoway (tsline co_p5w num_user_p5w, yaxis(1)) , name(factors, replace) ///
tlabel(,angle(forty_five) format(%tm)) xtitle("Coblog & all blog ")
graph export "TS_singlestock_pattern.pdf", as(pdf) replace
*******************/

use "F:\work\coblog\reg5.dta",clear
cd ../output
preserve
collapse (mean) syn_avg=syn (median) syn_med=syn, by( mdate)
format mdate %tm
tsset mdate
twoway (tsline syn_avg, yaxis(1)) (tsline syn_med, yaxis(2)), name(factors, replace) ///
tlabel(,angle(forty_five) format(%tm)) xtitle("")
graph export "TS_syn.pdf", as(pdf) 

twoway (tsline syn_avg, yaxis(1)) (tsline syn_med, yaxis(2)) if mdate<ym(2011,12), name(factors, replace) ///
tlabel(,angle(forty_five) format(%tm)) xtitle("")
graph export "TS_syn12.pdf", as(pdf) 

*******************/
preserve
collapse (mean) beta_avg=beta (median) beta_med=beta, by( mdate)
format mdate %tm
tsset mdate
twoway (tsline beta_avg, yaxis(1)) (tsline beta_med, yaxis(2)), name(factors, replace) ///
tlabel(,angle(forty_five) format(%tm)) xtitle("")
graph export "TS_beta.pdf", as(pdf) 

preserve
twoway (tsline num) , tlabel(,angle(forty_five) format(%tdCCYY)) xtitle("")
