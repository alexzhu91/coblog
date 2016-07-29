merge m:1 stkcd year using "F:\work\Fiscal\analyst.dta"
use "H:\crash\monthly_discuss.dta"
g mdate=ym(year,month)
save,replace
use F:\work\coblog\reg4.dta,clear

merge 1:1 stkcd mdate using "H:\crash\monthly_discuss.dta"
drop if _merge==2 //else wont balance
*replace delay=0 if _merge==3 & delay==.
bys mdate :egen delay_med=median(delay)
sort id mdate
g asym=(delay>delay_med) if delay !=. //median
*********************************new phase: google vs delay (can add InstHolder) but sort out data first! what's really 0
eststo clear
qui eststo: xtreg f.syn c.lnnum_blogger##wechat  $fe
preserve
keep if asym==1
qui eststo: xtreg f.syn c.lnnum_blogger##wechat  $fe
restore 
preserve
keep if asym==0
qui eststo: xtreg f.syn c.lnnum_blogger##wechat  $fe
cd H:\result\coblog
esttab using syn2.csv , p not obs b(a2) stats(r2 F N, labels(R2 F "No. of obs"))  legend varlabels(_cons Constant) star(* 0.10 ** 0.05 *** 0.01)  replace
save F:\work\coblog\reg5

replace syn_lead=-syn_lead
replace syn=-syn
g lncov=ln(1+cov)
global fe turnover lnsize lnbm TotInsHoldper mretwd ret6_0  mkt lmkt i.mdate,fe vce(cluster id)

g num_size=num_blogger/lnsize
gl outregopt merge addrows(""\"Controls","Yes"\"Firm Fixed Effect","Yes"\"Year Fixed Effect","Yes")  landscape plain coljust(lc)  sdec(3)  stats(b p) starlevels(10 5 1) starloc(1) nolegend blankrows     nocons nodisplay sq
preserve
eststo clear
*outreg, clear
keep  if mdate>600 
fvset base 601 mdate
foreach a of varlist   syn{
foreach i of varlist num_size {
qui eststo: xtreg `a'  c.`i'##c.lncov $fe
*qui eststo: xtreg `a'  c.`i'##c.TotInsHoldper $fe
outreg using c,     $outregopt 
}
}
******************************size effect?
qui eststo: xtreg `a'  c.`i'##c.TotInsHoldper##wechat  $fe
outreg,     $outregopt 
qui eststo: xtreg `a'  c.`i'##c.TotInsHoldper##google  $fe
outreg,     $outregopt 
qui eststo: xtreg `a'  `i' c.lnsize##wechat  $fe
outreg,   ctitles(Var,"placebo with size"\"",`b')  $outregopt 
qui eststo: xtreg `a'  `i' c.lnsize##google  $fe
outreg using oc2, ctitles(Var,"placebo with size"\"",`b')  $outregopt  replace
}	
}

foreach a of varlist   syn{
foreach i of varlist lnnum_blogger{
qui eststo: xtreg `a'  c.`i'##c.lncov  c.`i'##c.TotInsHoldper $fe
outreg,     $outregopt 
*qui eststo: xtreg `a'_lead  c.`i'##c.lncov c.`i'##c.TotInsHoldper  $fe
*outreg,     $outregopt 
qui eststo: xtreg `a'  c.`i'##wechat  $fe
outreg,     $outregopt 
qui eststo: xtreg `a'  c.`i'##c.lncov##wechat  $fe
outreg,     $outregopt 
qui eststo: xtreg `a' c.`i'##google  $fe
outreg,     $outregopt 
qui eststo: xtreg `a'  c.`i'##c.lncov##google  $fe
outreg using oc1, $outregopt  
}	
}
cd H:\result\coblog
esttab using syn1.csv , p not obs b(a2) stats(r2 F N, labels(R2 F "No. of obs"))  legend varlabels(_cons Constant) star(* 0.10 ** 0.05 *** 0.01)  replace
