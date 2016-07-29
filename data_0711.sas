*two proxies for firm-level stock return volatility: the logarithm of squared daily returns (VL) 
in Panel A and the standard deviation of daily squared returns (SD) in Panel B,but they're monthly!
co: user is co_blogger or not,v1 not contains 浏览用户
Markettype [市场类型] - 1=上海A，2=上海B，4=深圳A，8=深圳B,  16=创业板
DNVALTRD is raw amount, size is in 000s;
dm "out;clear;log;clear;";
*SHORT DATA summary by month, label the first month when there's not full month data;
libname ss 'H:\shortsell';
data ss;set ss.ss;ym=mdy(month,1,year);run;
proc means data=ss n mean noprint;
var long short;
class stkcd ym;
output out=ss MEAN=long short N=SHORT_DAYS;
run;


/*proc means mean;*/
/*var x co_num_link;*/
/*run;*/
/*proc means data=coblog.stk_p mean;*/
/*var co_num;*/
/*run;*/

/*rf data is all in percent, so shld /100 */
data roll ;
set xueqiu.day_ret ;
ex_ret=dretwd-rf/100;
ex_ret_m=dretwd-Dretwdos;
ex_mktret=Dretwdos-rf/100;
year=year(date);
ym=mdy(month(date),1,year);
rename dretwd=ret Dretwdos=mktret;
if ex_ret_m>=0 then sign=1;else sign=-1;
volume=sign*DNVALTRD/(10**10);*this is for liquidity beta;
if (markettype=1) then exchg=1;
else if markettype=4 or markettype=16 then exchg=2;
else delete;
keep stkcd ym year date ex_ret ex_ret_m dretwd ex_mktret Dretwdos volume exchg;
where year(date)>2008;
run;
data ff_daily;set xueqiu.FF3_daily;exchg=input(exchflg,3.);drop exchflg;
where exchflg ne '0' & mktflg='A';run;
proc sort; by exchg date;

PROC IMPORT OUT= per_share
DATAFILE= "H:\GTA\Ratio\FI_T9"
DBMS= dbf REPLACE;
Run;
data eps;
set per_share;
date=input(accper,yymmdd10.);
        format date  yymmdd10.;
if month(date)=12 & typrep='A';
year=year(date);
keep stkcd year indcd F090301B;
rename F090301B=eps;
run;
/*Info quality: earnings precision: degree of volatility in earnings*/
proc expand data = eps  out=eps method=none;
    by stkcd;
    id year;
    convert eps = vol_earning  /  transformout=( MOVSTD  5 trimleft  4);
quit;

/*data ratio.value;merge value eps;by stkcd year;run;*/
*get industry for each stk, ind_ret is daily ind ret;
proc sort data=roll; by exchg date;
data roll;merge roll(in=a) ff_daily;by exchg date;if a ;drop mktflg;run;

proc sort data=roll; by stkcd year;
data roll1;merge roll(in=a) eps;by stkcd year;if a & indcd ne "";rename indcd=csrciccd2;run;

proc sort; by csrciccd2 date;
proc sort data=xueqiu.ind_ret; by csrciccd2 date;
data roll_ind;merge roll1(in=a) xueqiu.ind_ret(in=b);by csrciccd2 date;
rename Drettmv=indret;if a & b;run;
proc sort; by stkcd date;

proc expand data=roll_ind  out=delay method = none; 
  by stkcd;
  id date; 
	convert ex_ret_m = exretm_led / transformout=(lead 1); 
	convert indret = ind_lag1   / transformout=(lag 1); 
	convert mktret = mkt_lag1   / transformout=(lag 1); 
	convert mktret = mkt_lag2   / transformout=(lag 2); 
	convert mktret = mkt_lag3   / transformout=(lag 3); 
	convert mktret = mkt_lag4   / transformout=(lag 4); 
	convert mktret = mkt_led1   / transformout=(lead 1); 
	convert mktret = mkt_led2   / transformout=(lead 2); 
run;

/*stambough liquidity*/
/*data stamb;set amihud;volume=DNVALTRD/(1000000);keep stkcd date volume;*/
/*proc sort; by stkcd date;*/
/*proc sort data=delay; by stkcd date;*/
/*data stamb1;merge delay(in=a) stamb(in=b);by stkcd date;if a & b;run;*/

************************core: if there's rsq or rmse, need non sychronous trading correction, can't adjust Rsq;

proc reg data=delay outest=est_beta  noprint edf ;*tableout gets the full regression table;
by stkcd ym;
	model ret = mktret mkt_lag1 mkt_lag2 mkt_lag3 mkt_lag4;
	model ret = mktret ;
	model ex_ret = ex_mktret;
	model ret = mktret mkt_lag1 indret ind_lag1;
	model exretm_led = ret volume;
    model ex_ret=rmrf_tmv smb_tmv hml_tmv;
    model ret=smb_tmv hml_tmv mkt_lag1 mkt_lag2 mktret mkt_led1 mkt_led2;
run;


************************daily delay;

*amihud no mkt ret;
/*  retpos=(ret>0)*abs(ret);*/
/*  retneg=(ret<0 and not missing(ret))*abs(ret);*/

data unr res beta syn stamb ivol1 ivol2;set est_beta;
n=_edf_+_P_ ;
if n>15 & _TYPE_ = 'PARMS';
keep stkcd ym _rmse_ _RSQ_ ex_mktret volume;
if _MODEL_='MODEL1' then output unr;
else if _MODEL_='MODEL2' then output res;
else if _MODEL_='MODEL3' then output beta;
else if _MODEL_='MODEL4' then output syn;
else if _MODEL_='MODEL5' then output stamb;
else if _MODEL_='MODEL6' then output ivol1;
else output ivol2;
run;
data stamb;set stamb;keep stkcd ym volume;
data ivol1;set ivol1;rename _rmse_=ivol_unr;keep stkcd ym _rmse_;
data ivol2;set ivol2;rename _rmse_=ivol_res;keep stkcd ym _rmse_;run;

data syn;set syn;syn=log(_rsq_/(1-_rsq_));
keep stkcd ym syn;run;
data beta;set beta;	
*drop _MODEL_ _TYPE_ _DEPVAR_ _IN_ _P_ n _edf_ ret ex_ret mktret mkt_lag1 mkt_lag2 mkt_lag3 mkt_lag4;
rename _rmse_=Idrisk_std ex_mktret=beta;
keep stkcd ym _rmse_ ex_mktret;
run;
data delay_day;
*_adjrsq_ (_adjrsq_=unr)) res(rename=(_adjrsq_=res)) can't use adjrsq, since it produce negative delay;
merge unr(rename=(_RSQ_=unr)) res(rename=(_RSQ_=res));
by stkcd ym;
pricedelay=1-res/unr;
keep stkcd ym pricedelay;
run;


proc means data=ivol1;
var _RSQ_;run;
proc means data=ivol2;
var _RSQ_;run;
*how good is the estimate: stamb only 10%, while ivol is 50%;
proc means data=stamb;
var _RSQ_;run;

/*
proc means;
var syn;run;
data syn_capm;set beta;syn=log(_rsq_/(1-_rsq_));
keep stkcd ym syn;
proc means;
var syn;run;
capm syn is lower than full model syn(>0), ind included;*/


*res_sas.monret is not complete,use GTA ret_firm, produce annual earnings precision;
data ret_firm;set xueqiu.ret_firm;ym=mdy(month(date),1,year(date));
drop month;*this is text;
run;
proc sort;by stkcd year;
data ret_firm;merge ret_firm eps;by stkcd year;run;

*******************skewness;
proc sort data = roll ;by stkcd ym;
proc summary data = roll noprint;
	var ret;
	by stkcd ym;
	output out = skew skewness = skew max=maxret;
run;

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

proc sort data=beta nodupkey; by stkcd ym; run;
proc sort data=skew nodupkey; by stkcd ym; where stkcd ne "";run;
proc sort data=ret_firm nodupkey; by stkcd ym; run;
proc sort data=ss nodupkey; by stkcd ym; run;
proc sort data=stk_xq nodupkey; by stkcd ym; run;
proc sort data=stk_p5w nodupkey; by stkcd ym; run;
proc sort data=coblog.momentum nodupkey; by stkcd ym; run;
proc sort data=coblog.amihud_AVG nodupkey; by stkcd ym; run;
proc sort data=cc nodupkey; by stkcd ym; run;
/*data why;merge momentum(where=(year>2007)) amihud_AVG;by stkcd ym;*/

*ref_firm has qtr before,coblog1 is from momentum, but shld be with nonmissing y:amihud 
not deal cc now;
data coblog.temp0720;
merge beta coblog.momentum( where=(year>2007)) ret_firm(drop=qtr) p5w.blogfull(in=a) ss(in=s) 
rep1-rep4 coblog.amihud_AVG(drop=_type_ in=c) delay_day syn stamb ivol1 ivol2 skew;
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
turnover=DNVALTRD/(size*10**3);*previous turnover is wrong:volume/size;
lev=1-equity/asset;
run;
PROC exPORT data=coblog.temp0720
outfile= "H:\crash\input\coblog.dta"
DBMS= stata REPLACE;
Run;
Proc Sort noduprec; by _all_;run;
PROC exPORT data=coblog.temp
outfile= "H:\crash\input\coblog.dta"
DBMS= stata REPLACE;
Run;

*annual syn is -0.2 mean;
proc reg data=delay outest=syn_yr  noprint edf ;
by stkcd year;
	model ret = mktret mkt_lag1 indret ind_lag1;
run;
data syn_yr;set syn_yr;
syn=log(_rsq_/(1-_rsq_));
proc means;
var syn;run;

proc print;run;


****************************************************;
*focus on num of dif user, not consider num of cmts yet;
option mprint;
%macro coblog(data,time,user);
proc sql;
create table stk_&data as
select &time,stkcd,count(distinct &user) as num_user_&data,count(&user) as num_cmt_&data
from &data
group by &time, stkcd ;

create table distinct_user as
select distinct &time,stkcd, &user
from &data;
/*proc sort data=&data out=distinct_user nodupkey; by ym stkcd user_ask; run;*/

/*how many stk per user dist_stk*/
create table user_stk as
select &time,&user,count(distinct stkcd) as dist_stk,(count(distinct stkcd)>1) as co,
(count(distinct stkcd)>2) as co2
from &data
group by &time, &user ;

proc sort data=distinct_user;
by &time &user ;
run;

data v1;
merge distinct_user user_stk;
by &time &user ;
run;

proc sql;
create table v1_sum as
select &time, stkcd,sum(co) as co_&data, sum(co2) as co2_&data,avg(dist_stk) as dist_stk_&data label="avg #distinct stk per stk@t" 
from v1
group by &time, stkcd ;

data stk_&data;
merge v1_sum stk_&data;
by &time stkcd ;
if &time ne .;
run;
%mend;
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

*general char of p5w.sum (monthly，only up to 2015/5);
proc sql;
create table blog as
select a.*,b.*
from stk_p5w a full join stk_xq b
on a.ym=b.ym & a.stkcd=b.stkcd
where a.ym ne . & a.stkcd ne "" ;

create table p5w.blogfull as
select a.*,b.*
from blog a full join p5w.sum b 
on year(a.ym)=b.year & month(a.ym)=b.month & a.stkcd=b.stkcd
where a.stkcd ne ""  ;
/* Sanity Checks for Duplicates - Ultimately, Should be 0 Duplicates */
proc sort data=p5w.blogfull nodupkey; by stkcd ym; run;


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
DATA coblog.momentum;SET momentum;rename date=ym;
label RET    = "Stock Return of current Month ";
label RET_3  = "Stock Return of Last 3 Months ";
label RET_6  = "Stock Return of Last 6 Months ";
label RET_9  = "Stock Return of Last 9 Months ";
label RET_12 = "Stock Return of Last 12 Months ";
label Tot_Vol_mv  = "Total Stock Return Volatility in the Last 24 Months";


data amihud;
set xueqiu.day_ret;
where year(date)>2007;
amihud=abs(DRETWD)*100000000/DNVALTRD;*DNVALTRD is raw amount, ret in percentage and divide by 10,0000;
ym=mdy(month(date),1,year(date));
proc means   ;
var amihud ;
run;
proc means data=amihud mean noprint;
var amihud DRETWD;
class stkcd ym;
output out=coblog.amihud_AVG mean(amihud)=amihud std(DRETWD)=tot_vol;
run;
*need to change _type_ when changed to ym;
proc sort data=coblog.amihud_AVG(where=(_TYPE_=3) rename=(_freq_=num_trdday)) nodupkey;
by stkcd ym;

data v;set xueqiu.day_ret(obs=10);
x=Dnshrtrd* clsprc/DNVALTRD;
proc print;var x;run;
/*proc export data=amihud_AVG*/
/*outfile= "H:\crash\input\amihud.dta"*/
/*DBMS= stata REPLACE;*/
/*Run;*/
proc contents data=xueqiu.day_ret;
proc contents data=rollbeta.ret;run;
/*solve the discrepancy and frame into one,rollbeta.ret from resset,mkt ret needs to do by one self*/
data day_mkt;set xueqiu.day_mkt;date=input(Trddt,yymmdd10.);
format date yymmdd10.;drop trddt;
proc sort data=xueqiu.day_ret;
by markettype date;
data xueqiu.day_ret ;
length markettype 3.TRDSTA 3. ;format markettype 3.TRDSTA 3. date yymmdd10.;
merge xueqiu.day_ret day_mkt;
by markettype date;
run;
proc sort data=xueqiu.day_ret;
by date;
data xueqiu.day_ret ;
merge xueqiu.day_ret(in=a) xueqiu.day_rf(keep=rf date);
by date;if a;
run;
