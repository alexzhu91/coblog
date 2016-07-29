/*rollbeta.beta_60(30) is from the stk pool of p5w*/
libname rollbeta "f:/rollbeta";
/*要先drop年报日附近的（单独分析？），以及浏览用户，看剩下为unregular disclosure
amihud and beta share the same year>2008
SS.ANC_LOSS HAVE PRE DISCLOSRE, BUT IT'S DAILY, SO HAVE TO USE SEPARATE OR AS A DUMMY*/

/*how to choose btw co_bloger or links?
every one has a stock pool, if stk appears once, then it connects with all other stocks in that pool;
if it appears in the 2nd investor, then co_p=2, and connects with all other stocks in that pool;but if there's
no overlap btwn the other stocks, then links ~= co_p 
For every user A, he has a pool>1,then co_p=1 for stk 1,but if stk appears in another co-blogger B, then 
co_p=2, but the link with stk 2 is only one, since B only covers stk 5,6
Imagine the extreme case, stk 1 has 100 user discussing, each user has 1 unique other stk, so co_p=100,but
links are 100 =1 with .
at end of day, need to summarize by stk, so links are not good, avg co_num_link>1 is 46, while co_p avg is 3.5,
co_num_link/num_link=2.5(how many investor is the bridge(coblogger) on avg for one pair, num_link=num_pair), so
their ratio is a good indicator of how scattered, so on the contrary, it's concentrated:
each user has many stks, while not many users co_talk/overlap each other;
stk,
A 1,2.3

B 1,5.6

3 ways to generate the links, sql is slowest, but can be done once I have the computer
*/


*how many for shanghai discussion: ts pattern;
data p;set p5w.sum;sh=(substr(stkcd,1,1)=6);run;
proc means data=p n noprint;
var tot_ask;
class year month sh;
output out=ym n=num;
run;
proc export data=ym(where=(_TYPE_=7))
outfile= "H:\grad\input\ts_discuss.dta"
DBMS= stata REPLACE;
Run;

*SS.ANC_LOSS MONTHLY, 1-2 PER QTR,PUT ON HOLD for now;
DATA ANC_LOSS;SET SS.ANNC_LOSS;MONTH=YEAR(DATE);
proc means data=ANC_LOSS n noprint;
var SOURCE;
class STOCKCODE year MONTH;
output out=LOSS n=num;
run;

dm "out;clear;log;clear;";
*SHORT DATA summary by month, label the first month when there's not full month data;
libname ss 'H:\shortsell';
data ss;set ss.ss;ym=mdy(month,1,year);run;
proc means data=ss n mean noprint;
var long short;
class stkcd ym;
output out=ss MEAN=long short N=SHORT_DAYS;
run;

*focus on num of dif user, not consider num of cmts yet;
%macro coblog(data,time,user);
proc sql;
create table stk_&data as
select &time,stkcd,count(distinct &user) as num_user_&data,count(&user) as num_cmt_&data
from &data
group by &time, stkcd ;
%mend coblog;
data xq;set xueqiu.main;ym=mdy(month(date),1,year(date));keep stkcd user ym;run; 
proc sort data=xq;
by user ;
run;
data xq;
set xq;
by user ;
retain id 0 ;
if first.user then id=id+1;
else id=id;
run;
%coblog(xq,ym,id);
data p5w;set p5w.v;ym=mdy(month(date_ask),1,year(date_ask));keep stkcd user_ask ym;where user_ask not contains '浏览用户';run; 
%coblog(p5w,ym,user_ask);

*general char of p5w.sum (monthly，only up to 2015/5);
proc sql;
create table blog as
select a.*,b.*
from stk_p5w a full join stk_xq b
on a.ym=b.ym & a.stkcd=b.stkcd
where a.ym ne . & a.stkcd ne "" ;

create table blogfull as
select a.*,b.*
from blog a full join p5w.sum b 
on year(a.ym)=b.year & month(a.ym)=b.month & a.stkcd=b.stkcd
where a.stkcd ne ""  ;
/* Sanity Checks for Duplicates - Ultimately, Should be 0 Duplicates */
proc sort data=blogfull nodupkey; by stkcd ym; run;

*from p5w.cc_sum,get co_p;
proc means data=p5w.cc_sum  noprint;
var num;
where num>1;
class ym stkcd;
output out=cc_cop sum=co_num_link N=num_link;
run;
data cc;set cc_cop;where _type_=3;link=co_num_link/num_link;drop _type_;
label link="co_num_link/num_link";
proc sort data=cc nodupkey; by stkcd ym; run;

/*proc means mean;*/
/*var x co_num_link;*/
/*run;*/
/*proc means data=coblog.stk_p mean;*/
/*var co_num;*/
/*run;*/

data amihud;
set xueqiu.day_ret;
where year(date)>2007;
amihud=abs(DRETWD)*10000000/DNVALTRD;*ret in percentage and divide by 10,0000;
ym=mdy(month(date),1,year(date));
proc means data=amihud mean noprint;
var amihud DRETWD;
class stkcd ym;
output out=amihud_AVG mean(amihud)=amihud std(DRETWD)=tot_vol;
run;
*need to change _type_ when changed to ym;
proc sort data=amihud_AVG(where=(_TYPE_=3) rename=(_freq_=num_trdday)) nodupkey;
by stkcd ym;
/*proc means   ;*/
/*var amihud ;*/
/*run;*/


/*proc export data=amihud_AVG*/
/*outfile= "H:\crash\input\amihud.dta"*/
/*DBMS= stata REPLACE;*/
/*Run;*/

data roll ;
set rollbeta.ret ;
ret_excess=dretwd-rf;
mktret_excess=Dretwdos-rf;
ym=mdy(month,1,year);
keep stkcd ym date ret_excess dretwd mktret_excess Dretwdos ;
where year>2008;
run;

proc expand data=roll  out=delay method = none; 
  by stkcd;
  id date; 
	convert dretwdos = mktret;
	convert dretwd = ret;
	convert dretwdos = mkt_lag1   / transformout=(lag 1); 
	convert dretwdos = mkt_lag2   / transformout=(lag 2); 
	convert dretwdos = mkt_lag3   / transformout=(lag 3); 
	convert dretwdos = mkt_lag4   / transformout=(lag 4); 
run;

proc reg data=delay outest=est_beta  noprint edf ;*tableout gets the full regression table;
by stkcd ym;
	model ret = mktret mkt_lag1 mkt_lag2 mkt_lag3 mkt_lag4;
	model ret = mktret ;
	model ret_excess = mktret_excess;
run;


************************daily delay;

*amihud no mkt ret;
/*  retpos=(ret>0)*abs(ret);*/
/*  retneg=(ret<0 and not missing(ret))*abs(ret);*/

data unr res beta;set est_beta;
n=_edf_+_P_ ;
if n>15 & _TYPE_ = 'PARMS';

if _MODEL_='MODEL1' then do;
	output unr;end;
else if _MODEL_='MODEL2' then do;
	output res;end;
else do;
	output beta;
end;
run;
data beta;set beta;	drop _MODEL_ _TYPE_ _DEPVAR_ _IN_ _P_ n _edf_ ret ret_excess mktret mkt_lag1 mkt_lag2 mkt_lag3 mkt_lag4;
	rename _rmse_=Idrisk_std mktret_excess=beta;
run;
data delay_day;
*_adjrsq_ (_adjrsq_=unr)) res(rename=(_adjrsq_=res)) can't use adjrsq, since it produce negative delay;
merge unr(rename=(_RSQ_=unr)) res(rename=(_RSQ_=res));
by stkcd ym;
pricedelay=1-res/unr;keep stkcd ym pricedelay;
run;
*res_sas.monret is not complete,use GTA ret_firm;
data ret_firm;set xueqiu.ret_firm;ym=mdy(month(date),1,year(date));
drop month;*this is text;
run;
proc sort;by stkcd ym;
data stk_p;set coblog.stk_p;drop _type_;
proc sort;by stkcd ym;
data stk_x;set coblog.stk_x;drop _type_;
proc sort;by stkcd ym;

data repar;
set p5w.repdt;
format date date9.;
rename date=ym repdt_ar=repdt4_;keep stkcd date repdt:;
run;
option mprint;
%macro rep;
%do i=1 %to 4;
data rep&i;
set repar;
ym=mdy(month(repdt&i._),1,year(repdt&i._));
keep stkcd ym repdt&i._;
if ym ne .;
run;
proc sort data=rep&i;
by stkcd ym;
%end;
%mend rep;
%rep;
*rollbeta.beta_12 is old beta in 1210 sas, and use the coblog sample;

/*get momentum and shld use full sample to ensure vol data for 2010*/
proc sort data = xueqiu.ret;by stkcd date;
proc expand data = xueqiu.ret(rename=(monret=ret)) from=month out=y method=none; *(obs=1000 keep=stkcd date monret);
    by stkcd;
    id date;
quit;
proc expand data = y  out=momentum method=none;
    by stkcd;
    id date;
    convert RET = RET_3  / transformin=(+1) transformout=( MOVPROD  3 -1 trimleft  2);
	convert RET = RET_6  / transformin=(+1) transformout=(MOVPROD  6 -1 trimleft  5);
	convert RET = RET_9  / transformin=(+1) transformout=(MOVPROD  9 -1 trimleft  8);
	convert RET = RET_12 / transformin=(+1) transformout=(MOVPROD 12 -1 trimleft 11);
    convert RET = Tot_Vol_mv / transformout = (movstd 24 trimleft 24);
quit;
DATA momentum;SET momentum;rename date=ym;
label RET    = "Stock Return of current Month ";
label RET_3  = "Stock Return of Last 3 Months ";
label RET_6  = "Stock Return of Last 6 Months ";
label RET_9  = "Stock Return of Last 9 Months ";
label RET_12 = "Stock Return of Last 12 Months ";
label Tot_Vol_mv  = "Total Stock Return Volatility in the Last 24 Months";



proc sort data=beta nodupkey; by stkcd ym; run;
proc sort data=momentum nodupkey; by stkcd ym; run;
proc sort data=ret_firm nodupkey; by stkcd ym; run;
proc sort data=cc nodupkey; by stkcd ym; run;
proc sort data=ss nodupkey; by stkcd ym; run;
proc sort data=stk_x nodupkey; by stkcd ym; run;
proc sort data=stk_p nodupkey; by stkcd ym; run;
proc sort data=amihud_AVG nodupkey; by stkcd ym; run;
/*data why;merge momentum(where=(year>2007)) amihud_AVG;by stkcd ym;*/

data coblog.temp;
*ref_firm has qtr before,coblog1 is from momentum, but shld be with nonmissing y:amihud ;
merge beta momentum( where=(year>2007)) ret_firm(drop=qtr) stk_p(rename=(co_num=co_p num_blogger=blogger_p) in=a) ss(in=s) cc
stk_x(rename=(co_num=co_x num_blogger=blogger_x) in=b) blogfull 
rep1-rep4 amihud_AVG(drop=_type_ in=c) delay_day;
by stkcd ym;if c;
*restrict on amihud, y var;
lnsize=log(size);
coblog=a;xq=b;ss_pilot=s;
if year>2009 then do;
	array CO blogger_: co_: num_user: num_cmt: ;
	do over CO;
	if CO=. then CO=0;
	end;
	if num_user_p5w ne 0 then co_p_r=co_p/num_user_p5w;
	else co_p_r=0;
	if num_user_xq ne 0 then co_x_r=co_x/num_user_xq;
	else co_x_r=0;
end;
syn=log(_rsq_/(1-_rsq_));
drop _edf_ ;
turnover=volume/size*10**3;
lev=1-equity/asset;
*volume is in 1000s;
run;
Proc Sort noduprec; by _all_;run;


proc print;run;


PROC exPORT data=coblog.temp
outfile= "H:\crash\input\coblog.dta"
DBMS= stata REPLACE;
Run;
*************below is wrong, get duplicate;
/*proc sort data = temp;*/
/*  by date;*/
/*run;*/
/*data time;*/
/*set temp;by date;if first.date then time+1;*keep date time;run;*/
proc sort data = temp;
  by stkcd date;
run;

proc expand data=temp out=temp1 from=month to=month method = none; 
  by stkcd;
  id date; 
  convert beta = beta_lag   / transformout=(lag 1); 
  convert beta = beta_lead  / transformout=(lead 1); 
  convert beta; *必须放，否则beta也会用之前的值去填充;
  convert syn = syn_lag   / transformout=(lag 1); 
  convert syn = syn_lead  / transformout=(lead 1); 
  convert syn;
run; 
data;set temp1;keep stkcd date trdmnt syn mretwd beta:;format date date9.;where beta=.;run;
/*由于先产生syn再产生betalead，所以syn和ret等其他变量都在transform中被插空（复制）了，只有date是插空后的新日期（trdmnt等都不能用）；所以有问题，但是由于beta为空，则回归自动drop这些，但是syn作为y时不会自动drop，所以synlead不能直接在stata里产生*/
*test if ret is missing;
/*data x;set temp;where monret=.;run;*/
/*temp1 is stored in rollbeta*/
