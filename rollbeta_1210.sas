*derive week return;
proc expand data=weekrtn out=week from=week to=week method = none;
  by stkcd;
  id week;
convert mktret = mktret;
convert weekret = weekret;
  convert mktret = mkt_lag1   / transformout=(lag 1);
  convert mktret = mkt_lag2   / transformout=(lag 2);
  convert mktret = mkt_lag3   / transformout=(lag 3);
run;
/*rollbeta.beta_60(30) is from the stk pool of p5w*/
libname rollbeta "B:/rollbeta";
proc sort data=coblog.stk_p;
by stkcd ym;
data stk_1st;
set coblog.stk_p;
by stkcd ym;
format ym yymmdd10.;
if first.stkcd;
rename ym=date_1st;
keep stkcd ym;
where ym ne .;
run;

proc sort data=rollbeta.ret;
by stkcd;


data roll_1st;
merge rollbeta.ret stk_1st(in=a);
by stkcd;
if a;
if date>=date_1st & dretwd ne .;
format date date9.;
run;

proc sort data=roll_1st;
by stkcd year month;


data roll ;
set roll_1st end=eof;
by stkcd year month;
retain n 0;
if first.month then n=n+1;
ret=dretwd-rf/100;
*ret_old=dretwd-rf;
mkt_ret=Dretwdos-rf/100;
*mkt_ret_old=Dretwdos-rf; *test found no dif in rsq or beta if using the wrong rf;
if eof then do;
      call symput('stkno', n);
   end;
keep stkcd year month date n ret mkt_ret;
run;
proc sql;
create table stkcd as select stkcd, year, month,max(n) as n,count(date) as no
from roll 
group by stkcd, year, month;
data final;
merge roll stkcd(in=a);
by stkcd year month;if a;
run;
/*rollbeta.final=alex.final*/
proc reg data=final outest=est_beta  noprint  TABLEOUT;
by n;
model ret = mkt_ret;
where no>12;
run;


data rollbeta.coef_12;
set Est_beta;
if _TYPE_ = 'PARMS';
drop _MODEL_ _TYPE_ _DEPVAR_ _IN_ _P_ ret;
rename _rmse_=Idrisk_std mkt_ret=beta;
run;
*******************after calc,no need to retain coef_20 since it can be derive from coef if no>20****************;

data rollbeta.newbeta_12;
merge rollbeta.coef_12(in=a) stkcd;
by n;if a;run;

%let var=ret;
%let interval=3;
*res_sas.monret is not complete,use GTA ret_firm;
data ret_firm;set xueqiu.ret_firm;
mth=input(month,3.);drop month; rename mth=month;run;
data stk_p;set coblog.stk_p;year=year(ym);month=month(ym);
proc sort;
by stkcd year month;
/*data monret;set res_sas.monret;*/
/*proc sort data=monret;*/
/*by stkcd year month;*/
data r1;
set ret_firm;by stkcd year month;
&var=log(1+mretwd);
if first.stkcd  then do;
n=1;
sum_&var.=&var.;
end;
else do;
n+1;
sum_&var.+&var.;
end;
/*if n=&interval then do;*/
/*mean_&var.=sum_&var./&interval.;*/
/*output;*/
/*end;*/
run;
data r2;
set r1;by stkcd year month;
ret6_0=lag(sum_ret)-lag7(sum_ret);ret3_0=lag(sum_ret)-lag4(sum_ret);ret12_0=lag(sum_ret)-lag13(sum_ret);
if n>3;keep stkcd year month csrciccd2 monret ret6_0 ret12_0 ret3_0;run;
proc sort data=xueqiu.ret_firm;
by stkcd year month;

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
month=month(repdt&i._);
year=year(repdt&i._);
keep stkcd year month repdt&i._;
run;
proc sort data=rep&i;
by stkcd year month;
%end;
%mend rep;
%rep;

data temp;
merge r2 rollbeta.newbeta_12(in=b) ret_firm stk_p(in=a) rep1 rep2 rep3 rep4 ;
by stkcd year month;if b;
coblog=a;run;

/*data r;set r2;where ret3_0=.;run;*/
data temp;
set temp;
lnsize=log(size);
if co_num=. then co_num=0;
if num_blogger=. then num_blogger=0;
syn=log((1-_rsq_)/_rsq_);drop _edf_ n;
turnover=volume/size*10**3;
*volume is in 1000s;
run;
/*proc sort data = temp;*/
/*  by date;*/
/*run;*/
/*data time;*/
/*set temp;by date;if first.date then time+1;*keep date time;run;*/
proc sort data = temp;
  by stkcd date;
run;

proc expand data=temp out=rollbeta.temp1 from=month to=month method = none; 
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
PROC exPORT data=rollbeta.temp1
outfile= "J:\work\coblog\reg3.dta"
DBMS= stata REPLACE;
Run;
*test if beta was right;
/*proc sort data = rollbeta.reg4;*/
/*  by stkcd date;*/
/*run;*/
/*data try;merge rollbeta.reg4(keep=stkcd date syn) rollbeta.temp1(keep=stkcd date syn rename=(syn=syn_new));*/
/*  by stkcd date; run;*/

*From Stata;
PROC imPORT out=rollbeta.reg4
datafile= "J:\work\coblog\reg3.xlsx"
DBMS= EXCEL REPLACE;
GETNAMES=Yes;
Run;

data rollbeta.reg4;set beta(drop=id);rename beta_lea=beta_lead co_demea=co_demean lnnum_bl=lnnum_blogger rep_co_r=rep_co_rank rep_co_d=rep_co_demean;run;
%include "C:\Users\alex\Documents\My SAS Files\9.3\spring\macbeth\fmreg_macro.sas";
%macro reg(y,data);
 %FM_piece (INSET=&data,OUTSET=reg_result1,DATEVAR=date,DEPVAR=&y, INDVARS=co_rank lnnum_blogger  turnover lnsize bm mretwd ret3_0,LAG=1);
 %FM_piece (INSET=&data,OUTSET=reg_result2,DATEVAR=date,DEPVAR=&y, INDVARS=lnco lnnum_blogger  turnover lnsize bm mretwd ret3_0,LAG=1);
 %FM_piece (INSET=&data,OUTSET=reg_result3,DATEVAR=date,DEPVAR=&y, INDVARS=co_demean lnnum_blogger  turnover lnsize bm mretwd ret3_0,LAG=1);
 %FM_piece (INSET=&data,OUTSET=reg_result4,DATEVAR=date,DEPVAR=&y, INDVARS=co_rank rep rep_co_rank lnnum_blogger  turnover lnsize bm mretwd ret3_0,LAG=1);
 %FM_piece (INSET=&data,OUTSET=reg_result5,DATEVAR=date,DEPVAR=&y, INDVARS=lnco rep rep_lnco lnnum_blogger  turnover lnsize bm mretwd ret3_0,LAG=1);
 %FM_piece (INSET=&data,OUTSET=reg_result6,DATEVAR=date,DEPVAR=&y, INDVARS=co_demean rep rep_co_demean lnnum_blogger  turnover lnsize bm mretwd ret3_0,LAG=1);
%mend;
%reg(beta_lead,rollbeta.reg4);%reg(beta,rollbeta.reg4);%reg(beta_lag,rollbeta.reg4);
%reg(syn_lead,rollbeta.reg4);%reg(syn,rollbeta.reg4);%reg(syn_lag,rollbeta.reg4);
data reg4;set rollbeta.reg4;where coblog=1;
%reg(beta_lead,reg4);%reg(beta,reg4);%reg(beta_lag,reg4);
%reg(syn_lead,reg4);%reg(syn,reg4);%reg(syn_lag,reg4);





data rollbeta.beta_30;
set beta_30;
ym=mdy(month(date),1,year(date));
where beta ne 0 & beta ne .;

proc sort data=rollbeta.beta_30;
by stkcd ym;
data monret;
set res_sas.monret;
ym=mdy(month,1,year);
proc sort data=monret;
by stkcd ym;
/*proc sql;*/
/*create table reg as */
/*select ;*/
proc sort data=coblog.stk_p(drop=hot_num);
by stkcd ym;



data i;set repar;if stkcd='000603';run;

data reg;
merge monret rollbeta.beta_30(in=a) rep1 rep2 rep3 rep4 coblog.stk_p(in=b);;
by stkcd ym;
if b & monret ne .;
run;



%rollbeta(data=roll,wlength=60,result=beta_60);
data rollbeta.beta_60;
set beta_60;
ym=mdy(month(date),1,year(date));
where beta ne 0 & beta ne .;

proc sort data=rollbeta.beta_60;
by stkcd ym;

data coblog.reg_full;
merge reg(in=a) rollbeta.beta_60(rename=(beta=beta_60 std=std_60));by stkcd ym;
if a;
run;


