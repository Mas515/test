from ij import IJ
import os
import sys

from ij import WindowManager
from ij import ImagePlus
#from ij import Concatenator
from fiji.plugin.trackmate import Model
from fiji.plugin.trackmate import Settings
from fiji.plugin.trackmate import TrackMate
from fiji.plugin.trackmate import SelectionModel
from fiji.plugin.trackmate import Logger
from fiji.plugin.trackmate.detection import LogDetectorFactory
from fiji.plugin.trackmate.detection import ThresholdDetectorFactory
from fiji.plugin.trackmate.tracking.sparselap import SparseLAPTrackerFactory
from fiji.plugin.trackmate.tracking import LAPUtils
from fiji.plugin.trackmate.gui.displaysettings import DisplaySettingsIO
import fiji.plugin.trackmate.visualization.hyperstack.HyperStackDisplayer as HyperStackDisplayer
import fiji.plugin.trackmate.features.FeatureFilter as FeatureFilter

import fiji.plugin.trackmate.features.track.TrackDurationAnalyzer as TrackDurationAnalyzer
from  fiji.plugin.trackmate.action import LabelImgExporter






filename =[]

filepath='/Users/secchim/Downloads/CellProfiler/corrected_movies_movie_example/test_trackmate_plugin'
#filepath='/Users/secchim/Downloads/CellProfiler/corrected_movies_movie_example/CP_output'
for root, dirs, files in os.walk(filepath): # will open up all the folders, dirs is all the name of the folder it finds, files will contain all the filenames it finds
        for file in files:               
			if file.endswith("- T=0SP.tiff"):
				ind=file.index("- T=0SP.tiff")
				rep=file[ind:]
				file_init=file.replace(rep, '-')
				filename.append(file_init) 
			
sequence=[]

for root, dirs, files in os.walk(filepath):
	for unique_file in filename:
#		for i in files: 
#			if unique_file in i:
#				sequence.append(os.path.join(root, i))
		sequence=[os.path.join(root, i) for i in files if unique_file in i]# i is representing an individual file name 
		print('hello',sequence)
		for i in sequence: 
			imp=IJ.openImage(i)
			slicenb=str(imp.getNSlices())
			filenb=str(len(sequence))
			#print(nSlices(imp))
			imp.show()
			print(slicenb, filenb)
		IJ.run("Concatenate...", "all_open title=["+unique_file+"]") #im4D
		IJ.selectWindow(unique_file)
		IJ.run("Properties...", "channels=1 slices="+slicenb+" frames="+filenb+" pixel_width=1.0000 pixel_height=1.0000 voxel_depth=1.0000")
		IJ.run("Make Substack...", "slices=1-"+slicenb+" frames=1-"+filenb+"")
		IJ.saveAs("Tiff", os.path.join('/Users/secchim/Downloads/CellProfiler/corrected_movies_movie_example/output_test_trackmate', unique_file +'_Ch7.tif'))
		IJ.run("Close All")

filepath2='/Users/secchim/Downloads/CellProfiler/corrected_movies_movie_example/output_test_trackmate'
for root, dirs, files in os.walk(filepath2): # will open up all the folders, dirs is all the name of the folder it finds, files will contain all the filenames it finds
        for file in files:
        	if file.endswith(".tif"):
        		imp=IJ.openImage(os.path.join(root, file))
        		imp.show()
model = Model()
model.setLogger(Logger.IJ_LOGGER)
slicenb=str(imp.getNSlices())
print(slicenb)
settings =Settings(imp)
#imp=IJ.selectWindow("VWF_043_MS211126_m4-pltdepletionmovie2_P1<3_Ch3_xyzCorrected.tif -_Ch7.tif")
#settings = Settings(IJ.selectWindow("VWF_043_MS211126_m4-pltdepletionmovie2_P1<3_Ch3_xyzCorrected.tif -_Ch7.tif"))
print("hello", settings)


##		settings.detectorFactory = LogDetectorFactory()#change to Threshold detector, intensity threshold auto
##		settings.detectorSettings = { 
##		    'DO_SUBPIXEL_LOCALIZATION' : True,
##		    'RADIUS' : 2.5,#2.5
##		    'TARGET_CHANNEL' : 1,
##		    'THRESHOLD' : 0.,
##		    'DO_MEDIAN_FILTERING' : False,
##		}
#		settings.detectorFactory = ThresholdDetectorFactory()
#		settings.detectorSettings = { 
#		    'TARGET_CHANNEL' : 1,
#		    'INTENSITY_THRESHOLD' : 0.,
#		    'SIMPLIFY_CONTOURS' : True,
#		}
#		filter1 = FeatureFilter('QUALITY', 30, True)#30
#		settings.addSpotFilter(filter1)
#		settings.trackerFactory = SparseLAPTrackerFactory()
#		settings.trackerSettings = LAPUtils.getDefaultLAPSettingsMap() # almost good enough
#		settings.trackerSettings['ALLOW_TRACK_SPLITTING'] = False #was True
#		settings.trackerSettings['ALLOW_TRACK_MERGING'] = False #was True
#		settings.addTrackAnalyzer(TrackDurationAnalyzer())
#		#settings.addTrackAnalyzer() #was used in a different script, but doesn't work
#		filter2 = FeatureFilter('TRACK_DISPLACEMENT', 20, True)#was 10
#		settings.addTrackFilter(filter2)
#		trackmate = TrackMate(model, settings) #gave error trackmate not defined
#		print(trackmate)
#		#print(settings)
#        ok = trackmate.checkInput()
#        if not ok:
#            sys.exit(str(trackmate.getErrorMessage())) #gave error nonetype # the source image is null
#            
#        ok = trackmate.process()
#        if not ok:
#            sys.exit(str(trackmate.getErrorMessage()))
#
#        selectionModel = SelectionModel(model)
#        ds = DisplaySettingsIO.readUserDefault()#from a different script
#        displayer =  HyperStackDisplayer(model, selectionModel, imp, ds)#added ds
#        displayer.render()
#        displayer.refresh()
#        model.getLogger().log( str( model ) )
##
#        exportSpotsAsDots = False
#        exportTracksOnly = False
#        #noticed a third option when using trackmate but not found in the code github
#        lblImg = LabelImgExporter.createLabelImagePlus(trackmate, exportSpotsAsDots, exportTracksOnly )#tried selectionModel, imp
#		lblImg.show()#gave error expecting dedent
#		IJ.saveAs("Tiff", os.path.join('/Users/secchim/Downloads/CellProfiler/corrected_movies_movie_example/output_test_trackmate', unique_file +'_Ch7.tif'))
		#IJ.run("Close All")#gave error expecting dedent
		
		
##EXPLORATION OF CODE
		
#im4D=True
#im4D_option= im4D
#sequence=['/Users/secchim/Downloads/CellProfiler/corrected_movies_movie_example/test_trackmate_plugin/VWF_043_MS211126_m4-pltdepletionmovie2_P1<3_Ch3_xyzCorrected.tif - T=0SP.tiff','/Users/secchim/Downloads/CellProfiler/corrected_movies_movie_example/test_trackmate_plugin/VWF_043_MS211126_m4-pltdepletionmovie2_P1<3_Ch3_xyzCorrected.tif - T=1SP.tiff','/Users/secchim/Downloads/CellProfiler/corrected_movies_movie_example/test_trackmate_plugin/VWF_043_MS211126_m4-pltdepletionmovie2_P1<3_Ch3_xyzCorrected.tif - T=2SP.tiff']
#for i in sequence:
#	imp=IJ.openImage(i)
#	slicenb=str(imp.getNSlices())
#	filenb=str(len(sequence))
#	#print(nSlices(imp))
#	imp.show()
#	print(slicenb, filenb)
#IJ.run("Concatenate...", "all_open im4D_option")
#IJ.selectWindow('Untitled')
#IJ.run("Properties...", "channels=1 slices="+slicenb+" frames="+filenb+" pixel_width=1.0000 pixel_height=1.0000 voxel_depth=1.0000")
#IJ.run("Make Substack...", "slices=1-"+slicenb+" frames=1-"+filenb+"")




		#IJ.run("Concatenate...", "all_open title=["+unique_file+".tif"+"]")
		#imp=IJ.Concatenator.run()
		#imp.show()
		#imp=WindowManager, getCurrentImage()
		#imp.show() #gave error noneType
		