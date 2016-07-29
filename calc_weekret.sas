libname crash "H:\peer";
/*week1.2 is shifting the interval by 2 days forward, from one benchmark you can derive all the 
cycles. m means middle*/
proc sql;
********below is from Wed to next Wed(week.7 is from Tue to next Tue);
create table weekrtn as
select permco,intnx("week.1", date, 0, "m") as week format=yymmdd10., 
exp(sum(log(1+ret))) - 1 as ret format=percentn8.2
from  crash.ret
group by permco, calculated week;
********below is from Fri to next Fri(week.5 is from Wed to next Wed);
create table weekrtn1 as
select permco,intnx("week.7", date, 0, "end") as week format=yymmdd10., 
exp(sum(log(1+ret))) - 1 as ret format=percentn8.2
from  crash.ret
group by permco, calculated week;
quit;

data _null_;week=intnx('week1.2', '01FEB2010'd, 1);format week yymmdd10.;put week;run;
