data p5w;set p5w.v;
week=intnx("week.5", date_ask, 0, "m");
keep stkcd week user_ask ;format week yymmdd10. ;
where user_ask not contains 'ä¯ÀÀÓÃ»§';run; 
data roll ;
set xueqiu.day_ret ;
ex_ret=dretwd-rf/100;
ex_ret_m=dretwd-Dretwdos;
ex_mktret=Dretwdos-rf/100;
year=year(date);
rename dretwd=ret Dretwdos=mktret;
if (markettype=1) then exchg=1;
else if markettype=4 or markettype=16 then exchg=2;
else delete;
*keep stkcd year date ex_ret ex_ret_m dretwd ex_mktret Dretwdos exchg;
where year(date)>2008;
run;
**bef week, get daily adjusted trading vol;
data ff_daily;set xueqiu.FF3_daily;exchg=input(exchflg,3.);drop exchflg;
where exchflg ne '0' & mktflg='A';run;
proc sort; by exchg date;
proc sort data=roll; by exchg date;
data roll;merge roll(in=a) ff_daily;by exchg date;if a ;drop mktflg;run;
***************************get rep date, can be done by transpose;
data repar;
set p5w.repdt;
format date date9.;
rename date=ym repdt_ar=repdt4_;keep stkcd date repdt:;
run;
/*data prob;set repar;if repdt3_=.;run;*/
option mprint;
%macro rep;
%do i=1 %to 4;
data rep&i;
set repar;
if ym ne .;*many ym missing;
if missing(repdt&i._) then delete; 
week=intnx("week.5", repdt&i._, 0, "m");
rename repdt&i._=repdt;FY_qtr=&i;
keep stkcd week repdt&i._ FY_qtr;
run;
%end;
%mend rep;
%rep;
data rep;set rep1-rep4;format week yymmdd10.;
label FY_qtr="Fiscal reporting Qtr";run;
/*week1.2 is shifting the interval by 2 days forward, from one benchmark you can derive all the 
cycles. m means middle (week.5 is from Thur to next Wed);
turnover can be first avg or sum*/
proc sql;
********below is from Wed to next Wed(week.7 is from Tue to next Tue);
create table weekrtn as
select stkcd,intnx("week.5", date, 0, "m") as week format=yymmdd10., 
avg(DSMVOSD) as size format=16.,
avg(DNVALTRD/(DSMVOSD*10**3)) as turnover format=16.,
exp(sum(log(1+ret))) - 1 as ret format=percent8.2,
exp(sum(log(1+ex_ret))) - 1 as ex_ret format=percent8.2,
exp(sum(log(1+mktret))) - 1 as mktret format=percent8.2,
exp(sum(log(1+ex_mktret))) - 1 as ex_mktret format=percent8.2,
exp(sum(log(1+rmrf_tmv))) - 1 as rmrf format=percent8.2,
exp(sum(log(1+hml_tmv))) - 1 as hml format=percent8.2,
exp(sum(log(1+smb_tmv))) - 1 as smb format=percent8.2
from  roll
group by stkcd, calculated week
order by stkcd, calculated week;
/********below is FF_weekly;
create table stkcd as
select distinct stkcd, exchg  
from  roll;
create table ff_week as
select *,intnx("week.5", date, 0, "m") as week format=yymmdd10. 
from (select * from stkcd a join weekrtn b on a.stkcd=b.stkcd) a 
join ff_daily ;
*/
quit;

proc sort data=p5w;by stkcd week;where week ne .;
proc sort data=weekrtn;by stkcd week;where stkcd ne "";run;


option mprint;
%let data=p5w;
%let time=week;
%let user=user_ask;

proc sql;
create table stk_&data as
select &time,stkcd,count(distinct &user) as num_user_&data,count(&user) as num_cmt_&data
from &data
group by &time, stkcd 
order by &time, stkcd;

create table distinct_user as
select distinct &time,stkcd, &user
from &data;
/*proc sort data=&data out=distinct_user nodupkey; by ym stkcd user_ask; run;*/

/*how many stk est_betar user dist_stk*/
create table user_stk as
select &time,&user,count(distinct stkcd) as dist_stk,(count(distinct stkcd)>1) as co,
(count(distinct stkcd)>2) as co2,(count(distinct stkcd)>3) as co3
from &data
group by &time, &user 
order by &time, &user ;


proc sort data=distinct_user;
by &time &user ;
run;

data v2;
merge distinct_user user_stk;
by &time &user ;
run;

proc sql;
create table v1_sum as
select &time, stkcd,sum(co) as co_&data, sum(co2) as co2_&data,
 sum(co3) as co3_&data,avg(dist_stk) as dist_stk_&data label="avg #distinct stk est_betar stk@t" 
from v1
group by &time, stkcd ;

data stk_&data;
merge v1_sum stk_&data;
by &time stkcd ;
if &time ne .;
run;
proc means;
var co_&data co2_&data co3_&data;
where num_user_p5w>0;
run;
proc sort data=stk_p5w;by stkcd week;
*stk_p5w has all positive discussion;
proc sort data=rep;by stkcd week;
data week_co;
merge stk_p5w weekrtn(in=c) rep;
by stkcd week;if c;

if year(week)>2009;
	array CO dist_stk: co: num_user: num_cmt: ;
	do over CO;
	if CO=. then CO=0;
	end;
	if num_user_p5w ne 0 then do;
		co_p_r=co_p5w/num_user_p5w;co2_p_r=co2_p5w/num_user_p5w;co3_p_r=co3_p5w/num_user_p5w;
		*co4_p_r=co4_p5w/num_user_p5w;
		one=1-co_p_r;two=co_p_r-co2_p_r;three=co2_p_r-co3_p_r;
	end;
	else do;
		co_p_r=0;co2_p_r=0;co3_p_r=0;one=0;two=0;three=0;
	end;
	single=num_user_p5w-co_p5w;mult2=co_p5w-co2_p5w;mult3=co2_p5w-co3_p5w;
	two_three=mult2+mult3;*original # is right;
ym=mdy(month(week),1,year(week));run;
proc sort ;by stkcd ym;
data ret_firm;set xueqiu.ret_firm;ym=mdy(month(date),1,year(date));
drop month;run;
proc sort;by stkcd ym;
data coblog.week_com;merge week_co(in=a) ret_firm;by stkcd ym;if a;run;

proc means data=week_co;
	var one single two_three co3_p5w co_p_r co2_p_r co3_p_r;
where year(week) between 2011 and 2015 & num_cmt_p5w>0;
run;

%let var=co2_p_r;

proc printto log=weekly;
%let var=num_user_p5w;
proc expand data=week_co  out=delay method = none; 
  by stkcd;
  id week; 
	convert ret = ret_led / transformout=(lead 1); 
	convert ex_ret = exret_led / transformout=(lead 1); 
	convert &var = max  / transformout=(MOVMax  4 trimleft 11);;
	convert &var = med   / transformout=(MOVMed  8 trimleft 7);;
run;
proc printto; run;


data delay1;set delay;if max>0;svi=log(1+&var)-log(1+med);
run;
*this is original cop ratio, no adjust;
%let var=co_p_r;
data delay1;set delay;if max>0;
svi=&var;
run;
**********horse race****************;
data delay1;set delay;if max>0;
run;
proc sort data=delay1; by week; run;

proc reg data=delay1 outest=est_beta  noprint edf ;*tableout gets the full regression table;
by week;
 *model exret_led =  two co2_p_r;
 model exret_led = one two ;
 *model exret_led = svi;
run;
/*data one two three;set est_beta; if */
proc means data=est_beta mean std t probt;
*var  two co2_p_r; 
var one two ;
run;
*common practice to use the Newey-West adjustment for standard errors;
proc sort data=est_beta; by &time; run;

%let lags=8;
ods output parameterestimates=nw;
ods listing close;
proc model data=est_beta;
 *by &time;
 instruments / intonly;
 co2_p_r=a;
 fit  co2_p_r/ gmm kernel=(bart,%eval(&lags+1),0) vardef=n; run;
quit;
ods listing;
proc means data=delay1 n mean std t ;
  var two co2_p_r;*var svi exret_led ;
  *ods output summary=_uncorr;
run;


proc print data=nw; id &time;
 var svi--df; format svi stderr 7.4;
run;

proc sort; by exchg date;
proc sort data=roll; by exchg date;
data roll;merge roll(in=a) ff_daily;by exchg date;if a ;drop mktflg;run;

proc sort; by stkcd date;

************************core: if there's rsq or rmse, need non sychronous trading correction;
proc sort data=roll; by stkcd ym;

proc reg data=roll outest=est_beta  noprint edf ;*tableout gets the full regression table;
by stkcd ym;
    model ex_ret=rmrf_tmv smb_tmv hml_tmv;
run;
data ivol ;set est_beta;
n=_edf_+_P_ ;
if n>15 & _TYPE_ = 'PARMS';
keep stkcd ym _rmse_ ;
rename _rmse_=ivol;
run;


data coblog.week_co;
merge momentum( where=(year>2007)) ret_firm(drop=qtr) blogfull(in=a) ss(in=s) 
rep1-rep4 amihud_AVG(drop=_tyest_beta_ in=c) ;
by stkcd ym;if c;
*restrict on amihud, y var;
ss_pilot=s;
if year>2009 then do;
	array CO dist_stk: co_: num_user: num_cmt: ;
	do over CO;
	if CO=. then CO=0;
	end;
	if num_user_p5w ne 0 then co_p_r=co_p5w/num_user_p5w;
	else co_p_r=0;
	if num_user_xq ne 0 then co_x_r=co_xq/num_user_xq;
	else co_x_r=0;
end;
lnsize=log(size);
turnover=volume/size*10**3;
lev=1-equity/asset;
*volume is in 1000s;
run;
*how to process # of digits into a stock measure;

