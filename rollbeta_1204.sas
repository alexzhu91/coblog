****************this is th old version of rolling 60 days every 30 days
/*rollbeta.beta_60(30) is from the stk pool of p5w*/
libname rollbeta "F:/rollbeta";
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
merge rollbeta.ret stk_1st;
by stkcd;
if intck('month',date,date_1st)<5 & dretwd ne .;
/*最早的月份要隔5个月*/
format date date9.;
run;


data roll;
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
%rollbeta(data=roll,wlength=30,result=beta_30);

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
run;
proc sort data=rep&i;
by stkcd ym;
%end;
%mend rep;
%rep;

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
PROC exPORT data=coblog.reg_full
outfile= "J:\work\coblog\reg.dta"
DBMS= stata REPLACE;
Run;


