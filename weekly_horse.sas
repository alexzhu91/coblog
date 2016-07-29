***********7/25, originally test if large coattention matter;
proc expand data=week_co  out=delay2 method = none; 
  by stkcd;
  id week; 
	convert ret = ret_led / transformout=(lead 1); 
	convert ex_ret = exret_led / transformout=(lead 1); 
	convert ret = ret_led2 / transformout=(lead 2); 
	convert ex_ret = exret_led2 / transformout=(lead 2); 
	convert num_user_p5w = max  / transformout=(MOVMax  4 trimleft 11);;
	convert single = single_med   / transformout=(MOVMed  8 trimleft 7);;
	convert mult2 = mult2_med   / transformout=(MOVMed  8 trimleft 7);;
	convert co2_p5w = mult3_med   / transformout=(MOVMed  8 trimleft 7);;
run;

data delay3;set delay2;if max>0;
single=log(1+single)-log(1+single_med);
mult2=log(1+mult2)-log(1+mult2_med);
co2_p5w=log(1+co2_p5w)-log(1+mult3_med);
run;
proc sort data=delay3; by week; run;

proc reg data=delay3 outest=est_beta  noprint edf ;*tableout gets the full regression table;
by week;
 model exret_led = single mult2 co2_p5w;
run;
proc means data=est_beta mean std t probt;
var single mult2 co2_p5w ;
run;
*see what the raw var stat;
proc means data=delay3 mean std ;
var single mult2 co2_p5w exret_led;
run;


***********use week_com with monthly controls: 7/26 see if reporting matters;
proc sort data=week_com nodupkey; by stkcd week; run;
proc expand data=week_com  out=delay2 method = none; 
  by stkcd;
  id week; 
	convert Fy_qtr = rep_month  / transformout=(MOVMax  5 trimleft 4);*get the month after repdt;
	convert ret = ret_led / transformout=(lead 1); 
	convert ex_ret = exret_led / transformout=(lead 1); 
	convert ret = ret_led2 / transformout=(lead 2); 
	convert ex_ret = exret_led2 / transformout=(lead 2); 
	convert num_user_p5w = max  / transformout=(MOVMax  4 trimleft 3);
	convert num_user_p5w = total_med  / transformout=(MOVMed  8  trimleft 7);
	convert single = single_med   / transformout=(MOVMed  8 trimleft 7);
	convert co_p5w = twoabove_med   / transformout=(MOVMed  8 trimleft 7);
	convert two_three = mult2_med   / transformout=(MOVMed  8 trimleft 7);
	convert co3_p5w = mult3_med   / transformout=(MOVMed  8 trimleft 7);
run;



data delay3;set delay2;if max;
*if rep_month ne .;
*if rep_month=.;
*if rep_month ne 1;*sample control!!!;
lnsize=log(size);
if bm>0 then bm=log(bm+1);
else delete;
single=log(1+single)-log(1+single_med);
two_three=log(1+two_three)-log(1+mult2_med);
co3_p5w=log(1+co3_p5w)-log(1+mult3_med);
total=log(1+num_user_p5w)-log(1+total_med);
co_p5w=log(1+co_p5w)-log(1+twoabove_med);
run;

proc sort data=delay3; by week; run;

proc reg data=delay3 outest=est_beta  noprint edf ;*tableout gets the full regression table;
by week;
 *model ex_ret = single two_three co3_p5w lnsize turnover bm;
 *model exret_led = single two_three co3_p5w lnsize turnover bm;
  model exret_led = single co_p5w lnsize turnover bm;
  *model exret_led = co_p_r lnsize turnover bm;
*model exret_led = one two co2_p_r lnsize turnover bm;
 where year(week)>2010;
run;
proc means data=est_beta mean std t probt;
*var single two_three co3_p5w;
*var co_p_r;
var single co_p5w;
*var one two co2_p_r;
run;
PROC exPORT data=delay3
outfile= "H:\crash\input\weekly.dta"
DBMS= stata REPLACE;
Run;

*********newey adjust;
proc sort data=est_beta; by week; run;

%let lags=8;
ods output parameterestimates=nw;
ods listing close;
proc model data=est_beta;
 *by &time;
 instruments / intonly;
 single=a;
 two_three=b;
 co3_p5w=c;
 fit  single two_three co3_p5w/ gmm kernel=(bart,%eval(&lags+1),0) vardef=n; run;
quit;
ods listing;
proc means data=delay1 n mean std t ;
  var two co2_p_r;*var svi exret_led ;
  *ods output summary=_uncorr;
run;

*see what the raw var stat;
proc means data=delay3 n mean std min max;
var single two_three co3_p5w exret_led;
run;
*see how distributed among dif users, raw value;
proc sort data=delay2; by rep_month; run;
proc means data=delay2 n mean std min max;
*var num_user_p5w single two_three co3_p5w;*this is raw;
var one two three co3_p_r;*this is ratio;
by rep_month;
run;

************************high-low attention group syn
for each stock with at least 2 years of weekly data;
data high low;*single two_three co3_p5w(4:23) total (10:17) ;
set delay3;
if total>0 then output high;
else output low;
run;
proc sort data=delay3; by week; run;

proc reg data=high outest=high_syn  noprint edf ;
by week;
 model ex_ret = single two_three co3_p5w;
 where year(week)>2010;
run;
data 
proc means data=est_beta mean std t probt;
var single two_three co3_p5w;
run;
