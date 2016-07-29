/* this is monthly data, no xueqiu data yet
2016/7/27
has the diverse as core var to predict beta
data has lots of dup
soe is only up to 2013! so data decrease a lot
ta withq year exchg
newdata: vol_earning, skew, ivol_unr, ivol_res
previous turnover is wrong; it's signed volume
after kill cluster time, rank not sign, raw do; so it can be concentrated in reporting month?
save month_temp is w/o max, 1st version
use month_com_res,clear is 0727 version of max>0
keep max shld be later
this file kills lnuser_p and lncmt_p since it's too raw, for deseason before
*/
cd H:\crash\
cd .\log
cap log close
log using 0727.txt,t append

cd ..\input
use month_com,clear

duplicates rep stkcd ym,g(dup)
encode stkcd, gen(id)
gen mdate = mofd(ym)
format mdate %tm
replace year=year(ym)
g qtr=quarter(ym)
format date %td
*br year* qtr* date mdate
*use 2010 stock as base to exclude newly listed/IPO effect
g bef_11=(year<2011)
bys  id: egen _tmp1=sum(bef_11)
g _tmp2=substr(stkcd,1,1) 
keep if  _tmp1 & _tmp2 !="2" & _tmp2 !="9" 
drop _tmp1 _tmp2 
keep if year>2009
merge m:1 stkcd year qtr using E:\data\insti_hlding\inst_hld,keepusing( stkcd year qtr TotInsHoldper TotInsHoldperA TotInsHoldperURA) nogenerate  keep(match master)

*latest soe
merge m:1 stkcd year using "H:\crash\input\soe",nogenerate  keep(match master)

*need analyst dispersion for vol
*merge 1:1 stkcd year using "F:\work\Fiscal\analyst",nogenerate  keep(match master)
g report_year=year-1
merge m:1 stkcd report_year using anal_yr,nogenerate  keep(match master)
replace coverage=0 if coverage==. 
*Define those w/o questions, or at least define a dummy
g withq=num_user_p5w~=0
/*ta withq
ta nox year
replace co_p_r=0 if co_p_r==.
*/


/*g amihud=amihud*1000
replace amihud_led=amihud_led*1000
*/
rename  co_p5w co_p
*bm shld use dynamic monthly!
g lnbm=ln(bm)

drop if lnbm<0 & size<0 & turnover<0

bys mdate: egen co_mean=mean(co_p)
g co_demean=co_p-co_mean
*since co_mean can be 0,so use substract 
g lnco=ln(co_p+1)
/*g dist_stk_p=ln(dist_stk_p5w+1)
g lnuser_p=ln(num_user_p5w+1)
g lncmt_p=ln(num_cmt_p5w+1)
*/

/*cmts manualy deseason
qui eststo:reg lncmt_p i.year i.month
predict cmt_deseason,resid

qui eststo:reg lnuser_p i.year i.month
predict user_deseason,resid
sum user_deseason
esttab using timetrend.csv , $optionfull   append //replace
*/

bys mdate: cumul(co_p), gen(co_rank) equal
bys mdate: cumul(num_cmt_p5w), gen(cmt_rank) equal

sort id mdate
******************reporting month generate
/*collapse by month
see any monthly pattern*/
foreach i of numlist 1/4 {
g rep`i'=(repdt`i'_ ~=.)
}
*bys id (mdate): g syn_lead=f.syn
egen rep=rowmax(rep1 rep2 rep3 rep4)

xtset id mdate
foreach a of varlist ret beta syn amihud tot_vol idrisk_std pricedelay {
cap g `a'_led=`a'[_n+1]
}


g olympic=(mdate==ym(2012,8))
g fifa=(mdate==ym(2014,6)|mdate==ym(2014,7))
g summer=(month<9 & month>6) 
g aug=(month==8) 
g jan=(month==1)
g jun_july=(month<8 & month>5) 
g lret_6=l.ret_6
g soe_olym=(soe&olympic)
g soe_fifa=(soe&fifa)

g sh=substr(stkcd,1,1)=="6"
*ta withq  sh //year

*turnover shld not be in ctrl, since it's related to sentiment; dazhi use firmClu
gl control  lnsize lnbm TotInsHoldper ret lret_6  coverage 
gl firmClu f.withq $control , abs(ym) cluster(id) 
gl  timeClu f.withq $control, abs(id) cluster(mdate) 
gl full  f.withq $control  , abs(id ym) cluster(mdate)  //not cluster id is same


gl optionfull p not obs b(a2) stats(r2 F N, labels(R2 F "No. of obs")) legend varlabels(_cons Constant) star(* 0.10 ** 0.05 *** 0.01)  
gl option p not obs b(a2) drop($control ) stats(r2 F N, labels(R2 F "No. of obs")) legend varlabels(_cons Constant) star(* 0.10 ** 0.05 *** 0.01)  
gl outregopt merge drop($control )  addrows(""\"Clusters","Time"\"Fixed Effect","Time and Firm"\"Control","Yes")  landscape plain coljust(lc)  sdec(3)  stats(b p) starlevels(10 5 1) starloc(1) nolegend blankrows     nocons nodisplay sq
//don't need winsor $core
*original value like co*
gl core link_stk link_sum num_user_p5w dist_stk_p diverse_avg dist_stk_p5w lndiverse  lnco co_demean  co_p_r   co2_p_r co3_p_r cmt_rank co_rank 

gl beta beta syn amihud pricedelay tot_vol idrisk_std turnover  skew ivol_unr ivol_res

winsor2 $control $beta, replace
cd ..\output
logout, save(stat)  excel replace:tabstat $core $beta $control ,stat(n mean sd min p10 median p90 max)
logout, save(stat_res)  excel replace:tabstat $core $beta $control if max,stat(n mean sd min p10 median p90 max)
*---------------Baseline with beta, dif funtion form, link_stk link_sum num_user_p5w dist_stk_p diverse_avg is already log & detrended-----------------------------------
*link avg is raw value, detrend post is really showing time pattern

preserve
keep if max 
eststo clear
loc core link_stk link_sum num_user_p5w dist_stk_p diverse_avg lndiverse link_avg lnco  co_p_r   co2_p_r co3_p_r cmt_rank co_rank 
loc beta beta syn  turnover //pricedelay amihud tot_vol idrisk_std skew 
foreach a of varlist `beta' {
foreach b of varlist `core' {
qui eststo: reghdfe f.`a'  f.`b' $firmClu
qui eststo: reghdfe f.`a'  f.`b' `a' $firmClu
*qui eststo: reghdfe f.`a' `b' $full
*qui eststo: reghdfe f.`a'  `b' `a' $full
}
}
esttab using relax.csv , $option   title("Baseline with relax constraint") append  //replace
*---------------simplified version, big sample, not ctrl firm FE for detrend ones, only care current effect, but also compare with before co_p-----------------------------------
reghdfe f.syn beta f.co_p_r $firmClu
reghdfe f.beta beta f.co_p_r $full
eststo clear
loc core link_stk link_sum num_user_p5w dist_stk_p diverse_avg 
loc trend lndiverse link_avg  lnco  co_p_r co_rank  co2_p_r co3_p_r cmt_rank  
loc beta beta syn  turnover //pricedelay amihud tot_vol idrisk_std skew turnover
foreach a of varlist `beta' {
foreach b of varlist `core'  {
qui eststo: reghdfe f.`a'  f.`b' $firmClu
qui eststo: reghdfe f.`a'  f.`b' `a' $firmClu
qui eststo: reghdfe f.`a' `b' $firmClu
qui eststo: reghdfe f.`a'  `b' `a' $firmClu
}
foreach b of varlist `trend' {
qui eststo: reghdfe f.`a'  f.`b' $full
qui eststo: reghdfe f.`a'  f.`b' `a' $full
qui eststo: reghdfe f.`a' `b' $full
qui eststo: reghdfe f.`a'  `b' `a' $full
}
}
esttab using complete.csv , $option   title("trend vs detrended") append  //replace

*---------------olympic-----------------------------------
gl time summer rep3 rep4 jan aug
reghdfe dist_stk_p olym $time  i.year , abs(id )  //can't cluster(mdate), since it'll kill everything in common during olym month lower indeed

 
{*******************ERC, for every fiscal year, ret12, and d12.eps
*for rep4, l.ret12 means month 3- next year ret, l12.d12.eps, then collapse, since it's annual
preserve
g lret12=l.ret_12
g deps=d12.eps
g ldeps=l12.deps
g co1=l12.co_rank
 keep if rep4
reg lret12 c.co1##c.deps

*---------------Baseline with olympic, y & x-----------------------------------
*---------------only add firm FE, olym is sig! can't cluster year or month(insufficient obs)
eststo clear
gl core lncmt_p  lnco  lnuser_p co_p_r  user_deseason  cmt_rank co_rank single_rank 
gl beta beta syn amihud pricedelay tot_vol idrisk_std turnover skew
gl base withq lnsize lnbm TotInsHoldper ret lret_6  coverage , abs(id) //cluster(mdate) 
foreach a of varlist $beta {
*qui eststo: reghdfe f.`a' olym soe soe_olym summer rep1 rep4 i.year $timeClu 
*qui eststo: reghdfe f.`a' olym summer rep1 rep4 i.year $timeClu 

qui eststo: reghdfe f.`a' `a' f.(olym $time i.year) $timeClu 
}
eststo clear
gl base lnsize lnbm TotInsHoldper ret lret_6  coverage , abs(id) //cluster(mdate) 
foreach a of varlist $core {
*qui eststo: reghdfe `a' olym  $time i.year $timeClu 
qui eststo: reghdfe `a' olym soe soe_olym $time i.year $timeClu 
qui eststo: reghdfe f.`a'  olym soe soe_olym $time i.year $timeClu 
*qui eststo: reghdfe f.`a'  f.(olym $time i.year) $timeClu 
}
esttab using base_olym.csv , $optionfull   title("SOE interact next period") append //replace //
//need to see the current prob, less likely to have q in Olym
probit withq olym soe soe_olym $time i.year $control
preserve
keep if !withq
reghdfe beta_led beta withq turnover lnsize lnbm TotInsHoldper ret lret_6 coverage $time (co_p_r=olympic), abs(year)  ffirst stage(first) //can't add withq, since it strongly weaken core,but result is there

reghdfe co_p_r syn olym soe soe_olym $time i.year $timeClu 

*try to replicate the previous sign soe_olym result
reghdfe f.co_p_r  olym soe soe_olym summer rep1 rep4 jan i.year $timeClu //yes 
reghdfe co_p_r  olym soe soe_olym summer rep1 rep4 jan i.year $timeClu //no
reghdfe F.co_p_r  fifa soe soe_fifa summer rep1 rep4 jan i.year $timeClu //YES, +FIFA
reghdfe co_p_r  fifa soe soe_fifa summer rep1 rep4 jan jun_july i.year $timeClu //YES,-FIFA w/o jun_july; with jun_july, non-sign

*---------------Garch for vol-----------------------------------


*---------------shortsell pilot as IV of corank/co_p, strong IV, 2nd stage no result-----------------------------------
 reghdfe amihud_led amihud turnover lnsize lnbm TotInsHoldper ret lret_6 coverage  (co_p_r=ss_pilot), abs(id ym) cluster(mdate)
 reghdfe beta_led beta turnover lnsize lnbm TotInsHoldper ret lret_6 coverage  (co_rank=l.ss_pilot), abs(id ym) cluster(mdate)
  reghdfe beta_led beta turnover lnsize lnbm TotInsHoldper ret lret_6 coverage  (lnuser_p=ss_pilot), abs(id ym) cluster(mdate)

 reghdfe beta_led beta turnover withq lnsize lnbm TotInsHoldper ret lret_6 coverage soe olym (co_p_r=soe_olym), abs(id ym) cluster(mdate) //used to work, but not now!!!!qui eststo:reghdfe `y'_led `y' withq $control soe (`a'=l.soe_olym) , abs(id ym) cluster(mdate) 

  ******************only olym as IV
  reghdfe beta_led beta turnover lnsize lnbm TotInsHoldper ret lret_6 coverage summer (co_p_r=olympic), abs(id year) cluster(mdate) //all insignif
  reghdfe beta_led beta withq turnover lnsize lnbm TotInsHoldper ret lret_6 coverage $time (co_p_r=olympic), abs(year)  ffirst stage(first) //can't add withq, since it strongly weaken core,but result is there
  reghdfe beta_led beta turnover lnsize lnbm TotInsHoldper ret lret_6 coverage $time (single_rank=olympic), abs(year)  ffirst //weak,not sign
  reghdfe beta_led beta turnover lnsize lnbm TotInsHoldper ret lret_6 coverage $time (co_rank=olympic), abs(year)  ffirst stage(first) //weak, but negative
  est restore reghdfe_first1
  *can't cluster(year), otherwise wil not full rank

  
 reghdfe syn_led syn withq turnover lnsize lnbm TotInsHoldper ret lret_6 coverage $time (co_p_r=olympic), abs(year)  ffirst stage(first) //negative; drop withq, become stronger
 reghdfe syn_led syn turnover lnsize lnbm TotInsHoldper ret lret_6 coverage $time (user_deseason=olympic), abs(year)  ffirst stage(first) //negative; same as core, user_p not working

 reghdfe pricedelay_led turnover lnsize lnbm TotInsHoldper ret lret_6 coverage $time (user_deseason=olympic), abs(year)  ffirst stage(first) //negative; same as core, user_p not working
  
  
  *current soe_olym don't work
eststo clear
foreach y of varlist $beta {
foreach a of varlist co_rank co_p_r lnco lnuser_p  {
qui eststo:reghdfe `y'_led `y' withq $control soe `a' , abs(id ym) cluster(mdate) ffirst  
qui eststo:reghdfe `y'_led `y' withq $control soe (`a'=l.ss_pilot) , abs(id ym) cluster(mdate) 
qui eststo:reghdfe `y'_led `y' withq $control soe (`a'=l.soe_olym) , abs(id ym) cluster(mdate) 
}
}
esttab using IV.csv , $optionfull   //append

*---------------Baseline-----------------------------------
eststo clear
foreach a of varlist $beta {
foreach i of varlist lnuser_p single_rank ans_ask lndelay{
qui eststo: reghdfe `a'_led `i' $full 
qui eststo: reghdfe `a'_led `a' `i' $full 
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
qui eststo: reghdfe `a'_led  `b'##c.`i' $full 
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
qui eststo: reghdfe `a'_led `a' `i' $full 
foreach b of varlist olympic summer {  
cap drop `b'_co
g `b'_co=`b'*`i'
qui eststo: reghdfe `a'_led `a' `b' `i'  `b'_co $full 
}
qui eststo: reghdfe `a'_led `a' `i'  summer_co summer olympic olympic_co $full 
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
qui eststo: reghdfe `a'_led  `b' `i'  `b'_co $full 
}
qui eststo: reghdfe `a'_led `i'  summer_co summer olympic olympic_co $full 
}
}
esttab using summer.csv , $option   replace

//outreg using manual,$outregopt replace
 reghdfe beta_led beta c.co_rank##soe_olym $full, abs(id ym) cluster(mdate)
 reghdfe amihud_led amihud c.co_rank##soe_olym $full, abs(id ym) cluster(mdate)
 reghdfe beta_led beta c.co_rank##soe_fifa $full, abs(id ym) cluster(mdate)

*---------------change to less control, since withq is colinear with co_r-----------------------------------
//soe interact 
preserve
*keep if year>2010
eststo clear
gl  beta  beta amihud  syn pricedelay
foreach a of varlist $beta {
foreach i of varlist co_rank co_p_r lnco{
foreach b of varlist soe_olym {  
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
qui eststo: reghdfe `a'_led  soe##olympic##c.`i' `a' $full 
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
qui eststo: reghdfe `a'_led  soe olympic `i' soe_olym olympic_`i' soe_`i' triple_`i' `a' $less 
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
*qui eststo: reghdfe `a'_led `a' `i' $full 
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
preserve
keep if !withq
eststo clear
foreach a of varlist co_rank co_p_r lnco lnuser_p  {
cap g `a'_led=`a'[_n+1]
qui eststo: reghdfe `a'_led amihud withq  soe_fifa soe $less
*qui eststo: reghdfe `a'_led amihud withq  soe_olym soe $less
}
esttab using pilot.csv , $optionfull   append

eststo clear
foreach a of varlist co_rank co_p_r lnco lnuser_p  {
foreach b of varlist ss_pilot {  
qui eststo: reghdfe `a'_led `b'  withq rep1-rep4 $less
}
}
esttab using pilot.csv , $optionfull   append
*---------------shortsell pilot/olympic effect on co_p, contemporaneous-----------------------------------
preserve
keep if !withq
eststo clear
foreach a of varlist co_rank co_p_r lnco lnuser_p  {
qui eststo: reghdfe `a' soe_olym soe rep1-rep4 l.(amihud withq   $control ), abs(id ym) cluster(mdate) 
}
esttab using pilot.csv , $optionfull   append
foreach a of varlist co_rank co_p_r lnco lnuser_p  {
qui eststo: reghdfe `a' soe_fifa soe rep1-rep4 l.(amihud withq   $control ) , abs(id ym) cluster(mdate) 
}
esttab using pilot.csv , $optionfull   append



*---------------other disclosure quality-----------------------------------
* reghdfe amihud_led amihud c.co_p_r##soe##olympic $full, abs(id ym) cluster(mdate)
//what kind of stock do two fields of investor like?
g lntot_ask=ln(tot_ask+1)
gl beta_eqn lntot_ask amihud co_p_r soe_olym soe $control //, abs(id ym) cluster(mdate)
gl seleqn withq $control nox
heckman $beta_eqn, select($seleqn)  twostep
heckman lntot_ask amihud co_p_r soe_olym soe olympic , select(withq $control)

************************mannual heckman
qui probit f.withq $control
predict p1, xb
replace p1=-p1
generate phi = (1/sqrt(2*_pi))*exp(-(p1^2/2))
generate capphi = normal(p1)
generate invmills = phi/(1-capphi)
*---------------heckman: amihud/pilot effect on co_p-----------------------------------
gl core co_rank co_p_r lnco lnuser_p
cd ..\output
reghdfe lntot_ask_led ss_pilot amihud invmills rep1-rep4 $less //nothing is sign
eststo clear
foreach a of varlist  lntot_ask {
cap g `a'_led=`a'[_n+1]
qui eststo: reghdfe `a'_led ss_pilot amihud invmills rep1-rep4 turnover lnsize lnbm TotInsHoldper ret lret_6 coverage
}
esttab using heck.csv , $optionfull   replace
************************mannual heckman
eststo clear
qui eststo:heckman $beta_eqn, select($seleqn)  twostep //first vce(cluster mdate)

*-----------------------------------Prob of questions compare with reg non selection
eststo clear
qui eststo:reghdfe $beta_eqn, abs(id ym) cluster(mdate)
qui eststo:probit  f.withq  ss_pilot amihud syn pricedelay $control soe_olym soe olympic summer
qui eststo:probit f.nox ss_pilot amihud syn pricedelay  $control  soe summer if year>2013
esttab using selection.csv , p not obs b(a2) stats(r2 F N, labels(R2 F "No. of obs")) legend varlabels(_cons Constant) star(* 0.10 ** 0.05 *** 0.01)     replace
*-other disclosure 
eststo clear
gl beta beta syn amihud pricedelay tot_vol idrisk_std 
foreach a of varlist $beta {
foreach i of varlist lnuser_p ans_ask ans_rate {
qui eststo: reghdfe `a'_led `a' `i' $full 
}
}
esttab using disclose.csv , $option   replace


foreach b of varlist ss_pilot{  
cap drop `b'_co
g `b'_co=`b'*`i'
qui eststo: reghdfe `a'_led  `b' `i'  `b'_co $full 
qui eststo: reghdfe `a'_led  `b' `i'  `b'_co `a' $full 
}

********************ordinary esttab
preserve
keep  if mdate>600 //&  coblog ==1
fvset base 601 mdate
foreach a of varlist beta {
eststo clear
foreach i of varlist co_rank co_demean lnco {
qui eststo: reghdfe `a'_led  `i'  $full
foreach b of varlist wechat google olympic{  
qui eststo: reghdfe `a'_led  `b'#c.`i' $full 
}
}
esttab using beta_fe.csv , $option   replace
}


foreach a of varlist  syn {
eststo clear
foreach i of varlist co_rank co_demean lnco {
foreach b of varlist wechat google olympic{  
qui eststo: reghdfe `a'_led  c.`i'  $full
qui eststo: reghdfe `a'_led  c.`i'##`b' $full 
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
