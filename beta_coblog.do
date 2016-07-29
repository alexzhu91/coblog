/* use the original 30, 60 day rollbeta, in sample */
use J:\work\coblog\reg.dta,clear
cd J:\work\coblog\
encode stkcd, gen(id)
  gen mdate = mofd(date)
  format mdate %tm
  xtset id mdate
*this generate last month(maybe not there) monret
g lret=l.monret
sort id mdate

bys mdate: egen co_mean=mean(co_num)
g co_demean=co_num/co_mean
g lnco=ln(co_num+1)
g lnnum_blogger=ln(num_blogger)

by mdate: cumul(co_num), gen(co_rank) equal
foreach y of varlist beta std beta_60 std_60 {
bys id : g `y'_l=`y'[_n+1]
}
/*collapse by month
see any monthly pattern*/
foreach i of numlist 1/4 {
*g rep`i'=(repdt`i'_ ~=.)
*g co_rep`i'=co_demean*rep`i'
g corank_rep`i'=co_rank*rep`i'
}
eststo clear
g co_rank_ar=co_rank*rep4
 xtfmb std_60_l monret  co_rank co_rank_ar rep4 lnnum_blogger
 
foreach y of varlist beta std beta_60 std_60 {
foreach a of varlist co_rank co_demean lnco{
qui eststo: xtfmb `y' monret  `a'  lnnum_blogger
qui eststo: xtfmb `y'_l monret  `a'  lnnum_blogger
}
}
esttab using beta_fmb.csv , p not obs b(a2) stats(r2 F N, labels(R2 F "No. of obs")) label legend varlabels(_cons Constant) star(* 0.10 ** 0.05 *** 0.01)  replace

eststo clear
fvset base 656 mdate
foreach i of numlist 1/3 {
foreach y of varlist beta std beta_60 std_60 {
foreach a of varlist co_rank co_demean lnco{
qui eststo: xtreg `y' monret `a' c.`a'#1.rep`i' rep`i' lnnum_blogger i.mdate,fe vce(cluster id)
qui eststo: xtreg `y'_l monret `a'  c.`a'#1.rep`i' rep`i' lnnum_blogger i.mdate,fe vce(cluster id)
}	
}
}

eststo clear
foreach y of varlist beta std beta_60 std_60 {
foreach a of varlist co_rank {
qui eststo: xtfmb `y' monret `a'  corank_rep1 corank_rep2 corank_rep3 corank_rep4 rep1 rep2 rep3 rep4 lnnum_blogger
qui eststo: xtfmb `y'_l monret `a'  corank_rep1 corank_rep2 corank_rep3 corank_rep4 rep1 rep2 rep3 rep4 lnnum_blogger
}
}
esttab using J:\work\coblog\beta_fmb.csv , p not obs b(a2) stats(r2 F N, labels(R2 F "No. of obs")) legend varlabels(_cons Constant) star(* 0.10 ** 0.05 *** 0.01)  replace

foreach y of varlist beta std beta_60 std_60 {
foreach a of varlist co_rank co_demean lnco{
qui eststo: xtreg `y' monret `a'  c.`a'#rep1 c.`a'#rep2 c.`a'#rep3 c.`a'#rep4 rep1 rep2 rep3 rep4 lnnum_blogger i.mdate,fe vce(cluster id)
qui eststo: xtreg `y'_l monret `a'  c.`a'#rep1 c.`a'#rep2 c.`a'#rep3 c.`a'#rep4 rep1 rep2 rep3 rep4 lnnum_blogger i.mdate,fe vce(cluster id)
}
}
esttab using beta_fe.csv , p not obs b(a2) stats(r2 F N, labels(R2 F "No. of obs")) label legend varlabels(_cons Constant) star(* 0.10 ** 0.05 *** 0.01)  replace

save reg1,replace

logout, save(summary) word replace:tabstat beta std beta_60 std_60 co_num  num_blogger co_rank co_demean lnco, stat(n mean min p5 p25 p50 p75 p95 max)
