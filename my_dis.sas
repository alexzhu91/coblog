proc sort data=xueqiu.analyst nodupkey out=analyst;
by stkcd fenddt BROKERCD descending rptdt;
run;

data analyst;
set analyst;
if feps ne .;
repdate=input(rptdt,yymmdd10.);
month=month(repdate);
year=year(repdate);
reportdt=mdy(month,'1',year);
format repdate yymmdd10. reportdt yymmn.;;
keep stkcd BROKERCD reportdt rptdt date feps meps;

proc sort data = analyst;
  by stkcd BROKERCD reportdt;
  where year(date)>2007 ;
run;
Proc Sql;
create table Base
  as select *, count(distinct reportdt) as num from analyst 
group by stkcd, BROKERCD,date
having calculated num>3
order by stkcd, BROKERCD,date, reportdt;
*ABOVE NODUP ONLY DELETE RECORDS ON THE SAME REPDATE, NOT MONTH;
Proc Sort data=analyst nodupkey; by stkcd BROKERCD date reportdt  ;run;
proc expand data=base(keep=stkcd BROKERCD reportdt date  feps) out=feps to=month method=step ; 
  by stkcd BROKERCD date;
  *convert feps=feps;
  id reportdt; 
run; 
/*can't do meps same way, since lots of 2016,2017, and direct merge will do;*/
data x;set feps;where intnx('month',date,-8,'E')<=reportdt<intnx('month',date,4,'E');run;

PROC IMPORT OUT= per_share
DATAFILE= "H:\GTA\Ratio\FI_T9"
DBMS= dbf REPLACE;
Run;
data eps;
set per_share;
date=input(accper,yymmdd10.);
        format date  yymmdd10.;
if month(date)=12 & typrep='A';
keep stkcd date F090301B;
rename F090301B=eps;
run;

proc sql;
create table anal as
select a.*,b.*,a.feps-b.eps as forecast_error
from x a left join eps b
on a.date=b.date & a.stkcd=b.stkcd;
/*MEPS=每股收益=归属于母公司所有者的净利润/对应期末普通股股数=F090301B */
proc means ;
var forecast_error;
run;
/*ensure you match the exact fiscal date for each reporting month
since in 201001 can establish 2010 eps, it can be error if next month eps is missing and for 2009 FY*/
Proc Sort data=anal; by stkcd reportdt  ;run;

proc means data = ANAL mean median maxdec=3 std N noprint;
OUTPUT OUT = forec_summary N(feps)= coverage mean(feps)= avgforecast 
std(feps)= dispersionforecast median(feps)= medianofforecast mean(forecast_error) = aveforecasterror ; 
var feps forecast_error; /*calculate average forecast error for a perticular firm and perticular quarter*/
by stkcd reportdt;
run;
