

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
   if first.month then count=count1-&wlength/20-1;else count=0;
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
%mend rollbeta;
%rollbeta(data=xueqiu.roll,wlength=30,result=res);
