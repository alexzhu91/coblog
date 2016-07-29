
libname rollbeta "B:/rollbeta";
Proc import datafile="J:\data\dayret\TRD_Dalym.xls"
out=xueqiu.day_mkt
dbms=xls replace;
getnames=yes;
run;
Proc import datafile="J:\data\dayret\TRD_Nrrate.xlsx"
out=xueqiu.day_rf
dbms=xlsx replace;
getnames=yes;
run;
proc sort data=xueqiu.day_mkt;
by markettype trddt;
proc sort data=xueqiu.day_ret;
by markettype trddt;
data xueqiu.day_rf;
set xueqiu.day_rf;
date=input(var2,yymmdd10.);
rename var4=rf;
data ret;
merge xueqiu.day_ret(in=a) xueqiu.day_mkt;
by markettype trddt;
date=input(trddt,yymmdd10.);
year=year(date);
month=month(date);if a;
proc sort data=ret;
by date;

data rollbeta.ret;
merge ret(in=a) xueqiu.day_rf;
by date;if a;
keep date year month stkcd dretwd rf Dretwdos;run;
/*>24个月discussion data？*/
data coblog.stk_24;
set coblog.stk;
by stkcd ym;
format ym yymmdd.;
if first.stkcd then n=0;n+1;
if last.stkcd & n>23 then output;
run;

data stk_1st;
set coblog.stk;
by stkcd ym;
format ym yymmdd10.;
if first.stkcd;
rename ym=date_1st;
keep stkcd ym;
run;

proc sql;
/*里面有哪些不够12个月？*/
create table qualified_stk as
select stkcd,count(stkcd) as obsnum from rollbeta.ret
group by stkcd
having calculated obsnum>250;
/*最终股票*/

create table roll as
select * from rollbeta.ret
where stkcd in (select distinct stkcd from coblog.stk_24) & stkcd in (select stkcd from qualified_stk);
/*if forgot to select, use beta1*/
/*create table beta1 as*/
/*select * from beta where stkcd in (select distinct stkcd from roll);*/
proc sort data=roll;
by stkcd date;

data roll_1st;
merge roll stk_1st;
by stkcd;
if intck('month',date,date_1st)<5 & dretwd ne .;
/*最早的月份要隔5个月*/
format date date9.;
run;

data xueqiu.roll;
set roll_1st end=eof;
by stkcd date;
ret=dretwd-rf;
mkt_ret=Dretwdos-rf;
retain n 0;
if first.stkcd then n=n+1;
if eof then do;
      call symput('stkno', n);
   end;
keep stkcd date year month n ret mkt_ret;
run;


**********************************************************************************************************************
data 按照我发你的样本 变量名字和顺序都要一致 date日期（sas）要能识别 ret是要算的股票的收益 mkt_ret是市场收益
wlength 向前取的天数
result 输出结果
未考虑前60个交易日中间停牌的情况，考虑了之前不足60个交易日的情况
也可以取前3个月，剔除3个月小于50个交易日的情况
**********************************************************************************************************************;

%macro rollbeta(data=,wlength=,result=);
%do t=1 %to 542;
dm 'cle log;';

* Calculate the loops needed for rolling regression;
data _0;
set &data;
 where n=&t;

data a;
set _0;
by year month;
 if first.month then lab=1;else lab=0;
   count1+lab; /*求和*/
   run;

data b;
 set a;
 by year month;
   if first.month then count=count1-int(&wlength/20)-1;else count=0;
   keep date ret mkt_ret count stkcd;
run;

/*data c;*/
/*set b ;*/
/*call symput('ntotal',max(_n_));*/
/*run;*/


data c;
set b nobs = nobs end=eof;
if eof then call symput('ntotal',nobs);
run;

proc sql noprint;
select max(count) into :nloop 
from b;
/*select max(_n_) into :ntotal*/
/*from &data;*/
quit;

proc iml;
use b;
read all var{date ret mkt_ret count} into raw;

x=j(&wlength,1,0);
y=j(&wlength,1,0);
beta=j(&nloop,2,0);
std=j(&nloop,1,0);
/*stkcdb=stkcd[1:&nloop,1];*/
do i=1 to &nloop;
   do j=1 to &ntotal;
      if raw[j,4]=i then 
         do;
            x=raw[j-&wlength:j-1,3];
            y=raw[j-&wlength:j-1,2];
            beta[i,1]=raw[j,1];
         end;
	std[i,1]=std(y);
      xtran=x`;
      xx=xtran*x;
      if xx^=0 then
      beta[i,2]=inv(xx)*xtran*y;
      else
      beta[i,2]=.;
   end;        
end;

res=beta||std;
create temp from res[colname={'date' 'beta' 'std'}];
append from res;
close temp;
quit;


proc sql noprint;
create table imlout as select a.*, b.stkcd from
temp as a left join b as b
on a.date=b.date;
quit;

%if &t=1 %then %do;
data &result;
set imlout;format date date9.;run;
%end;

%else %do;
proc append base=&result data=imlout;run;
%end;

%end;

/*house cleaning */
      proc sql; drop table a, b, c,imlout,_0,temp;quit;

%mend rollbeta;
%rollbeta(data=xueqiu.roll,wlength=30,result=res);
data beta_30;
set res;
ym=mdy(month(date),1,year(date));
where beta ne 0 & beta ne .;
proc sort data=beta_30;
by stkcd ym;

%rollbeta(data=xueqiu.roll,wlength=60,result=res);
data beta_60;
set res;
ym=mdy(month(date),1,year(date));
where beta ne 0 & beta ne .;
proc sort data=beta_60;
by stkcd ym;

data coblog.stk_ret;
merge beta_30(in=a rename=(beta=beta_30 std=std_30)) beta_60(in=b) coblog.stk(in=c);
by stkcd ym;if  b & c;
run;

proc corr data=coblog.stk_ret cov;
   var co_p co_x hot_p hot_x beta std;
run;

proc rank data=coblog.stk_ret out=stk_ret ties=low;
   var co_p co_x hot_p hot_x beta std ;
   ranks p x hp hx b sd;
run;

proc corr data=stk_ret cov;
   var p x hp hx b sd;
run;

proc npar1way data=coblog.stk_ret wilcoxon;  
*class cent_soe;
var co_x beta;
run;


/*30 & 60 days, hot_p is dropped as the same with co_p */
ods output clear;
proc corr data=coblog.stk_ret pearson spearman;
   var co_p co_x hot_x beta std beta_30 std_30;
   where beta_30 ne .;
run;

proc rank data=coblog.stk_ret out=stk_ret ties=low;
   var co_p co_x hot_x beta std beta_30 std_30 ;
   ranks p x hx b sd b_30 sd_30;
   where beta_30 ne .;
run;

proc corr data=stk_ret pearson spearman;
   var p x hx b sd b_30 sd_30;
run;
