libname rollbeta "B:/rollbeta";
data x;
set rollbeta.ret(obs=5000);format date yymmdd10.;run;
proc sql;
create table weekrtn as
select stkcd,  intnx("week.7", date, 0, "end") as week format=mmddyy10., 
exp(sum(log(1+dretwd-rf/100))) - 1 as weekret format=percentn8.2,
exp(sum(log(1+dretwdos-rf/100))) - 1 as mktret format=percentn8.2
from x
group by stkcd, calculated week;
quit;
proc expand data=weekrtn out=week from=week to=week method = none; 
  by stkcd;
  id week; 
convert mktret = mktret;
convert weekret = weekret;
  convert mktret = mkt_lag1   / transformout=(lag 1); 
  convert mktret = mkt_lag2   / transformout=(lag 2); 
  convert mktret = mkt_lag3   / transformout=(lag 3); 
  convert mktret = mkt_lag4   / transformout=(lag 4); 
run;
data week1;
set week;where mktret ne .;year=year(week);
/*ods output FitStatistics = fitstats;*can't used with noprint;*/
/* proc reg data=week1 plots=diagnostics(stats=(default ADJRSQ nobs ));*/
/*      model weekret = mktret mkt_lag1 mkt_lag2 mkt_lag3 mkt_lag4;*/
/*by stkcd year;*/
/*   run;*/

proc reg data=week1 outest=est_unr ADJRSQ noprint  edf;
      model weekret = mktret mkt_lag1 mkt_lag2 mkt_lag3 mkt_lag4;
	  model weekret = mktret ;
by stkcd year;
   run;
data unr;set est_unr;
if _TYPE_ = 'PARMS';
if _MODEL_='MODEL1' then n=_edf_+6;else n=_edf_+2;
keep stkcd year _MODEL_ _rsq_ n _edf_ _adjrsq_;
run;

********************************alternative;
proc print;run;
data y;set x;
if 2 le weekday(date) le 6;
  endofweek = INTNX( 'WEEK', date, 0, 'E' )-1;
format endofweek date9.;
run;
proc summary data=y (drop=date rename=(endofweek=date))  nway;
  var dretwd;
  class stkcd date;
  output out=want  sum=weekret;
run;

********************************sth wrong;
 data y;set x;_id=cats(date,week(date));
data weekrtn1 ;
  do until (last._id);
    set y;
	retain _total;
     by _id;
     if first._id then _total=1;
     _total=_total*(1+dretwd);
     end;
     Week_ret=_total-1;
run;


