libname ss 'H:\shortsell';
proc sql;
create table sample as
select *,count(stkcd) as trd_day
from ss.ss 
group by stkcd,year, month
having calculated trd_day>15;
create table mkt_avg as
select *,avg(short) as short_m,avg(long) as long_m
from sample 
group by ss_date;
run ;


****************************correlation********************;

proc means data=ss_ret mean noprint;
var ret_dif long_dif short_dif;
class n;
output out=ss_mean mean=ret_dif ss_dif fin_dif;
run;
proc sort data=mkt_avg;   by stkcd year month;
proc corr data=mkt_avg  noprint outp=cor; 
   var  short long ;
   with short_m long_m;
   by stkcd year month;
   *where year=2011;
run;

data cor1 cor2;set cor;if _type_='CORR' then do;
if _NAME_='long_m' then output cor1;
else if
_NAME_='short_m' then output cor2;keep stkcd year month short;
end;
run;

data cor_m;merge cor1(keep=stkcd year month long) cor2(keep=stkcd year month short) ;
   by stkcd year month;
run;

****************************alternative: beta********************;

proc reg data=mkt_avg outest=beta_coshort ADJRSQ noprint  edf;
      model short = short_m;
      model long = long_m;
by stkcd year month;
   run;
data b1 b2;set beta_coshort;if _model_='MODEL1' then do;
keep stkcd year month short_m ;output b1;
end;
else do;
keep stkcd year month long_m ;output b2;
end;
run;
data beta_m;merge b1(keep=stkcd year month short_m) b2(keep=stkcd year month long_m) ;
   by stkcd year month;rename short_m=short_beta long_m=long_beta;
run;

proc sort nodup data=coblog.stk_p;by  stkcd ym;
proc sort nodup data=coblog.stk_x;by  stkcd ym;
/*take the full part of both dataset*/
data xp;merge coblog.stk_p(rename=(co_num=co_p num_blogger=blogger_p) in=a) coblog.stk_x(rename=(co_num=co_x num_blogger=blogger_x) in=b);
by stkcd ym;drop _type_;
p=a;x=b;
array arr1 _numeric_;
do over arr1;
if arr1=. then arr1=0;end;
if stkcd ne '';
year=year(ym);month=month(ym);
run;

data final;merge xp cor_m(in=a) beta_m; rename short=short_cor long=long_cor;  by stkcd year month;
shortsell=a;run;
****************************controls********************;

data ret;set xueqiu.ret_firm(rename=(month=month1));
r=log(1+mretwd);lev=1-equity/asset;month=input(month1,3.);qtr=qtr+1;
turnover=volume/size*10**3;drop month1;run;
PROC exPORT data=ret 
outfile= "H:\coshort\control.dta" 
DBMS= stata REPLACE ;
Run;
PROC exPORT data=final 
outfile= "H:\coshort\coshort.dta" 
DBMS= stata REPLACE ;
Run;

PROC imPORT out= ss2
           dataFILE= "H:\SDC\cash\flag.txt" 
            DBMS=dlm REPLACE;
			delimiter='    ';
RUN;



定下变量后再输入，尽量避免带空格的
