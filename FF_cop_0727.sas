***delay3 come from weekly_horse.sas
*********The end week of each month is trouble*************************************************************************;
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
data port;
	set delay1;
	ym=mdy(month(week),1,year(week));
run;


**********************************************************************************;
data ret_firm;set xueqiu.ret_firm;ym=mdy(month(date),1,year(date));
drop month;*this is text;
run;
proc sort;by stkcd ym;
data lagme;
	set ret_firm;
	by stkcd ym;
	lagme=lag(size);
	if first.stkcd=1 then lagme=. ;
	if lagme^=.;
run;
data port1;merge port(in=a) lagme;by stkcd ym;
if a;*rename MRETWD=ret;run;
proc sort data= port1; by stkcd week;run;

***********************************formal part***********************************************;

%let vol=co_p_r;

proc sort ; by week; run;
proc univariate data=port1 noprint;
	var &vol;by week;
output out=vol pctlpts=25 to 75 by 25 pctlpre=vol;
*where num_cmt_p5w>0;
where &vol>0;
run;
proc sort data=vol; by week;run;
data sort;
	merge port1 vol(in=a); by week;if a;
	if &vol^=. and lagme^=.;
	if &vol =0 then dec=1;
	else dec=2;
	if &vol>vol25 then dec=3;
	if &vol>vol50 then dec=4;
	if &vol>vol75 then dec=5;
run;
proc means data=port1;
	var co_p_r co2_p_r;
where year(week) between 2011 and 2015 & num_cmt_p5w>0;
run;
proc univariate data=port1 noprint;
	var &vol;by week;
output out=vol pctlpts=20 to 80 by 20 pctlpre=vol;
where num_cmt_p5w>0;
run;
proc sort data=vol; by week;run;

data sort;
	merge port1 vol; by week;
	dec=1;
	if &vol>vol20 then dec=2;
	if &vol>vol40 then dec=3;
	if &vol>vol60 then dec=4;
	if &vol>vol80 then dec=5;
	if &vol^=. and lagme^=.;
run;

data sort;set sort;
dec=(co2_p_r>0);
*dec=(num_cmt_p5w>0);
***Sorting over***************************************************************************;

proc sort data=sort; by dec week ; run;
*EW similar to VW;
proc means data=sort noprint;
	weight lagme;
	var ret_led;
	by dec week;
	output out=dec mean=portret; 
run;

proc sort data=dec; by dec; run;

proc means data=dec noprint;
	var portret;
	by dec;
	output out=fiveavg mean=bigavg; 
run;
proc print;var dec bigavg;run;

***ALPHA***************************************************************************;
proc sort data=sort; by dec week;run;

proc reg data=sort outest=alpha tableout noprint;
     model ex_ret=rmrf smb hml
	 /edf;
     by dec;
run;
proc print data=alpha;where _TYPE_="PARMS" ;var dec intercept;run;
