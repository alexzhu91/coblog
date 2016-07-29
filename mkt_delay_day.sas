libname rollbeta "B:/rollbeta";
data a;
set rollbeta.ret(obs=5000);format date yymmdd10.;run;
proc sql;
create table weekrtn as
select stkcd,  intnx("week.7", date, 0, "end") as week format=mmddyy10., 
exp(sum(log(1+dretwd-rf/100))) - 1 as weekret format=percentn8.2,
exp(sum(log(1+dretwdos-rf/100))) - 1 as mktret format=percentn8.2
from x
group by stkcd, calculated week;
quit;
proc expand data=a out=week method = none; 
  by stkcd;
  id date; 
convert dretwdos = mktret;
convert dretwd = ret;
  convert dretwdos = mkt_lag1   / transformout=(lag 1); 
  convert dretwdos = mkt_lag2   / transformout=(lag 2); 
  convert dretwdos = mkt_lag3   / transformout=(lag 3); 
  convert dretwdos = mkt_lag4   / transformout=(lag 4); 
run;

proc reg data=week outest=est_unr ADJRSQ noprint  edf;
      model ret = mktret mkt_lag1 mkt_lag2 mkt_lag3 mkt_lag4;
	  model ret = mktret ;
by stkcd year month;
   run;
data unr;set est_unr;
if _TYPE_ = 'PARMS';
if _MODEL_='MODEL1' then do;
n=_edf_+6 ;
adjr=_adjrsq_;
end;
else do;
n=_edf_+2;
adjr=-_adjrsq_;
keep stkcd year month _MODEL_ n adjr;
end;
run;

proc means data=unr sum noprint;
var adjr;by stkcd ;output out=r2 sum=r2;
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


