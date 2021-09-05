
global dir "D:\Dropbox\steiner_research\calwater_project\calwater_data_clean"

* Install a regression command that allows us to use multiple fixed effects
// ssc install ftools
// ssc install reghdfe

/*
Load cleaned data from "calwater_cleaning" notebook.
*/
import delimited "$dir/calwater_data.csv", clear

* Basic cleaning to optimize for Stata analysis
gen time_mid = date(reporting_month, "YMD")
gen time = mofd(time_mid)

gen month = month(time_mid)
gen year = year(time_mid)

format time %tm

drop time_mid
replace private = 0 if private == .
replace nonprofit = 0 if nonprofit == .

replace county = "UNKNOWN" if county == ""

gen public = (nonprofit == 0 & for_profit == 0)

gen ownership = 1 if for_profit == 1
replace ownership = 2 if nonprofit == 1
replace ownership = 3 if public == 1

* Assign IDs to relevant groups
egen county_id = group(county)

egen hydro_id = group(hydrologic_region)

egen supplier_id = group(supplier_name county)

egen avg_gpcd = mean(calculated_r_gpcd), by(time)

sort time

/*
Here, we will check for time trends; although there is not a clear increase or
decrease in GPCD over time, there is a very clear seasonal pattern for which
we must control in the upcoming regression analysis.
*/
twoway (line avg_gpcd time), graphregion(color(white)) ///
	ytitle("Average GPCD (monthly)", size(medium)) ylab(, labsize(medsmall)) ///
	xtitle("") xlab(, labsize(medsmall)) title("Average GPCD over Time", size(medium)) ///
	xsize(8) name(avg_gpcd_graph, replace)

xtset supplier_id time

/*
We set the panel to urban water supplier; however, because ownership does not vary
within each supplier we will implement county fixed effects. Suppliers 
within the same geographic area will likely be subject to the same environmental
and demographic constraints, making county an effective proxy while still
allowing ownership to vary.

Additionally, in the final model, we will include month fixed effects in order
to control for the clear seasonal pattern seen in the graph above.

We cluster standard errors around 'supplier_name' because GPCD is not independently
distributed within water suppliers; that is to say, from month to month, water 
suppliers with high GPCD in one month will likely have high GPCD in the next.

We omit for_profit from the definition of the model to avoid the dummy variable
trap. 
*/
reg log_gpcd public nonprofit

reg log_gpcd public nonprofit, vce(cluster supplier_name)

reghdfe log_gpcd public nonprofit, vce(cluster supplier_name) absorb(county_id)

reghdfe log_gpcd public nonprofit, vce(cluster supplier_name) absorb(county_id month)

* No need to control for population or share residential; GPCD is already
* down to individual



predict pred_gpcd, xb

twoway scatter pred_gpcd time


