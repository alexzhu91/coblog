use J:\work\coblog\reg2.dta,clear
cd J:\work\coblog\
encode stkcd, gen(id)
  gen mdate = mofd(date)
  format mdate %tm
  xtset id mdate
*this generate last month(maybe not there) monret
*g lret=l.monret
sort id mdate

bys mdate: egen co_mean=mean(co_num)
g co_demean=co_num/co_mean
g lnco=ln(co_num+1)
g lnnum_blogger=ln(num_blogger)

by mdate: cumul(co_num), gen(co_rank) equal
foreach y of varlist beta idrisk_std  {
bys id : g `y'_l=`y'[_n+1]
}
/*collapse by month
see any monthly pattern*/
foreach i of numlist 1/4 {
*g rep`i'=(repdt`i'_ ~=.)
*g co_rep`i'=co_demean*rep`i'
g co_rank_rep`i'=co_rank*rep`i'
*g lnco_rep`i'=lnco*rep`i'
}

egen rep=rowmax(rep1 rep2 rep3 rep4)
g rep_lag=rep[_n-1]
g rep_lead=rep[_n+1]
foreach i of varlist co_rank co_demean lnco{
g rep_`i'=rep*`i'
g rep_lag_`i'=rep_lag*`i'
g rep_lead_`i'=rep_lead*`i'
}

  global  fmb lnnum_blogger  turnover lnsize bm monret ret12_0
 *cant: lag(1)(not regular space)
  preserve
  keep  if mdate>627
  *can't xtbalance, since not all are continuous range(628,665)
 eststo clear
foreach y of varlist beta beta_l {
foreach i of varlist co_rank co_demean lnco{
qui eststo: xtfmb `y'  `i' rep_`i' rep $fmb
qui eststo: xtfmb `y' `i' rep_lead_`i' rep_lead $fmb
qui eststo: xtfmb `y' `i' rep_lag_`i' rep_lag $fmb
}
}
esttab using beta_fmb.csv , p not obs b(a2) stats(r2 F N, labels(R2 F "No. of obs"))  legend varlabels(_cons Constant) star(* 0.10 ** 0.05 *** 0.01)  replace

preserve
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


global fe lnnum_blogger turnover lnsize bm monret ret12_0  i.mdate,fe vce(cluster id)
preserve
keep  if mdate>627
eststo clear
fvset base 628 mdate
foreach y of varlist beta beta_l idrisk_std idrisk_std_l{
foreach i of varlist co_rank co_demean lnco{
qui eststo: xtreg `y'  `i'  $fe
qui eststo: xtreg `y'  `i' rep $fe
qui eststo: xtreg `y'  `i' rep_`i' rep $fe
qui eststo: xtreg `y' `i' rep_lead_`i' rep_lead $fe
qui eststo: xtreg `y' `i' rep_lag_`i' rep_lag $fe
qui eststo: xtreg `y' `i' rep_`i' rep_lag_`i' rep_lead_`i' rep rep_lag rep_lead $fe
}	
}
esttab using beta_fe.csv , p not obs b(a2) stats(r2 F N, labels(R2 F "No. of obs"))  legend varlabels(_cons Constant) star(* 0.10 ** 0.05 *** 0.01)  replace

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
logout, save(summary) word replace:tabstat beta idrisk_std co_num  num_blogger co_rank co_demean lnco, stat(n mean min p5 p25 p50 p75 p95 max)
