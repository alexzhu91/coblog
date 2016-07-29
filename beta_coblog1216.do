use J:\work\coblog\reg3.dta,clear
cd J:\work\coblog\
use J:\work\coblog\reg4.dta,clear
replace qtr=qtr+1
merge m:1 stkcd year qtr using J:\data\insti_hlding\inst_hld,keepusing( stkcd year qtr TotInsHoldper TotInsHoldperA TotInsHoldperURA) nogenerate  keep(match master)
g lnbm=ln(bm)
/*import excel "J:\data\monret_gta\TRD_Mont.xls", sheet("TRD_Mont") firstrow
g mdate=monthly(Trdmnt,"YM")
rename Markettype markettype
save D:\stata13\mkt_monret
*/
merge m:1 markettype mdate using D:\stata13\mkt_monret,nogenerate  keep(match master)
encode stkcd, gen(id)
  gen mdate = mofd(date)
  format mdate %tm
  xtset id mdate
*this generate last month(maybe not there) monret
*g lret=l.monret
g lmkt=l.Mretwdos
g mkt=Mretwdos 

bys mdate: egen co_mean=mean(co_num)
*since co_mean can be 0,so use substract 
sort id mdate
g co_demean=co_num-co_mean
g lnco=ln(co_num+1)
replace num_blogger=0 if num_blogger==.
g lnnum_blogger=ln(num_blogger+1)
by mdate: cumul(co_num), gen(co_rank) equal
******************g google&law dummy***
g google=(date>mdy(6,1,2014))
g wechat=(date>mdy(8,1,2013))
g placebo=(date>mdy(1,1,2015))
 winsor2 beta* syn*,replace



/*collapse by month
see any monthly pattern*/
foreach i of numlist 1/4 {
g rep`i'=(repdt`i'_ ~=.)
g co_rep`i'=co_demean*rep`i'
g co_rank_rep`i'=co_rank*rep`i'
g lnco_rep`i'=lnco*rep`i'
}
*bys id (mdate): g syn_lead=f.syn
egen rep=rowmax(rep1 rep2 rep3 rep4)
foreach i of varlist co_rank co_demean lnco{
g rep_`i'=rep*`i'
}

foreach b of varlist placebo wechat google {  
foreach i of varlist co_rank co_demean lnco {
g `i'_`b'=`i'*`b'
}
}
  global  fmb lnnum_blogger  turnover lnsize bm mretwd ret12_0,lag(1)
 *cant: lag(1)(not regular space)

 eststo clear
preserve
keep  if mdate>600 //&  coblog ==1
fvset base 601 mdate
foreach a of varlist beta  syn {
foreach b of varlist wechat google {  
foreach i of varlist co_rank co_demean lnco {
qui eststo: xtfmb `a'_lead  `i' rep $fmb
qui eststo: xtfmb `a'_lead  `i' `i'_`b' rep $fmb
}
}
}
esttab using beta_fmb.csv , p not obs b(a2) stats(r2 F N, labels(R2 F "No. of obs"))  legend varlabels(_cons Constant) star(* 0.10 ** 0.05 *** 0.01)  replace

keep  if mdate>627
eststo clear
foreach y of varlist idrisk_std {
qui eststo: xtfmb `y'  co_demean rep1 rep2 rep3 rep4  $fmb 
qui eststo: xtfmb `y'  co_rep1 co_rep2 co_rep3 co_rep4 co_demean rep1 rep2 rep3 rep4 $fmb
qui eststo: xtfmb `y' co_rank rep1 rep2 rep3 rep4  $fmb 
qui eststo: xtfmb `y' co_rank_rep1 co_rank_rep2 co_rank_rep3 co_rank_rep4 co_rank rep1 rep2 rep3 rep4 $fmb
qui eststo: xtfmb `y'  lnco rep1 rep2 rep3 rep4  $fmb 
qui eststo: xtfmb `y' lnco_rep1 lnco_rep2 lnco_rep3 lnco_rep4 lnco rep1 rep2 rep3 rep4 $fmb
}
esttab using beta_fmb.csv , p not obs b(a2) stats(r2 F N, labels(R2 F "No. of obs"))  legend varlabels(_cons Constant) star(* 0.10 ** 0.05 *** 0.01)  replace

*mdate=600 is 2010m1;mretwd ret3_0 is from GTA(same with monret)

*********************************Google & wechat
global fe lnnum_blogger turnover lnsize lnbm TotInsHoldper mretwd ret6_0  mkt lmkt i.mdate,fe vce(cluster id)
eststo clear
preserve
keep  if mdate>600 //&  coblog ==1
fvset base 601 mdate
foreach a of varlist beta syn {
foreach b of varlist wechat google {  
foreach i of varlist co_rank co_demean lnco {
qui eststo: xtreg `a'_lead  `i' rep $fe
qui eststo: xtreg `a'_lead  `i' c.`i'#1.`b' rep $fe 
}
}
}
esttab using beta_fe.csv , p not obs b(a2) stats(r2 F N, labels(R2 F "No. of obs"))  legend varlabels(_cons Constant) star(* 0.10 ** 0.05 *** 0.01)  replace
//placebo
eststo clear
preserve
keep  if  date>mdy(6,1,2014) 
fvset base 601 mdate
foreach a of varlist beta syn {
foreach b of varlist placebo {
foreach i of varlist co_rank co_demean lnco {
qui eststo: xtreg `a'_lead  `i' rep $fe
qui eststo: xtreg `a'_lead  `i' c.`i'#1.`b' rep $fe 
}
}
}
esttab using beta_fe.csv , p not obs b(a2) stats(r2 F N, labels(R2 F "No. of obs"))  legend varlabels(_cons Constant) star(* 0.10 ** 0.05 *** 0.01)  replace


*check beta as ctrl for serial cor
preserve
eststo clear
keep  if mdate>600 
fvset base 601 mdate
foreach a of varlist   syn{
foreach i of varlist co_rank co_demean lnco{
qui eststo: xtreg `a'_lead `a'  `a'_lag  `i' rep $fe
qui eststo: xtreg `a'_lead `a'  `a'_lag  `i' rep_`i' rep $fe
}	

keep if coblog ==1
foreach i of varlist co_rank co_demean lnco{
qui eststo: xtreg `a'_lead `a'  `a'_lag  `i' rep $fe
qui eststo: xtreg `a'_lead `a'  `a'_lag  `i' rep_`i' rep $fe
}	
}
esttab using beta_fe.csv , p not obs b(a2) stats(r2 F N, labels(R2 F "No. of obs"))  legend varlabels(_cons Constant) star(* 0.10 ** 0.05 *** 0.01)  replace
*use SAS
export excel using "J:\work\coblog\reg3.xlsx", firstrow(variables) replace //too slow
export sasxport "B:\rollbeta\beta.xpt", replace vallabfile(none) rename
/*see half year report&annual report*/
preserve
keep  if mdate>627
fvset base 628 mdate
eststo clear
foreach y of varlist beta beta_l {
qui eststo: xtreg `y'  co_demean rep1 rep2 rep3 rep4  $fe 
qui eststo: xtreg `y'  co_rep1 co_rep2 co_rep3 co_rep4 co_demean rep1 rep2 rep3 rep4 $fe
qui eststo: xtreg `y' co_rank rep1 rep2 rep3 rep4  $fe 
qui eststo: xtreg `y' co_rank_rep1 co_rank_rep2 co_rank_rep3 co_rank_rep4 co_rank rep1 rep2 rep3 rep4 $fe
qui eststo: xtreg `y'  lnco rep1 rep2 rep3 rep4  $fe 
qui eststo: xtreg `y' lnco_rep1 lnco_rep2 lnco_rep3 lnco_rep4 lnco rep1 rep2 rep3 rep4 $fe
}
esttab using beta_fe.csv , p not obs b(a2) stats(r2 F N, labels(R2 F "No. of obs"))  legend varlabels(_cons Constant) star(* 0.10 ** 0.05 *** 0.01)  replace

eststo clear
foreach y of varlist beta std beta_60 std_60 {
foreach a of varlist co_rank {
qui eststo: xtfmb `y' monret `a'  corank_rep1 corank_rep2 corank_rep3 corank_rep4 rep1 rep2 rep3 rep4 lnnum_blogger
qui eststo: xtfmb `y'_l monret `a'  corank_rep1 corank_rep2 corank_rep3 corank_rep4 rep1 rep2 rep3 rep4 lnnum_blogger
}
}
esttab using beta_fmb.csv , p not obs b(a2) stats(r2 F N, labels(R2 F "No. of obs")) legend varlabels(_cons Constant) star(* 0.10 ** 0.05 *** 0.01)  replace

foreach y of varlist beta std beta_60 std_60 {
foreach a of varlist co_rank co_demean lnco{
qui eststo: xtreg `y' monret `a'  c.`a'#rep1 c.`a'#rep2 c.`a'#rep3 c.`a'#rep4 rep1 rep2 rep3 rep4 lnnum_blogger i.mdate,fe vce(cluster id)
qui eststo: xtreg `y'_l monret `a'  c.`a'#rep1 c.`a'#rep2 c.`a'#rep3 c.`a'#rep4 rep1 rep2 rep3 rep4 lnnum_blogger i.mdate,fe vce(cluster id)
}
}
esttab using beta_fe.csv , p not obs b(a2) stats(r2 F N, labels(R2 F "No. of obs")) label legend varlabels(_cons Constant) star(* 0.10 ** 0.05 *** 0.01)  replace

save reg1,replace

preserve
keep mdate ym beta beta_l idrisk_std idrisk_std_l co_rank co_demean lnco co_rank_rep4 co_rank_rep3 co_rank_rep2 co_rank_rep1 rep_lnco rep_lead_lnco rep_lead_co_rank rep_lead_co_demean rep_lead rep_lag_lnco rep_lag_co_rank rep_lag_co_demean rep_lag rep_co_rank rep_co_demean rep1 rep2 rep3 rep4 rep lnnum_blogger turnover lnsize bm monret ret12_0 ret3_0 ret6_0 
export sasxport "B:\rollbeta\beta.xpt", rename replace

keep  if mdate>627
logout, save(summary) word replace:tabstat beta syn co_num  num_blogger co_rank co_demean lnco, stat(n mean min p5 p25 p50 p75 p95 max)
qui estpost cor beta syn co_num  num_blogger co_rank co_demean lnco , matrix //listwise
est store c1
esttab c1 using corrl.csv, star unstack not noobs compress replace

save reg4
