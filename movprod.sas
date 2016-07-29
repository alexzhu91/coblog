data x;set xueqiu.ret;keep stkcd date monret;
rename monret=ret;drop if _obs=2;run;
proc sort;by stkcd date;
/* Use this step to fill the gaps of missing monthly observations
To interpolate missing values in time series without converting the observation frequency, leave off the TO= option on the PROC EXPAND statement. For example, the following statements interpolate any missing values in the time series in the data set ANNUAL. 
   proc expand data=annual out=new from=year;
      id date;
      convert x y z;
      convert a b c / observed=total;
   run;

This example assumes that the variables X, Y, and Z represent point-in-time values observed at the beginning of each year. (The default value of the OBSERVED= option is OBSERVED=BEGINNING.) The variables A, B, and C are assumed to represent annual totals. 
To interpolate missing values in variables observed at specific points in time, omit both the FROM= and TO= options and use the ID statement to supply time values for the observations. The observations do not need to be periodic or form regular time series, but the data set must be sorted by the ID variable. For example, the following statements interpolate any missing values in the numeric variables in the data set A. 
   proc expand data=a out=b;
      id date;
   run;
If the observations are equally spaced in time, and all the series are observed as beginning-of-period values, only the input and output data sets need to be specified. For example, the following statements interpolate any missing values in the numeric variables in the data set A using a cubic spline function, assuming that the observations are at equally spaced points in time. 
   proc expand data=a out=b;
   run;
PROC EXPAND requires a return time series with continuous date intervals and won't give you a missing automatic
so do it beforehand: if do from=month in the next proc expand, then it fills missing t with the value of t+1*/

proc expand data = x(obs=10 where=(ret ne -.0594)) from=month out=y method=none;
    by stkcd;
    id date;
quit;
proc expand data = y  out=z method=none;
    by stkcd;
    id date;
    convert RET = RET_3  / transformin=(+1) transformout=( MOVPROD  3 -1 trimleft  2);
quit;
proc print;run;
/*trim less is enough, movprod contains the current t obs
directly use from=month to=month in this convert will cause ret to be non missing, so better do it before
but convert will gen the correct mvsum and ignore the missing month*/
proc expand data = x(obs=10 where=(ret ne -.0594)) from=month out=y method=none;
    by stkcd;
    id date;
    convert RET = RET_3  / transformin=(+1) transformout=( MOVPROD  3 -1 trimleft  2);
/*	convert RET = RET_6  / transformin=(+1) transformout=(MOVPROD  6 -1 trimleft  6);*/
/*	convert RET = RET_9  / transformin=(+1) transformout=(MOVPROD  9 -1 trimleft  9);*/
/*	convert RET = RET_12 / transformin=(+1) transformout=(MOVPROD 12 -1 trimleft 12);*/
quit;
proc print;run;

/*ALTERNATIVE FOR ABOVE*/

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
if n>3;keep stkcd year month ret6_0 ret12_0 ret3_0;run;
