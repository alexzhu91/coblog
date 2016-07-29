***data come from weekly.sas
use which market FF3 shld not matter much***;
***create lag value of me***;

*********The end week of each month is trouble*************************************************************************;

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

%let vol=co2_p_r;

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
	if &vol>vol33 then dec=2;
	if &vol>vol66 then dec=3;
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
