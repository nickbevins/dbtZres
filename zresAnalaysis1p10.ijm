/*----------------------ACR DBT Z Resolution Analyzer----------------------------
!
!	Copyright 2022 Henry Ford Health
!	
!	This file is free to use and distribute, and should not be sold
!	This program is free software: you can redistribute it and/or modify
!	it under the terms of the GNU General Public License as published by
!	the Free Software Foundation, either version 3 of the License, or
!	(at your option) any later version.
!
!	This program is distributed in the hope that it will be useful,
!	but WITHOUT ANY WARRANTY; without even the implied warranty of
!	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!	GNU General Public License for more details.
!
!	You should have received a copy of the GNU General Public License
!	along with this program.  If not, see <https://www.gnu.org/licenses/>.
!
---------------------------------------------------------------------------------
!
!	This script is used to analyze a digital breast tomosynthesis (DBT) image of the
!	updated ACR quality assurance phantom for the z-axis resolution measurements. It
!	crops the image to the section covering the largest few speck groups and the left
!	and chest edges of the wax insert. The "in-focus" slice is determined from the 
!	maximum pixel value of the reduced image area. This maximum should correspond to 
!	the slice where the specks are the brightest. Within this slice, the wax insert 
!	edges are found using local minima, from which the location of the largest speck 
!	group is determined. The script assumes the phantom has been set up without too 
!	much rotation with respect to the detector. From the location of the largest 
!	speck group, the script measures the maxima from all six specks over a range of
!	+/- 3 slices (adjustable with nn variable). The script also records the mean background  
!	value for each slice from a location between the 10 o'clock and 12 o'clock specks.
!	The maxima are averaged on a per-slice basis, and all results are printed in a
!	format to be pasted into the ACR spreadsheet. A montage of the analyzed slices and 
!	the ROIs is presented to the user for visual verification of the placement. 
!
!	1.0	Release notes (8/19/2019):
!		- Added file header with description and directions
!		- Improved annotations within script for interpretation of code
!		- Removed extraneous code that wasn't being used
!		- Introduced version numbers (officially non-beta?)
!	1.1	Release notes (9/11/2019):
!		- Corrected comment describing structure of results array
!		- Modified montage slice label font size to account for pixel dimensions
!		- Updated spaced indents to tabbed
!		- Change montage overlay color from default yellow to green
!		- Clarified description of the script regarding edge-finding routine
!	1.2	Release notes (9/16/2019):
!		- Corrected description of speck position array (left/right confusion)
!		- Added check for correct phantom orientation (R CC orientation)
!		- Fixed run errors with missing semicolons
!		- Change overlay color for background ROI to cyan
!	1.3	Release notes (11/18/2019):
!		- Remove Roi.remove commands (compatibility issues with vanilla ImageJ)
!	1.4	Release notes (11/19/2019):
!		- Overhaul of speck location search
!			- Use Find Maxima command to return locations of specks
!			- Sort the locations to the correct order and use for the max value routine
!	1.5	Release notes (05/04/2020):
!		- Change prominence threshold in Find Maxima... routine
!	1.6	Release notes (07/09/2020):
!		- Fixed error in insert edge search (used hprofile in vprofile routine)
!	1.7	Release notes (07/14/2020):
!		- Added ability to change the number of slices (nn variable)
!	1.8	Release notes (03/04/2021):
!		- Modified location of hprofile line to avoid chest wall zeros during min search
!	1.9	Release notes (08/30/2021):
!		- Perform iterative maxima search to ensure correct count (6)
!			- Adjust noise threshold in Find Maxima... routine based on result
!		- Modify order of operations for initial image processing
!			- Crop image as before (1/3 of width from chest, 1/3 of height from midline)		
!			- Use slice thickness from DICOM header to position at 34 mm from phantom base
!			- Perform edge search at this slice position, crop to largest speck group
!			- Perform max search on largest speck group only (exclude wax edges)
!		- Move nn variable to top for easy modification
!		- Change results to tab delimited to facilite pasting into excel
!		- Copy the results to clipboard after printing to log to reduce clicks
!		- Add dialog box to tell user the results were copied, clicking OK copies montage
!		- Dialog box allows user to close all windows when clicking "OK"
!		- Increased font size on slice labels in montage
!		- Improve annotations throughout
!	1.10 Release notes (01/16/2024):
!		- Modified code to present user with save dialog at the end to store txt file with results
!		- Script runs in batch mode to improve speed
!
!------------------------------------------------------------------------------*/
// Turn on batch mode to hide new/temp images
setBatchMode(true);

// Set the number of slices to be analyzed (in form +/- from central slice)
nn = 3;

// Retrieve the image height and width in pixels and set to variables
w = getWidth();
h = getHeight();

// Retrieve the pixel spacing from the DICOM header
// It's reported as horizontal\vertical. Use split to get the values separated
pixelSpacing = getInfo("0028,0030");
pixelSpacingArray = split(pixelSpacing,"\\");
pixelH = parseFloat(pixelSpacingArray[0]);
pixelW = parseFloat(pixelSpacingArray[1]);
// Retrieve the Slice Thickness from the DICOM header
sliceThick = getInfo("0018,0050");

// Check to ensure the correct phantom orientation
// The chest wall side of the phantom should be on the right side of the image
// The largest speck group should be toward the bottom edge of the image
// Check a small ROI on the right edge of the image - if it's air, rotate 180 degrees
makeRectangle(w-6,h/2,6,h/2);
Stack.getStatistics(voxelCount, mean) // get the stats from the edge ROI
makeRectangle(0,0,w,h);
// If the mean through the stack is less than 50, assume it's air and rotate 180 deg
if(mean < 50) { 
	run("Rotate... ", "angle=180 grid=1 interpolation=None stack");
}

// Draw a rectangle over the region of the of the image containing the 
// left and chest edges of the wax insert.
// The width of the ROI is one-third of the overall width and abuts 
// the chest wall.
// The height of the ROI is one-third of the overall height and extends 
// down from the midline of the phantom.
makeRectangle(2*w/3,h/2,w/3,h/3);

// Crop to the rectangle
run("Crop");

// Replace the height and width variables with the new dimensions
w = getWidth();
h = getHeight();

// Use Slice Thickness to determine approximate location of wax insert
// Assume the wax insert is typically ~34 mm from the bottom
waxSlice = 34/sliceThick;
setSlice(waxSlice);

// Draw lines horizontally and vertically across the image (exclude chest wall edge and lower edge)
// Collect the profiles of the lines and store them in respective arrays
// Ignore 10 lines in from the chest wall to avoid any zero padding at the edges (or phantom misalignment)
makeLine(0,h/2,w-10,h/2,100);
hprofile = getProfile();
makeLine(w/3,0,w/3,h-1,100);
vprofile = getProfile();

// Find the index of the minimum values for each profile. Use this to set the edge positions
// Begin with the phantom chest edge. Search the hprofile for the min value and return the index
Array.getStatistics(hprofile, min);
hmin = min;
for(i = 1; i < lengthOf(hprofile); i++){
	if(hprofile[i] == hmin){
		cEdge = i;
	}
}
// Find the min value index for the vertical profile and use it to set the left edge
Array.getStatistics(vprofile,min);
vmin = min;
for(i = 1; i < lengthOf(vprofile); i++){
	if(vprofile[i] == vmin){
		lEdge = i;
	}
}

// Crop down to the largest speck group
// The center of the central speck is 35 mm from the chest edge and 16 mm from the left
// The ROI is 20 mm x 20 mm
makeRectangle(cEdge-45/pixelW,lEdge-26/pixelH,20/pixelW,20/pixelH);
run("Crop");

// Find the highest maximum value and record the slice number
// The logic assumes that the absolute max over the stack will be the "in-focus" plane
maxMax = 0; // initialize the value of the stack max value
for(i = 1; i < nSlices; i++) {
	setSlice(i); // move to the current slice
	getStatistics(area, mean, min, max); // get the stats over the entire slice
	// test to see if the max of the current slice is greater than the absolute max (init 0)
	// if it is greater, then store it as the new absolute max
	if(maxMax < max) { 
		maxMax = max;
		maxSlice = i;
	}
}
setSlice(maxSlice);

// Define two arrays (x and y) with the location of each speck w.r.t. to the upper left corner
// The "Find Maxima..." routine will return a list of the six specks. Each position is assigned
// to the x or y array. These arrays are organized into the correct order (center, twelve o'clock, 
// two, five, seven, ten). After reorganization, the coordinates are passed to the max results
// routine below. The ROIs are drawn artificially larger for the final montage and visual verification 

x = newArray(6); // array for x coordinates (in pixels)
y = newArray(6); // array for y coordinates (in pixels)

// Run a do-while to ensure 6 maxima are found. Adjust the prominence threshold as necessary
// to correct for missing or too many maxima
// Initialize the noise value for the maxima search prominence threshold
noise = 150;
// Store the default threshold for comparison later
defnoise = noise;
// Initialize the max count variable for the do-while loop
maxCount = 0;
do {
	// Run the "Find Maxima..." command. Set the noise to eliminate false maxima
	run("Find Maxima...", "noise="+noise+" output=List"); 
	String.copyResults; // copy the results to the clipboard
	// Paste the results to the max_xy array
	max_xy = split(String.paste);
	// Close the results window
	close("Results");

	// Create a new array to convert the results of the paste into integers
	// Fill that array with the converted results
	max_xy_int = newArray(max_xy.length);
	for (i = 0; i < max_xy.length; i++) {
		max_xy_int[i] = parseInt(max_xy[i]);
	}

	// Set a variable to the length of the maxima locations to check the proper number were found
	maxlength = lengthOf(max_xy_int);

	// Populate the x, y arrays with the results from the "Find Maxima..." routine
	// The results vary a bit depending on the user's Input/Output settings
	// Run some if and for loops to determine if the row numbers or column headings were
	// copied as part of the results.
	// Also use maxlength variable to determine the length of the copied text. If the length is
	// incorrect, iterate the noise value to correct it.
	if (isNaN(max_xy_int[0])) {				//column headers were copied
		if (max_xy_int[2] == 1) {			//row headers were copied
			if (maxlength == 20) {			//total entries in array is 20 (first is not counted, NaN)
				for (i = 0; i < 6; i++) {
				x[i] = max_xy_int[3*i+3];
				y[i] = max_xy_int[3*i+4];
				}
				maxCount = 1;				//switch maxCount check to indicate success for do-while
			} else if (maxlength > 20) {	//too many entries - increase maxima prominence threshold
				noise = noise + 25;
			} else {						//too few entries - decrease maxima prominence threshold
				noise = noise - 25;
			}
		} else if (maxlength == 14) {		//total entries in array is 14 (no row headers)
			for (i = 0; i < 6; i++) {
				x[i] = max_xy_int[2*i+2];
				y[i] = max_xy_int[2*i+3];
			}
			maxCount = 1;
		} else if (maxlength > 14) {		//too many entries - increase maxima prominence threshold
				noise = noise + 25;
		} else {							//too few entries - decrease maxima prominence threshold
				noise = noise - 25;
		}
	} else {
		if (max_xy_int[0] == 1) {			//column headers not copied, row headers copied
			if (maxlength == 18) {			//total entries in array is 18
				for (i = 0; i < 6; i++) {
					x[i] = max_xy_int[3*i+1];
					y[i] = max_xy_int[3*i+2];
				}
				maxCount = 1;
			} else if (maxlength > 18) {	//too many entries - increase maxima prominence threshold
				noise = noise + 25;
			} else {						//too few entries - decrease maxima prominence threshold
				noise = noise - 25;
			}
		} else if (maxlength == 12) {		//no row or column headers copied, 12 total entries
			for (i = 0; i < 6; i++) {
				x[i] = max_xy_int[2*i];
				y[i] = max_xy_int[2*i+1];
			}
			maxCount = 1;
		} else if (maxlength > 12) {		//too many entries - increase maxima prominence threshold
				noise = noise + 25;
		} else {							//too few entries - decrease maxima prominence threshold
				noise = noise - 25;
		}
	}
} while (maxCount == 0); //if maxCount not switched, re-enter do loop with new prominence threshold

// The specks are not ordered in any particular geometric way from the "Find Maxima..." routine
// Assuming the phantom is lined up correctly, the spots can be re-ordered according to:
// - The top speck (smallest y value) is the twelve o'clock position
// - Next from the top is the two o'clock
// - The center speck and ten o'clock speck are on about the same level
// - The fifth speck from the top is the five o'clock
// - The last speck from the top (largest y value) is the seven o'clock
// The only two specks sensitive to alignment are the central and ten o'clock positions
// These two will be re-ordered by seeing which one has a lower x value.

// Find the rank order of the y values for the sort (lower is closer to the top of the 
// cropped image)
yrank = Array.rankPositions(y);

// Define new arrays for the sorted values
xs = newArray(x.length);
ys = newArray(y.length);

// Re-order based on the yrank results. Re-order xs at the same time to keep the pairs together.
for (i = 0; i < 6; i++) {
	xs[i] = x[yrank[i]];
	ys[i] = y[yrank[i]];
}

// Now re-order the central two coordinates (central speck and 10 o'clock speck) based
// on the x value. The resulting array should have the 10 o'clock listed first. 

// Create some temporary arrays to hold the values during the re-organization
xt = Array.copy(xs);
yt = Array.copy(ys);

// If the third (index 2) x value is larger than the fourth, swap them
if (xs[2] > xs[3]) {
	xt[2] = xs[3];
	yt[2] = ys[3];
	xt[3] = xs[2];
	yt[3] = ys[2];	
}

// At this point the xt, yt arrays now have the specks listed in the following order:
// Twelve o'clock, two o'clock, ten o'clock, central, five o'clock, seven o'clock
// Re-order them to match the results spreadsheet. Populate the xspeck and yspeck arrays
xspeck = newArray(x.length);
yspeck = newArray(y.length);
xspeck[0] = xt[3]; // central
yspeck[0] = yt[3];
xspeck[1] = xt[0]; // twelve o'clock
yspeck[1] = yt[0];
xspeck[2] = xt[1]; // two o'clock
yspeck[2] = yt[1];
xspeck[3] = xt[4]; // five o'clock
yspeck[3] = yt[4];
xspeck[4] = xt[5]; // seven o'clock
yspeck[4] = yt[5];
xspeck[5] = xt[2]; // ten o'clock
yspeck[5] = yt[2];

// Finally, append the speck arrays with the position of the background measurement
// Use the top most yspeck value and left most xspeck value (both mins)
// Do a little adjustment (based on pixel size) to avoid overlap
Array.getStatistics(x,min);
xspeck = Array.concat(xspeck,min-0.5/pixelW);
Array.getStatistics(y,min);
yspeck = Array.concat(yspeck,min+0.5/pixelH);

// Build a second array for the max and mean results from the -nn to +nn slices
// The array will have the slice number, relative position, max readings from the specks,
// background mean, and mean max (10 values in total per slice)
// Total slices is 2*nn+1
// Format is (slice_1,rel_1,max1_1,max2_1,...,max6_1,meanMax_1,bkgdMean_1,slice_2,...)
results = newArray(10*(2*nn+1));

// Draw ROIs over the specks and the mean background region
// The position of each speck is given in the xspeck and yspeck arrays
// The offset values in the makeEllipse normalized to the pixel dimensions
// Each ROI is a circle, with a radius of rad mm
rad = 1.25;
// For each ROI, collect the maximum value for the +/- nn slices surrounding the
// max slice found above.
for (j = 0; j < 2*nn+1; j++){		// run a for loop over the slices of interest
	setSlice(maxSlice+j-nn);		// position the stack at the slice of interest
	results[j*10] = maxSlice+j-nn;	// record the slice number
	results[j*10+1] = j-nn;			// record the relative slice position from center
	for (i = 0; i < 7; i++) {		// run a for loop over each of the specks and background
		if(i != 6){					// test to see if this is a max or mean reading (mean is last)
			makeEllipse(xspeck[i]-rad/pixelW,yspeck[i]-rad/pixelH,
			xspeck[i]+rad/pixelW,yspeck[i]+rad/pixelH,1);	// draw ellipse at location in xspeck, yspeck
			getStatistics(area,mean,min,max);				// get stats from the ROI
			results[j*10+i+2] = max;						// store the max value in the results array
		} else {											// make the mean reading and average the maxima
			makeEllipse(xspeck[i],yspeck[i],xspeck[i]+2*rad/pixelW,
			yspeck[i]+2*rad/pixelH,1);						// draw ellipse at mean bkgd location 
			getStatistics(area,mean,min,max);				// get stats from the ROI
			results[j*10+i+3] = mean;						// store the mean value of the background
			sliceMax = Array.slice(results,j*10+2,j*10+8);	// store the maxima in a temp array
			Array.getStatistics(sliceMax,min,max,mean);		// stats of the temp array
			results[j*10+i+2] = mean;						// store the mean max value from the maxima
		}
		// Add the selection to the overlay for the central slice
		// For the background ROI, make the color cyan, else make it green
		if(j == nn){
			if(i == 6){
				Overlay.addSelection("cyan");
			} else {
				Overlay.addSelection("green");
			}
		}
	}
}

// Save the results as a tab-delimited array to use later in the macro
// Shorten the two mean measurements to one decimal with d2s command (double to string)
printres = newArray(2*nn+1);
for (j = 0; j < 2*nn+1; j++) {
	printres[j] = results[j*10]+" \t"+results[j*10+1]+" \t"+results[j*10+2]+" \t"+results[j*10+3]+
	" \t"+results[j*10+4]+" \t"+results[j*10+5]+" \t"+results[j*10+6]+" \t"+results[j*10+7]+
	" \t"+d2s(results[j*10+8],1)+" \t"+d2s(results[j*10+9],1);
}

// Display a montage of the nn slices with the ROIs overlayed
// for visual confirmation of positioning and copying into worksheet
// Flatten the overlay so it carries over to the montage
Overlay.show;
run("Flatten", "stack");

// Call the Make Montage command. Pass on the first and last slice based on maxSlice variable
// Pass on the pixelH variable to set the font size. Typical pixelH results in size ~14
run("Make Montage...", "columns=4 rows=" + floor(2*nn+1)/4+1 +" scale=1 first=" + (maxSlice-nn) + 
" last=" + (maxSlice+nn) +" font=" + 1.5/pixelH + " border=1 label");
// Store the montage ImageID for future copying
montageID = getImageID();

// Create a diaglog box to inform the user of the next steps
// Present the option to save the results to files
Dialog.create("Analysis Complete");
if (noise == defnoise) {
	Dialog.addMessage("Default threshold used: "+ noise)
} else {
	Dialog.addMessage("Modified threshold used: "+ noise)
}
Dialog.addFile("Save Results", "E:\\zresResults.txt")
Dialog.addFile("Save Montage", "E:\\zresMontage.jpg")
Dialog.addCheckbox("Display Montage", false)
Dialog.show();
resfile = Dialog.getString();
montfile = Dialog.getString();
montCheck = Dialog.getCheckbox();
if (montCheck) {
	selectImage(montageID);
	setBatchMode("Show");
}

// Save the array, using new line as the delimiter
File.saveString(String.join(printres,"\n"), resfile);
// Save the montage
selectImage(montageID);
saveAs("png",montfile);

// Call the debug window to see the variables
//debug("dump");