
libname rollbeta "B:/rollbeta";
Proc import datafile="B:\rollbeta\raw.xls"
out=rollbeta.raw
dbms=xls replace;
getnames=yes;
run;

/*This code for multifactor w/o rf rate*/
proc sort data=xueqiu.day_mkt;
by markettype trddt;
proc sort data=xueqiu.day_ret;
by markettype trddt;

data rollbeta.ret;
merge xueqiu.day_ret xueqiu.day_mkt;
year=year(date);
month=month(date);


proc sql;
/*里面有哪些不够24个月？*/
create table qualified_stk as
select stkcd,count(stkcd) as obsnum from rollbeta.ret
group by stkcd
having calculated obsnum>250;
/*最终股票*/

create table roll as
select * from res_sas.monret
where stkcd in (select distinct stkcd from coblog.stk) & stkcd in (select stkcd from qualified_stk);
/*if forgot to select, use beta1*/
/*create table beta1 as*/
/*select * from beta where stkcd in (select distinct stkcd from roll);*/

data roll;
set roll end=eof;
by stkcd year;
ret=monret-monrfret;
mkt_ret=mrettmv-monrfret;
retain n 0;
if first.stkcd then n=n+1;
if eof then do;
      call symput('stkno', n);
   end;
keep stkcd date n  ret mktret;
where date>mdy(9,1,2008);run;


**********************************************************************************************************************
data 按照我发你的样本 变量名字和顺序都要一致 date日期（sas）要能识别 stock是要算的股票的收益 mkt_ret是市场收益
wlength 向前取的天数
result 输出结果
未考虑前60个交易日中间停牌的情况，考虑了之前不足60个交易日的情况
**********************************************************************************************************************;

%macro rollbeta(data=,wlength=,result=);
%do t=1 %to &stkno;
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
   if first.month then count=count1-&wlength/20-1;else count=0;
   keep date ret mkt_ret count;
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
do i=1 to &nloop;
   do j=1 to &ntotal;
      if raw[j,4]=i then 
         do;
            x=raw[j-&wlength:j-1,3];
            y=raw[j-&wlength:j-1,2];
            beta[i,1]=raw[j,1];
         end;
      xtran=x`;
      xx=xtran*x;
      if xx^=0 then
      beta[i,2]=inv(xx)*xtran*y;
      else
      beta[i,2]=.;
   end;        
end;

create temp from beta[colname={'date' 'beta'}];
append from beta;
close temp;
quit;

%if &t=1 %then %do;
data &result;
set temp;format date date9.;run;
%end;

%else %do;
proc append base=&result data=temp;run;
%end;

%end;
%mend rollbeta;
%rollbeta(data=rollbeta.raw,wlength=60,result=res);
