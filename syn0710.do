/* this is monthly data, no xueqiu data yet
2016/7/7
data has lots of dup
soe is only up to 2013! so data decrease a lot
ta noq year exchg
newdata: vol_earning, skew, ivol_unr, ivol_res
*/
cd H:\crash\
cd .\log
cap log close
log using 0720.txt,t append

cd ..\input
use coblog,clear

sum amihud
duplicates rep stkcd ym,g(dup)
encode stkcd, gen(id)
gen mdate = mofd(ym)
format mdate %tm
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

*latest soe
merge m:1 stkcd year using "H:\crash\input\soe",nogenerate  keep(match master)

//merge m:1 stkcd year using "F:\work\Fiscal\soe_new",nogenerate  keep(match master)
//egen soe_static=max(soe),by( id)
*some are missing

*need analyst dispersion for vol
*merge 1:1 stkcd year using "F:\work\Fiscal\analyst",nogenerate  keep(match master)
g report_year=year-1
merge m:1 stkcd report_year using anal_yr,nogenerate  keep(match master)
replace coverage=0 if coverage==. 
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
rename volume stambough
winsor2 stambough, replace
sum stambough,d
cor stamb amihud
*g lnbm=ln(bm)
*bm shld use dynamic monthly!
g bm_month=equity/(size*10^3)
drop if bm_month<0

bys mdate: egen co_mean=mean(co_p)
g co_demean=co_p-co_mean
*since co_mean can be 0,so use substract 
g lnco=ln(co_p+1)
g dist_stk_p=ln(dist_stk_p5w+1)
g lnuser_p=ln(num_user_p5w+1)

bys mdate: cumul(co_p), gen(co_rank) equal
//bys mdate: cumul(co_xq), gen(co_rank_x) equal
g single_p=num_user_p5w-co_p
sum single_p
//g single_p_r=1-co_p_r
bys mdate: cumul(single_p), gen(single_rank) equal
bys mdate: cumul(co_xq), gen(co_x_rank) equal

sort id mdate
*g lmkt=l.mktret
******************g google&law dummy***
g google=(date>mdy(6,1,2014))
g wechat=(date>mdy(8,1,2013))
******************reporting month generate
/*collapse by month
see any monthly pattern*/
foreach i of numlist 1/4 {
g rep`i'=(repdt`i'_ ~=.)
/* co_rep`i'=co_demean*rep`i'
g co_rank_rep`i'=co_rank*rep`i'
g lnco_rep`i'=lnco*rep`i'
*/
}
*bys id (mdate): g syn_lead=f.syn
egen rep=rowmax(rep1 rep2 rep3 rep4)
foreach i of varlist co_rank co_demean lnco{
g rep_`i'=rep*`i'
}

xtset id mdate
foreach a of varlist ret beta syn amihud tot_vol idrisk_std pricedelay stambough{
g `a'_led=`a'[_n+1]
}


g olympic=(mdate==ym(2012,8))
g fifa=(mdate==ym(2014,6)|mdate==ym(2014,7))
g summer=(month<9 & month>6) 
g lret_6=l.ret_6
//g soe_olym=(soe_static&olympic)

//g soe_olym1=(soe&olympic) this is total wrong, since 13 after soe is missing, so 
g soe_olym1=(soe&olympic)

g soe_fifa=(soe&fifa)

g sh=substr(stkcd,1,1)==6
ta noq year sh

*******************heckman
/*g x=. if lnco==0
replace x=lnco if lnco>0
*/

gl control   turnover lnsize bm_month TotInsHoldper ret lret_6  coverage 
gl full noq dist_stk_p $control 
gl beta beta syn amihud pricedelay tot_vol idrisk_std 
global less $control , abs(id ym) cluster(mdate) 
global fe $full , abs(id ym) cluster(mdate)  //not cluster id is same
gl option p not obs b(a2) drop($control ) stats(r2 F N, labels(R2 F "No. of obs")) legend varlabels(_cons Constant) star(* 0.10 ** 0.05 *** 0.01)  
gl outregopt merge drop($control )  addrows(""\"Clusters","Time"\"Fixed Effect","Time and Firm"\"Control","Yes")  landscape plain coljust(lc)  sdec(3)  stats(b p) starlevels(10 5 1) starloc(1) nolegend blankrows     nocons nodisplay sq

winsor2 $control, replace
//logout, save(stat)  excel replace:tabstat co_rank co_p_r  lnco num* $beta $full ,stat(n mean sd min max)
*******************ERC, for every fiscal year, ret12, and d12.eps
*for rep4, l.ret12 means month 3- next year ret, l12.d12.eps, then collapse, since it's annual
preserve
g lret12=l.ret_12
g deps=d12.eps
g ldeps=l12.deps
g co1=l12.co_rank
 keep if rep4
reg lret12 c.co1##c.deps

*---------------Ret prediction no result with/wo noq-----------------------------------

xtfmb ret_led co_p_r $control if !noq, lag(1)
xtfmb ret_led co_rank $control if !noq, lag(1)
xtfmb ret_led co_rank $control, lag(1)
preserve
keep if year>2011 & !noq
reghdfe ret_led lnco $fe
reghdfe ret_led co_p_r $fe //no

reghdfe ret_led co_rank $fe

//test IVOL puzzle but failed
xtfmb ret_led idrisk_std amihud , lag(3)


xtfmb ret_led co_rank $control if !noq, lag(1)
xtfmb ret_led   syn amihud pricedelay  $control, lag(3) //failed, since mdate is not regular
xtfmb ret_led lnuser_p $control, lag(1)
xtfmb ret_led lnuser_p  turnover lnsize bm_month TotInsHoldper lret_6  coverage , lag(3)
xtfmb ret_led ans_ask lndelay  turnover lnsize bm_month TotInsHoldper lret_6  coverage , lag(3)

xtfmb ret_led co_x_r  $control, lag(1)

*--------------#user decompose into single vs co_p, mainly coblog at work -----------------------------------
  reghdfe amihud_led amihud lnuser_p noq $less
  reghdfe amihud_led amihud co_rank single_rank  noq $less
  **w/o noq
reghdfe amihud_led amihud co_rank  $less
reghdfe amihud_led amihud co_p_r  $less
reghdfe amihud_led amihud noq  $less
reghdfe amihud_led amihud co_p_rr noq  $less
preserve
keep if year>2013
reghdfe amihud_led co_x_rank  $less
reghdfe amihud_led nox  $less
reghdfe amihud_led co_x_rank  nox $less
reghdfe amihud_led amihud co_x_r nox $less
//prove the illiquid paper
reghdfe syn_led amihud  noq $less
// IVOL is positively related to disclosure quality , means it measure info, so less risky, less return , but no result
reghdfe  idrisk_std_led noq $less
reghdfe  idrisk_std_led num_ans $less
g lndelay=ln(1+delay)
reghdfe  idrisk_std_led ans_rate ans_ask lndelay $less //negat, delay is skewed, so shld ln
 
 reghdfe beta_led beta co_p_r $full, abs(id ym) cluster(mdate) //drop beta won't help
*---------------Which measure is sig after clustering, stambough no result-----------------------------------
cd ..\output
preserve
*keep  if mdate>600 //&  coblog ==1
outreg,clear
eststo clear
foreach a of varlist $beta {
foreach i of varlist co_rank co_p_r {
qui eststo: reghdfe `a'_led `a' `i'  $fe
outreg ,$outregopt
}
}
outreg using beta,$outregopt

*---------------Baseline-----------------------------------
eststo clear
gl beta beta syn amihud pricedelay tot_vol idrisk_std 
foreach a of varlist $beta {
foreach i of varlist lnuser_p single_rank ans_ask lndelay{
qui eststo: reghdfe `a'_led `i' $fe 
qui eststo: reghdfe `a'_led `a' `i' $fe 
}
}
esttab using base.csv , $option   replace

*---------------Automatic interaction-----------------------------------

foreach a of varlist beta {
eststo clear
outreg,clear
foreach i of varlist co_rank {
foreach b of varlist wechat google olympic{  
fvset base 0 `b'
qui eststo: reghdfe `a'_led  `b'##c.`i' $fe 
outreg ,$outregopt
}
outreg using beta,$outregopt
}
}

*---------------Manual interaction-----------------------------------
eststo clear
gl beta beta syn amihud pricedelay tot_vol //idrisk_std 
foreach a of varlist $beta {
foreach i of varlist co_rank co_p_r lnco {
qui eststo: reghdfe `a'_led `a' `i' $fe 
foreach b of varlist olympic summer {  
cap drop `b'_co
g `b'_co=`b'*`i'
qui eststo: reghdfe `a'_led `a' `b' `i'  `b'_co $fe 
}
qui eststo: reghdfe `a'_led `a' `i'  summer_co summer olympic olympic_co $fe 
}
}
esttab using summer.csv , $option   replace

 reghdfe amihud_led amihud c.co_rank##olympic  $full, abs(id ym) cluster(mdate)
 reghdfe amihud_led amihud c.co_rank##summer  $full, abs(id ym) cluster(mdate)
/*no AR, comparsion btw two y var*/
eststo clear
gl beta amihud syn
foreach a of varlist $beta {
foreach i of varlist co_rank co_p_r {
foreach b of varlist olympic summer {  
cap drop `b'_co
g `b'_co=`b'*`i'
qui eststo: reghdfe `a'_led  `b' `i'  `b'_co $fe 
}
qui eststo: reghdfe `a'_led `i'  summer_co summer olympic olympic_co $fe 
}
}
esttab using summer.csv , $option   replace

//outreg using manual,$outregopt replace
 reghdfe beta_led beta c.co_rank##soe_olym1 $full, abs(id ym) cluster(mdate)
 reghdfe amihud_led amihud c.co_rank##soe_olym $full, abs(id ym) cluster(mdate)
 reghdfe beta_led beta c.co_rank##soe_fifa $full, abs(id ym) cluster(mdate)

*---------------change to less control, since noq is colinear with co_r-----------------------------------
//soe interact 
preserve
*keep if year>2010
eststo clear
gl  beta  beta amihud  syn pricedelay
foreach a of varlist $beta {
foreach i of varlist co_rank co_p_r lnco{
foreach b of varlist soe_olym1 {  
cap drop `b'_co
g `b'_co=`b'*`i'
qui eststo: reghdfe `a'_led  `b' `i'  `b'_co $less 
qui eststo: reghdfe `a'_led  `b' `i'  `b'_co `a' $less 
}
}
}
esttab using summer.csv , $option   replace
 
 *******************full triple automatic,shld use outreg, not recomend
eststo clear
gl  beta beta amihud syn pricedelay
outreg,clear
foreach a of varlist $beta {
foreach i of varlist co_rank co_p_r lnco{
qui eststo: reghdfe `a'_led  soe##olympic##c.`i' `a' $fe 
outreg ,$outregopt
}
}
outreg using triple,$outregopt replace

 *******************full triple manual
eststo clear
gl  beta beta amihud syn pricedelay
foreach i of varlist co_rank co_p_r lnco{
g olympic_`i'=olympic*`i'
g soe_`i'=soe*`i'
g triple_`i'=olympic*soe_`i'
foreach a of varlist $beta {
qui eststo: reghdfe `a'_led  soe olympic `i' soe_olym1 olympic_`i' soe_`i' triple_`i' `a' $less 
}
drop olympic_`i' soe_`i' triple_`i' 
}
esttab using triple.csv , $option   replace

 fvset base 0 soe  olympic
 reghdfe beta_led beta c.co_rank##soe##olympic $full, abs(id ym) cluster(mdate)
 reghdfe amihud_led amihud c.co_p_r##soe##olympic $full, abs(id ym) cluster(mdate)

esttab using summer.csv , $option   replace


*---------------shortsell pilot-----------------------------------
eststo clear
gl beta beta syn amihud pricedelay //tot_vol idrisk_std 
foreach a of varlist $beta {
foreach i of varlist co_rank co_p_r lnco {
*qui eststo: reghdfe `a'_led `a' `i' $fe 
foreach b of varlist ss_pilot{  
cap drop `b'_co
g `b'_co=`b'*`i'
qui eststo: reghdfe `a'_led  `b' `i'  `b'_co $less
qui eststo: reghdfe `a'_led  `b' `i'  `b'_co `a' $less 
}
}
}
esttab using pilot.csv , $option   replace

*---------------shortsell pilot effect on co_p-----------------------------------
cd ..\output
gl optionfull p not obs b(a2) stats(r2 F N, labels(R2 F "No. of obs")) legend varlabels(_cons Constant) star(* 0.10 ** 0.05 *** 0.01)  
preserve
keep if !noq
eststo clear
foreach a of varlist co_rank co_p_r lnco lnuser_p  {
cap g `a'_led=`a'[_n+1]
qui eststo: reghdfe `a'_led amihud noq  soe_fifa soe $less
*qui eststo: reghdfe `a'_led amihud noq  soe_olym1 soe $less
}
esttab using pilot.csv , $optionfull   append

eststo clear
foreach a of varlist co_rank co_p_r lnco lnuser_p  {
foreach b of varlist ss_pilot {  
qui eststo: reghdfe `a'_led `b'  noq rep1-rep4 $less
}
}
esttab using pilot.csv , $optionfull   append
*---------------shortsell pilot/olympic effect on co_p, contemporaneous-----------------------------------
preserve
keep if !noq
eststo clear
foreach a of varlist co_rank co_p_r lnco lnuser_p  {
qui eststo: reghdfe `a' soe_olym1 soe rep1-rep4 l.(amihud noq   $control ), abs(id ym) cluster(mdate) 
}
esttab using pilot.csv , $optionfull   append
foreach a of varlist co_rank co_p_r lnco lnuser_p  {
qui eststo: reghdfe `a' soe_fifa soe rep1-rep4 l.(amihud noq   $control ) , abs(id ym) cluster(mdate) 
}
esttab using pilot.csv , $optionfull   append


*---------------shortsell pilot as IV of corank/co_p, strong IV, 2nd stage no result-----------------------------------
 reghdfe amihud_led amihud turnover lnsize bm_month TotInsHoldper ret lret_6 coverage  (co_p_r=ss_pilot), abs(id ym) cluster(mdate)
 reghdfe beta_led beta turnover lnsize bm_month TotInsHoldper ret lret_6 coverage  (co_rank=l.ss_pilot), abs(id ym) cluster(mdate)
  reghdfe beta_led beta turnover lnsize bm_month TotInsHoldper ret lret_6 coverage  (lnuser_p=ss_pilot), abs(id ym) cluster(mdate)

*current soe_olym don't work
eststo clear
foreach y of varlist $beta {
foreach a of varlist co_rank co_p_r lnco lnuser_p  {
qui eststo:reghdfe `y'_led `y' noq $control soe `a' , abs(id ym) cluster(mdate) ffirst  
qui eststo:reghdfe `y'_led `y' noq $control soe (`a'=l.ss_pilot) , abs(id ym) cluster(mdate) 
qui eststo:reghdfe `y'_led `y' noq $control soe (`a'=l.soe_olym1) , abs(id ym) cluster(mdate) 
}
}
esttab using IV.csv , $optionfull   //append


*---------------other disclosure quality-----------------------------------
* reghdfe amihud_led amihud c.co_p_r##soe##olympic $full, abs(id ym) cluster(mdate)
//what kind of stock do two fields of investor like?
g lntot_ask=ln(tot_ask+1)
gl beta_eqn lntot_ask amihud co_p_r soe_olym1 soe $control //, abs(id ym) cluster(mdate)
gl seleqn noq $control nox
heckman $beta_eqn, select($seleqn)  twostep
heckman lntot_ask amihud co_p_r soe_olym1 soe olympic , select(noq $control)

************************mannual heckman
qui probit f.noq $control
predict p1, xb
replace p1=-p1
generate phi = (1/sqrt(2*_pi))*exp(-(p1^2/2))
generate capphi = normal(p1)
generate invmills = phi/(1-capphi)
*---------------heckman: amihud/pilot effect on co_p-----------------------------------
gl cop co_rank co_p_r lnco lnuser_p
cd ..\output
gl optionfull p not obs b(a2) stats(r2 F N, labels(R2 F "No. of obs")) legend varlabels(_cons Constant) star(* 0.10 ** 0.05 *** 0.01)  
reghdfe lntot_ask_led ss_pilot amihud invmills rep1-rep4 $less //nothing is sign
eststo clear
foreach a of varlist  lntot_ask {
cap g `a'_led=`a'[_n+1]
qui eststo: reghdfe `a'_led ss_pilot amihud invmills rep1-rep4 turnover lnsize bm_month TotInsHoldper ret lret_6 coverage
}
esttab using heck.csv , $optionfull   replace
************************mannual heckman
eststo clear
qui eststo:heckman $beta_eqn, select($seleqn)  twostep //first vce(cluster mdate)

*-----------------------------------Prob of questions compare with reg non selection
eststo clear
qui eststo:reghdfe $beta_eqn, abs(id ym) cluster(mdate)
qui eststo:probit  f.noq  ss_pilot amihud syn pricedelay $control soe_olym1 soe olympic summer
qui eststo:probit f.nox ss_pilot amihud syn pricedelay  $control  soe summer if year>2013
esttab using selection.csv , p not obs b(a2) stats(r2 F N, labels(R2 F "No. of obs")) legend varlabels(_cons Constant) star(* 0.10 ** 0.05 *** 0.01)     replace
*-other disclosure 
eststo clear
gl beta beta syn amihud pricedelay tot_vol idrisk_std 
foreach a of varlist $beta {
foreach i of varlist lnuser_p ans_ask ans_rate {
qui eststo: reghdfe `a'_led `a' `i' $fe 
}
}
esttab using disclose.csv , $option   replace


foreach b of varlist ss_pilot{  
cap drop `b'_co
g `b'_co=`b'*`i'
qui eststo: reghdfe `a'_led  `b' `i'  `b'_co $fe 
qui eststo: reghdfe `a'_led  `b' `i'  `b'_co `a' $fe 
}

********************ordinary esttab
preserve
keep  if mdate>600 //&  coblog ==1
fvset base 601 mdate
foreach a of varlist beta {
eststo clear
foreach i of varlist co_rank co_demean lnco {
qui eststo: reghdfe `a'_led  `i'  $fe
foreach b of varlist wechat google olympic{  
qui eststo: reghdfe `a'_led  `b'#c.`i' $fe 
}
}
esttab using beta_fe.csv , $option   replace
}


foreach a of varlist  syn {
eststo clear
foreach i of varlist co_rank co_demean lnco {
foreach b of varlist wechat google olympic{  
qui eststo: reghdfe `a'_led  c.`i'  $fe
qui eststo: reghdfe `a'_led  c.`i'##`b' $fe 
}
}
esttab using beta_fe.csv , $option   append
}



***************************************graph

cd ../output
loc var co_p_r  //co_x_r
preserve
collapse (mean) avg=`var' (median) med=`var', by( mdate)
tsset mdate
twoway (tsline avg, yaxis(1)) (tsline med, yaxis(2)), name(factors, replace) ///
tlabel(,angle(forty_five) format(%tm)) xtitle("`var' if replace missing with 0")
graph export "TS_`var'1.pdf", as(pdf) replace

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
