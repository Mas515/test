//Adapted by Marine Secchi, last update 12/10/2022
///https://imagej.net/scripting/batch used to batch this macro

/*
Fast4DReg is a Fiji macro for drift correction of 3D videos or 
channel alignment in 3D multichannel image stacks. Drift or 
misalignment can be corrected in all x-, y- and/or z-directions. 

Time estimate+apply script estimates the drift between frames in 
a 3D video and applied the correction to the same dataset. 

Fast4DReg is dependent on the NanoJ-Core plugin and Bioformats.
If you use this script in your research, please cite our pre-print and 
Laine, R. F. Et al 2019. NanoJ: a high-performance open-source super-resolution 
microscopy toolbox, doi: 10.1088/1361-6463/ab0261.

Authors: Joanna W Pylvänäinen and Romain F Laine
version: 1.0 (preprint)
Licence: MIT
*/

run("Close All");
print("\\Clear");

input=getDir("Get input directory");
results=getDir("Get input directory");

run("Collect Garbage");

// give experiment number
#@ Integer (label="Experiment number", value=001, style="format:000") exp_nro ;

// select file to be corrected
//#@ File (label="Select the file to be corrected", style="open") my_file_path ;
#@ File () my_file_path ;

//settings for xy-drif correction
#@ String  (value="-----------------------------------------------------------------------------", visibility="MESSAGE") hint1;
#@ boolean (label = "<html><b>xy-drift correction</b></html>") XY_registration ; 
#@ String(label = "Projection type", choices={"Max Intensity","Average Intensity"}, style="listBox") projection_type_xy ;

#@ Integer (label="Time averaging (default: 100, 1 - disables)", min=1, max=100, style="spinner") time_xy ;

#@ Integer (label="Maximum expected drift (pixels, 0 - auto)", min=0, max=auto, style="spinner") max_xy ;

#@ String (label = "Reference frame", choices={"first frame (default, better for fixed)" , "previous frame (better for live)"}, style="listBox") reference_xy ;

#@ boolean (label = "Crop output") crop_output ; 
#@ String  (value="<html><i> Cropping output will be enabled automatically when continuing to z-correction.</i></html>", visibility="MESSAGE") hint2;


//settings for z-drift correction
#@ String  (value="-----------------------------------------------------------------------------", visibility="MESSAGE") hint3;
#@ boolean (label = "<html><b>z-drift correction</b></html>") z_registration ; 
#@ String(label = "Projection type", choices={"Max Intensity","Average Intensity"}, style="listBox") projection_type_z ;

#@ String(label = "Reslice mode", choices={"Top","Left"}, style="listBox") reslice_mode ;

#@ Integer (label="Time averaging (default 100, 1 - disables)", min=1, max=100, style="spinner") time_z ;

#@ Integer (label="Maximum expected drift (pixels, 0 - auto)", min=0, max=auto, style="spinner") max_z ;

#@ String (label = "Reference frame", choices={"first frame (default, better for fixed)" , "previous frame (better for live)"}, style="listBox") reference_z ;

#@ boolean (label = "Extend stack to fit") extend_stack_to_fit ; 

#@ boolean (label = "Save RAM") ram_conservative_mode ; 

#@ String  (value="-----------------------------------------------------------------------------", visibility="MESSAGE") hint4;


// get time stamp
MonthNames = newArray("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");  
getDateAndTime(year, month, week, day, hour, min, sec, msec);
print("----");  

year = "" + year; //converts year to string
timeStamp = year+"-"+MonthNames[month]+"-"+day+"-"+IJ.pad(exp_nro, 3);

print(timeStamp);


//======================================================================
// ----- Helper functions -----
function getMinMaxFromDriftTable_z(path_to_table) {
	run("Open NanoJ Table (NJT)...", "load=["+path_to_table+"]");
	Table.rename(File.getName(path_to_table), "Results");

	minmaxZdrift = newArray(2);
	minmaxZdrift[0] = 0;
	minmaxZdrift[1] = 0;

	for (i = 0; i < nResults; i++) {
		zDrift = getResult("Y-Drift (pixels)", i);
		if (zDrift < minmaxZdrift[0]) minmaxZdrift[0] = zDrift;
		if (zDrift > minmaxZdrift[1]) minmaxZdrift[1] = zDrift;
	}

	minmaxZdrift[0] = floor(minmaxZdrift[0]); 
	minmaxZdrift[1] = Math.ceil(minmaxZdrift[1]);
	close("Results");

	return minmaxZdrift;
}

//--------------------------------------------- 
function resetDriftTable(path_to_table, scale_factor) {
	run("Open NanoJ Table (NJT)...", "load=["+path_to_table+"]");
	Table.rename(File.getName(path_to_table), "Results");

	for (i = 0; i < nResults; i++) {
		zDrift = getResult("Y-Drift (pixels)", i);
		setResult("Y-Drift (pixels)", i, zDrift/scale_factor);
	}
	updateResults();

	run("Save Results-Table as NJT...", "save=["+path_to_table+"]");
	close("Results");

	return;
}

//--------------------------------------------- 
function getMinMaxXYFromDriftTable_xy(path_to_table) {
	run("Open NanoJ Table (NJT)...", "load=["+path_to_table+"]");
	Table.rename(File.getName(path_to_table), "Results");

	minmaxXYdrift = newArray(4);
	minmaxXYdrift[0] = 0;
	minmaxXYdrift[1] = 0;
	minmaxXYdrift[2] = 0;
	minmaxXYdrift[3] = 0;

	for (i = 0; i < nResults; i++) {
		xDrift = getResult("X-Drift (pixels)", i);
		yDrift = getResult("Y-Drift (pixels)", i);
		if (xDrift < minmaxXYdrift[0]) minmaxXYdrift[0] = xDrift;
		if (xDrift > minmaxXYdrift[1]) minmaxXYdrift[1] = xDrift;

		if (yDrift < minmaxXYdrift[2]) minmaxXYdrift[2] = yDrift;
		if (yDrift > minmaxXYdrift[3]) minmaxXYdrift[3] = yDrift;
	}

	close("Results");
	return minmaxXYdrift;
}

fs=File.separator; 

//input="/Users/secchim/Downloads/CellProfiler/movies2_split_channels";

//results= "/Users/secchim/Downloads/CellProfiler/movies2_corrected";

processFolder(input);


function processFolder (input){
allFiles=getFileList(input);
for(f = 0; f < allFiles.length; f++) {
	if(File.isDirectory(input+allFiles[f]))
	processFolder(input+allFiles[f]);
	if(endsWith(allFiles[f], "Ch2.tif"))
	processFile(input, results, allFiles[f]);	
}
}

function processFile(input, results, file){
	fileName=file;
	print(fileName);
	my_file_path=input +fs + fileName ;
	if (endsWith(fileName, "Ch2.tif")){
	

//set file paths
filename_no_extension = File.getNameWithoutExtension(my_file_path);


//results = File.getDirectory(my_file_path)+filename_no_extension+"_"+timeStamp+File.separator;
//results = output+filename_no_extension+"_"+timeStamp;
//File.makeDirectory(results);

settings_file_path = results+fs+filename_no_extension+"_settings.csv"; 
DriftTable_path_XY = results+fs+filename_no_extension+"-"+projection_type_xy+"_xy_";
DriftTable_path_Z = results+fs+filename_no_extension+"-"+projection_type_z+"-"+reslice_mode+"_z_";


// create a settings table and set columns
setResult("Setting", 0, "File Name");
setResult("Value", 0, filename_no_extension);

setResult("Setting", 1, "xy-registration");
setResult("Value", 1, XY_registration);

setResult("Setting", 2, "xy-projection type");
setResult("Value", 2, projection_type_xy);

setResult("Setting", 3, "xy-time averaging");
setResult("Value", 3, time_xy);

setResult("Setting", 4, "xy-maximum expected drift");
setResult("Value", 4, max_xy);

setResult("Setting", 5, "xy-reference frame");
setResult("Value", 5, reference_xy);

setResult("Setting", 6, "Crop output");
setResult("Value", 6, crop_output);

setResult("Setting", 7, "z-registration");
setResult("Value", 7, z_registration);

setResult("Setting", 8, "z-projection type");
setResult("Value", 8, projection_type_z);

setResult("Setting", 9, "z-reslice mode");
setResult("Value", 9, reslice_mode);

setResult("Setting", 10, "z-time averaging");
setResult("Value", 10, time_z);

setResult("Setting", 11, "z-maximum expected drift");
setResult("Value", 11, max_z);

setResult("Setting", 12, "z-reference frame");
setResult("Value", 12, reference_z);

setResult("Setting", 13, "Extend stack to fit");
setResult("Value", 13, extend_stack_to_fit);

setResult("Setting", 14, "Save RAM");
setResult("Value", 14, ram_conservative_mode);

setResult("Setting", 15, "xy-drift table path");
setResult("Value", 15, DriftTable_path_XY +"DriftTable.njt");

setResult("Setting", 16, "z-drift table path");
setResult("Value", 16, DriftTable_path_Z +"DriftTable.njt");

setResult("Setting", 17, "results path");
setResult("Value", 17, results);

saveAs("Results", settings_file_path);

close("Results");

//======================================================================
// ----- Let's go ! -----
IJ.log("===========================");
t_start = getTime();

//open file
filename_no_extension = File.getNameWithoutExtension(my_file_path);
IJ.log("My file path: " + my_file_path);

options = "open=[" + my_file_path+ "] autoscale color_mode=Default stack_order=XYCZT";// use_virtual_stack "; // here using bioformats
run("Bio-Formats", options);

// study the image a bit and close if dimentions are wrong
getDimensions(width, height, channels, slices, frames);

if (channels > 1)  {
	
	waitForUser("Please use one channel images");
	exit();
	
}

setBatchMode(true); 
thisTitle = getTitle();

//======================================================================
// ----- Estimating the xy-correction from the resliced projection -----

if (XY_registration){
	IJ.log("Estimating the xy-drift....");
	// make projection
	getDimensions(width, height, channels, slices, frames);
	run("Z Project...", "projection=["+projection_type_xy+"] all");
	rename(projection_type_xy+" projection_"+filename_no_extension);
	
	IJ.log("xy-drift table path: " + DriftTable_path_XY);
	
	//estimate x-y drift
	run("Estimate Drift", "time="+time_xy+" max="+max_xy+" reference=["+reference_xy+"] show_drift_plot apply choose=["+DriftTable_path_XY+"]");
	rename("DriftCorrOutput_XY");

	//save drift plots
	selectWindow("Drift-X");
	saveAs("Tiff", results+fs+filename_no_extension+"_Drift-plot-X");

	selectWindow("Drift-Y");
	saveAs("Tiff", results+fs+filename_no_extension+"_Drift-plot-Y");


// ----- Applying the xy-correction from the resliced projection -----
	IJ.log("--------------------------------");
	IJ.log("Applying the xy-correction to the stack....");
	
	for (i = 0; i < slices; i++) {
		showProgress(i, slices);
		
		selectWindow(thisTitle);
		run("Duplicate...", "title=DUP duplicate slices="+(i+1));
		//run("16-bit");//changed 32 to 16
		run("Correct Drift", "choose=["+DriftTable_path_XY+"DriftTable.njt]");
		selectWindow("DUP - drift corrected");
		rename("SLICE");
	
	if (i==0){
		rename("AllStarStack");}
	else {
		// This is potentially what makes it so slow as it needs to dump and recreate the stack every time
		run("Concatenate...", "  image1=AllStarStack image2=SLICE image3=[-- None --]");
		rename("AllStarStack");}

	close("DUP");	

}

	selectWindow("AllStarStack");

	setBatchMode("show");
	run("Stack to Hyperstack...", "order=xyctz channels=1 slices="+slices+" frames="+frames+" display=Color");
	
	//run("Enhance Contrast", "saturated=0.35");
	//run("Apply LUT", "stack");
	rename(filename_no_extension+"_xyCorrected");
	Corrected_path_xy = results+fs+filename_no_extension+"_xyCorrected";
	IJ.log("Path xy-corrected: " + Corrected_path_xy);

// crops image when doing xy-correction AND if z-estimatin is performed	 
	if (crop_output || z_registration) {	
		minmaxXYdrift = getMinMaxXYFromDriftTable_xy(DriftTable_path_XY+"DriftTable.njt");

	selectWindow(filename_no_extension+"_xyCorrected");
	width = getWidth();
	height = getHeight();
	 
	new_width = width - Math.ceil(minmaxXYdrift[1]) + Math.ceil(minmaxXYdrift[0]);
	new_height = height - Math.ceil(minmaxXYdrift[3]) + Math.ceil(minmaxXYdrift[2]);
	
	makeRectangle(Math.ceil(minmaxXYdrift[1]), Math.ceil(minmaxXYdrift[3]), new_width, new_height);
	run("Crop");
	}

	// Save intermediate file xy-correct	 
	saveAs("Tiff", Corrected_path_xy);
	close("*");


}
//======================================================================

if (z_registration) {
	IJ.log("===========================");
	IJ.log("Estimating the z-drift....");
	
	// ----- opening the correct file-----	
	if (!XY_registration){
		options = "open=[" + my_file_path + "] autoscale color_mode=Default stack_order=XYCZT";// use_virtual_stack "; // here using bioformats
		run("Bio-Formats", options);
	} else {
		Corrected_image_xy = Corrected_path_xy+".tif";
		//options = "open=[" + Corrected_image_xy + "]";
		//run("TIFF Virtual Stack...", options);
		options = "open=[" + Corrected_image_xy + "]autoscale color_mode=Default stack_order=XYCZT";
		run("Bio-Formats", options);
		
	}
	
	// ----- Reslicing for z-projection estimation-----	
	getVoxelSize(width, height, depth, unit);
	run("Reslice [/]...", "output="+depth+" start="+reslice_mode+" avoid");
	rename("DataRescliced");
	getDimensions(width, height, channels, slices, frames);
	scale_factor = round(width/height);
	
	setBatchMode("show");
	
	//======================================================================
	// ----- Estimating the z correction  from the resliced projection -----
	run("Z Project...", "projection=["+projection_type_z+"] all");
	rename(projection_type_z+" "+reslice_mode+" projection_"+filename_no_extension);
	setBatchMode("show");
	
	run("Scale...", "x=1.0 y="+scale_factor+" z=1.0 width="+width+" height="+(scale_factor*width)+" depth="+frames+" interpolation=Bicubic average process create");

	IJ.log("z-drift table path: " + DriftTable_path_Z);
	
	run("Estimate Drift", "time="+time_z+" max="+max_z+" reference=["+reference_z+"] show_drift_plot apply choose=["+DriftTable_path_Z+"]");
		
	rename("DriftCorrOutput");
	
	selectWindow("Drift-X");
	//setBatchMode("show");
	
	selectWindow("Drift-Y");
	rename("Drift-Z");
	Plot.setXYLabels("time-points", "z-drift (px)");
	saveAs("Tiff", results+fs+filename_no_extension+"_Drift-plot-Z");
	//setBatchMode("show");
	
	selectWindow("DriftCorrOutput");
	run("Scale...", "x=1.0 y="+(1/scale_factor)+" z=1.0 width="+width+" height="+height+" depth="+frames+" interpolation=Bicubic average process create");
	rename("DriftCorrected_"+projection_type_z+" "+reslice_mode+" projection_"+filename_no_extension);
	
	//edits drift tabel so that only z drift is saved
	run("Open NanoJ Table (NJT)...", "load=["+DriftTable_path_Z+"DriftTable.njt]");
	TableName = filename_no_extension+"-"+projection_type_z+"-"+reslice_mode+"_z_DriftTable.njt";
	Table.rename(TableName, "Results");
	for (i = 0; i < nResults; i++) {
		setResult("X-Drift (pixels)", i, 0);
		setResult("XY-Drift (pixels)", i, 0);
	}
	updateResults();
	run("Save Results-Table as NJT...", "save=["+DriftTable_path_Z+"DriftTable.njt]");
	
	resetDriftTable(DriftTable_path_Z+"DriftTable.njt", scale_factor);
	
	setBatchMode(false);
	run("Collect Garbage");
	
	

}

close("\\Others");
IJ.log("===========");
IJ.log("Time taken: "+round((getTime()-t_start)/1000)+"s");
IJ.log("All done.");

run("Close All");
//showMessage("All DONE! Time: " +round((getTime()-t_start)/1000)+"s");

//====== THE END =======================================================

	}
else {print ("error");}
}

setBatchMode(false);

//input=getDir("Get input directory");
settings=getDir("Get input directory");
//settings=results;
results=getDir("Get input directory");

// ----- Helper functions -----
function getMinMaxFromDriftTable(DriftTable_path_Z) {
	run("Open NanoJ Table (NJT)...", "load=["+DriftTable_path_Z+"]");
	Table.rename(File.getName(DriftTable_path_Z), "Results");

	minmaxZdrift = newArray(2);
	minmaxZdrift[0] = 0;
	minmaxZdrift[1] = 0;

	for (i = 0; i < nResults; i++) {
		zDrift = getResult("Y-Drift (pixels)", i);
		if (zDrift < minmaxZdrift[0]) minmaxZdrift[0] = zDrift;
		if (zDrift > minmaxZdrift[1]) minmaxZdrift[1] = zDrift;
	}

	minmaxZdrift[0] = floor(minmaxZdrift[0]); 
	minmaxZdrift[1] = Math.ceil(minmaxZdrift[1]);
	close("Results");

	return minmaxZdrift;
}


// ----- Helper functions -----
function getMinMaxXYFromDriftTable(DriftTable_path_XY) {
	run("Open NanoJ Table (NJT)...", "load=["+DriftTable_path_XY+"]");
	Table.rename(File.getName(DriftTable_path_XY), "Results");

	minmaxXYdrift = newArray(4);
	minmaxXYdrift[0] = 0;
	minmaxXYdrift[1] = 0;
	minmaxXYdrift[2] = 0;
	minmaxXYdrift[3] = 0;

	for (i = 0; i < nResults; i++) {
		xDrift = getResult("X-Drift (pixels)", i);
		yDrift = getResult("Y-Drift (pixels)", i);
		if (xDrift < minmaxXYdrift[0]) minmaxXYdrift[0] = xDrift;
		if (xDrift > minmaxXYdrift[1]) minmaxXYdrift[1] = xDrift;

		if (yDrift < minmaxXYdrift[2]) minmaxXYdrift[2] = yDrift;
		if (yDrift > minmaxXYdrift[3]) minmaxXYdrift[3] = yDrift;
	}

	close("Results");

	return minmaxXYdrift;
	
}

run("Close All");
print("\\Clear");
//run("Collect Garbage");

// select file to be corrected
//#@ File (label="Select the file to be corrected", style="open") my_file_path ;
//#@ File () my_file_path ;
//#@ File (label="Select settings file (.csv)", style="open") settings_file_path ;
//#@ File () settings_file_path ;

fs=File.separator; 

//input="/Users/secchim/Downloads/CellProfiler/movies2_split_channels";
//settings="/Users/secchim/Downloads/CellProfiler/movies2_corrected";
//results= "/Users/secchim/Downloads/CellProfiler/movies2_apply";

processFolder2(input);

function processFolder2 (input){
allFiles=getFileList(input);
for(f = 0; f < allFiles.length; f++) {
	if(File.isDirectory(input+allFiles[f]))
	processFolder(input+allFiles[f]);
	if (endsWith(allFiles[f], ".tif"))
	processFile2(input, results, allFiles[f]);	
}
}

function processFile2(input, results, file){
	fileName=file;
	print(fileName);
	my_file_path=input + fileName ;//deleted +fs in between input and filename
	
filename_no_extension = File.getNameWithoutExtension(fileName);

settings_file=substring(filename_no_extension, 0, (lengthOf(filename_no_extension)-4));
settings_file_path =settings+settings_file+"_Ch2_settings.csv";//deleted the +fs+ IN BETWEEN SETTINGS

print(settings_file_path);

// ----- Let's go ! -----

// read settins from csv
Table.open(settings_file_path);
//z_registration = Table.get("Value",0); //should be 5
z_registration = 1;
File_Name = Table.getString("Value", 0);//0 instead of 7
//reslice_mode = Table.getString("Value",14); //set to Top as it's what's selected in the first plugin
reslice_mode = "Top";
print(z_registration);
// get variables from settings file

//File_Name = Table.getString("Value", 0);
XY_registration = 1;
crop_output = 1;
//z_registration = Table.getString("Value",7);
//z_registration = Table.get("Value",7);
//reslice_mode = Table.getString("Value",9);
extend_stack_to_fit = 1;
//ram_conservative_mode = Table.getString("Value",14); //set to 0 as it's what's selected in the first plugin
ram_conservative_mode = 0;
DriftTable_path_XY = Table.getString("Value",15);
DriftTable_path_Z = Table.getString("Value",16);
//results_path = Table.getString("Value",17);
results_path = results;//deleted +fs

//if (isNaN(Table.get("Value",0))){
//z_registration = Table.get("Value",7);}

//if (Table.getString("Value",14)=="Top"){ //set to 0 as it's what's selected in the first plugin
//ram_conservative_mode =(0);}

//if (Table.getString("Value",14)==0){ //set to Top as it's what's selected in the first plugin
//reslice_mode ="Top";}

run("Close");

setBatchMode(true); 

// =============== XY ====================
if (XY_registration){


IJ.log("--------------------------------");
IJ.log("Applying the xy-correction to the stack....");
t_start = getTime();

filename_no_extension = File.getNameWithoutExtension(my_file_path);
IJ.log("File name: " + filename_no_extension);

options = "open=[" + my_file_path+ "] autoscale color_mode=Default stack_order=XYCZT";// use_virtual_stack "; // here using bioformats
run("Bio-Formats", options);

//setBatchMode(true); 

thisTitle = getTitle();
getDimensions(width, height, channels, slices, frames);

for (i = 0; i < slices; i++) {
	showProgress(i, slices);

	selectWindow(thisTitle);
	run("Duplicate...", "title=DUP duplicate slices="+(i+1));
	//run("16-bit");//changed 32 to 16
	run("Correct Drift", "choose=["+settings+fs+settings_file+"_Ch2-Max Intensity_xy_DriftTable.njt"+"]");
	//run("Correct Drift", "choose=["+DriftTable_path_XY"]");
	selectWindow("DUP - drift corrected");
	rename("SLICE");
	
	if (i==0){
		rename("AllStarStack");}
	else {
		// This is potentially what makes it so slow as it needs to dump and recreate the stack every time
		run("Concatenate...", "  image1=AllStarStack image2=SLICE image3=[-- None --]");
		rename("AllStarStack");}

	close("DUP");	
}

selectWindow("AllStarStack");
run("Stack to Hyperstack...", "order=xyctz channels=1 slices="+slices+" frames="+frames+" display=Color");

//run("Enhance Contrast", "saturated=0.35");
//run("Apply LUT", "stack");
rename(filename_no_extension+"_xyCorrected");
Corrected_path_xy = results_path+filename_no_extension+"_xyCorrected"; 
IJ.log("xy_corrected_image_path: " + Corrected_path_xy);

if (crop_output){
	minmaxXYdrift = getMinMaxXYFromDriftTable(DriftTable_path_XY);

	new_width = width - Math.ceil(minmaxXYdrift[1]) + Math.ceil(minmaxXYdrift[0]);
	new_height = height - Math.ceil(minmaxXYdrift[3]) + Math.ceil(minmaxXYdrift[2]);
	makeRectangle(Math.ceil(minmaxXYdrift[1]), Math.ceil(minmaxXYdrift[3]), new_width, new_height);
	run("Crop");
	
}

setBatchMode("show");
setBatchMode(false);
	
// Save intermediate file xy-correct //JP 	 
saveAs("Tiff", Corrected_path_xy);
close("*");

}
setBatchMode(true);
Table.open(settings_file_path);

// =============== Z ====================

if (z_registration){

IJ.log("------------------");
t_start = getTime();

filename_no_extension = File.getNameWithoutExtension(my_file_path);

// ----- opening the correct file-----	
	if (!XY_registration){
		options = "open=[" + my_file_path+ "] autoscale color_mode=Default stack_order=XYCZT"; //use_virtual_stack "; // here using bioformats
		run("Bio-Formats", options);
	} else {
		Corrected_image_xy = Corrected_path_xy+".tif";
//		options = "open=[" + Corrected_image_xy + "]";
//		run("TIFF Virtual Stack...", options);
		options = "open=[" + Corrected_image_xy + "]autoscale color_mode=Default stack_order=XYCZT";
		run("Bio-Formats", options);

	}

//setBatchMode(true); 

thisTitle = getTitle();

getVoxelSize(width, height, depth, unit);
run("Reslice [/]...", "output="+depth+" start="+reslice_mode+" avoid");
rename("DataRescliced");


//------- Applying the correction -------- 

IJ.log("Applying the z-correction to the stack....");

if (extend_stack_to_fit){
//	minmaxZdrift = getMinMaxFromDriftTable(DriftTable_path_Z);
	minmaxZdrift = getMinMaxFromDriftTable(settings+fs+settings_file+"_Ch2-Max Intensity-Top_z_DriftTable.njt");
//	"choose=["+settings+fs+settings_file+"_Ch2-Max Intensity-Top_z_DriftTable.njt"+"]");
	padding = 2*maxOf(-minmaxZdrift[0], minmaxZdrift[1]);
}
else {
	padding = 0;
}


selectWindow("DataRescliced");
getDimensions(width, height, channels, slices, frames);
getVoxelSize(width_realspace, height_realspace, depth_realspace, unit_realspace);
padded_height = height + padding;

if (!ram_conservative_mode){
	newImage("DataRescliced_Corrected", "16-bit black", width, padded_height, slices*frames);//changed 32 to 16
	setVoxelSize(width_realspace, height_realspace, depth_realspace, unit_realspace);
}


for (i = 0; i < slices; i++) {
	showProgress(i, slices);
	
	selectWindow("DataRescliced");

	if (ram_conservative_mode){
		setSlice(1);
		run("Duplicate...", "title=DUP duplicate slices=1");
	}
	else{
		run("Duplicate...", "title=DUP duplicate slices="+(i+1));
	}

	run("Canvas Size...", "width="+width+" height="+(padded_height)+" position=Center zero");
	
	run("Correct Drift", "choose=["+settings+fs+settings_file+"_Ch2-Max Intensity-Top_z_DriftTable.njt"+"]");
	rename("SLICE");
	run("Hyperstack to Stack");
	

	if (ram_conservative_mode){
		if (i==0){
			rename("AllStarStack");}
		else {
			// This is potentially what makes it so slow as it needs to dump and recreate the stack every time
			run("Concatenate...", "  image1=AllStarStack image2=SLICE image3=[-- None --]");
			rename("AllStarStack");}
	}
	else {
		for (f = 0; f < frames; f++) {
			selectWindow("SLICE");
			setSlice(f+1);
			run("Select All");
			run("Copy");
			selectWindow("DataRescliced_Corrected");
			setSlice(i*frames + f+1);
			run("Paste");		
		}
	}
		
	close("DUP");

	if (ram_conservative_mode){
		selectWindow("DataRescliced");
		run("Delete Slice", "delete=slice");
	}
	else {
		close("SLICE");
	}

}

if (!ram_conservative_mode){
	close("DataRescliced");
	selectWindow("DataRescliced_Corrected");
	run("Select None");
	//run("Enhance Contrast", "saturated=0.35");
	//run("Apply LUT", "stack");
}
else {
	selectWindow("AllStarStack");
}

run("Stack to Hyperstack...", "order=xyctz channels=1 slices="+slices+" frames="+frames+" display=Color");
getVoxelSize(width, height, depth, unit);
run("Reslice [/]...", "output="+depth+" start=Top avoid");

if (reslice_mode == "Left"){
	run("Flip Vertically", "stack");
	run("Rotate 90 Degrees Right");
}

//save files here
if (!XY_registration) {
	rename(filename_no_extension+"_zCorrected"); 
	Corrected_path_z = results_path+filename_no_extension+"_zCorrected"; 
	saveAs("Tiff", Corrected_path_z);
	IJ.log("z_corrected_image_path: " + Corrected_path_z);
	} else {
	rename(filename_no_extension+"_xyzCorrected");
	Corrected_path_xyz = results_path+filename_no_extension+"_xyzCorrected";
	saveAs("Tiff", Corrected_path_xyz);
	IJ.log("xyz_corrected_image_path: " + Corrected_path_xyz);
	File.delete(Corrected_path_xy+".tif")
	}   


close("\\Others");
//run("Enhance Contrast", "saturated=0.35");


setBatchMode(false);

IJ.log("============");
IJ.log("Time taken: "+round((getTime()-t_start)/1000)+"s");
IJ.log("All done.");
//showMessage("All DONE!");

}
print("Finished!");

}