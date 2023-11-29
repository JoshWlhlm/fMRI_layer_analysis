#!/bin/zsh

# prerequisit: FSL, LAYNII, MATLAB
# make sure to adjust the code to your individual directory


# Defining the input variables

# EPI ASL data
EPI_ASL_fmri_data="/Users/joshuwilhelm/Desktop/Test/P01_EPI_1p25mm_task_run2.nii"

# SPI ASL data
SPI_ASL_fmri_data="/Users/joshuwilhelm/Desktop/Test/P01_SPI_1p25mm_task_run2.nii"

# EPI_M0
EPI_M0_data="/Users/joshuwilhelm/Desktop/Test/P01_EPI_1p25mm_M0.nii"

# 1. Data quality check
#   - loading data files in FSL using FSLeyes 
#   - check volumes (are there weird jumps in data)
Fsleyes "$EPI_ASL_fmri_data" "$SPI_ASL_fmri_data"

# 2. Pre-processing
# not performed: slice scan time correction, distortion correction (EPI), correction for multiple testing

# 2.1 Motion correction (with M0 run if possible) 

# 2.1.1 motion correct EPI M0 run
mcflirt -in "$EPI_M0_data" -out "corrected_EPI_M0"
fslmaths "corrected_EPI_M0" -Tmean "Mean_EPI_M0"

# 2.1.2 motion correct fMRI data using mean M0 image as reference
mcflirt -in "$EPI_ASL_fmri_data" -reffile "Mean_EPI_M0.nii.gz" -out "corrected_EPI_ASL_fmri_data" -cost normmii -plots

# 2.1.3 visual inspection: open reference image and motion corrected data in FSLeyes
Fsleyes "corrected_EPI_ASL_fmri_data" "Mean_EPI_M0"

# 2.1.4 extract the first volume of the SPI data to use as reference image for motion correction
fslroi "$SPI_ASL_fmri_data" "SPI_reference" 0 1 

# 2.2 create brain masks for brain extraction

# EPI
bet "Mean_EPI_M0.nii.gz" "EPI_brain_mask" -f 0.3 -g 0 -m

# SPI
bet "SPI_reference.nii.gz" "SPI_brain_mask" -f 0.3 -g 0 -m

# 2.3 masking the 4D timeseries using the brain masks

# EPI
fslmaths "$EPI_ASL_fmri_data" -mul "EPI_brain_mask.nii.gz" "EPI_masked"

# SPI
fslmaths "$SPI_ASL_fmri_data" -mul "SPI_brain_mask.nii.gz" "SPI_masked"

# 2.3 perfusion average and perfusion subtraction 

# navigate to directory where .sh files are stored
cd /Users/joshuwilhelm/Desktop/Test/Functional_analysis

# make executable with superuser privileges 
sudo chmod +x ./perfusion_average.sh
sudo chmod +x ./perfusion_subtract.sh

# execute the scripts on the functional data --> make sure that you put the according files in the path prior to executing

# EPI BOLD
./perfusion_average.sh "EPI_masked.nii.gz" "EPI_masked_perf_average"

# EPI ASL
./perfusion_subtract.sh "EPI_masked.nii.gz" "EPI_masked_perf_subtract"

# SPI BOLD
./perfusion_average.sh "SPI_masked.nii.gz" "SPI_masked_perf_average"

# SPI ASL
./perfusion_subtract.sh "SPI_masked.nii.gz" "SPI_masked_perf_subtract"

# 2.4 GLM with FSL Feat

# open FSL
FSL

# run FSLfeat --> you can put in the data and select specifications manually using the FSLfeat GUI

# do GLM for EPI_masked_perf_subtract, SPI_masked_perf_average, and SPI_masked_perf_subtract

# Display the zstat1 maps on top of the reference image (use lightbox view as well --> manual selection in fsleyes)
# run these commands individually since all files have the same name "zstat1" and otherwise you won't be able to differentiate between them

FSLeyes "Mean_EPI_M0.nii.gz" "./EPI_masked_average.feat/stats/zstat1.nii.gz" -dr 2 10 -cm hot 

FSLeyes "Mean_EPI_M0.nii.gz" "./EPI_masked_subtract.feat/stats/zstat1.nii.gz" -dr 2 10 -cm hot 

FSLeyes "Mean_EPI_M0.nii.gz" "./SPI_masked_average.feat/stats/zstat1.nii.gz" -dr 2 10 -cm hot 

FSLeyes "Mean_EPI_M0.nii.gz" "./SPI_masked_subtract.feat/stats/zstat1.nii.gz" -dr 2 10 -cm hot 

# collect the zstat1 files from the .feat folders that have been created and save them with appropriate names in new folder for layer analysis
cd /Users/joshuwilhelm/Desktop/Test/Layer_analysis

# 2.5 Layer Analysis

# 2.5.1 use FSLeyes to open the reference image and the zstat activation maps of BOLD and ASL for EPI and for SPI separately

FSLeyes "EPI_brain_mask.nii.gz" "EPI_BOLD.nii.gz" -dr 2 10 -cm hot "EPI_ASL.nii.gz" -dr 2 10 -cm hot 

FSLeyes "SPI_brain_mask.nii.gz" "SPI_BOLD.nii.gz" -dr 2 10 -cm hot "SPI_ASL.nii.gz" -dr 2 10 -cm hot 

# The following command lines for the upsampling are taken from the LAYNII repository by layerfMRI on Github
# Upsample EPI
delta_x=$(3dinfo -di EPI_brain_mask.nii.gz)
delta_y=$(3dinfo -dj EPI_brain_mask.nii.gz)
delta_z=$(3dinfo -dk EPI_brain_mask.nii.gz)
sdelta_x=$(echo "((sqrt($delta_x * $delta_x) / 5))"|bc -l)
sdelta_y=$(echo "((sqrt($delta_y * $delta_y) / 5))"|bc -l)
sdelta_z=$(echo "((sqrt($delta_z * $delta_z) / 1))"|bc -l) 
# here I only upscale in 2 dimensions. 
#3dresample -dxyz $sdelta_x $sdelta_y $sdelta_z -rmode NN -overwrite -prefix scaled_$1 -input $1 
3dresample -dxyz $sdelta_x $sdelta_y $sdelta_z -rmode Cu -overwrite -prefix scaled_Mean_M0.nii -input EPI_brain_mask.nii.gz
3dresample -dxyz $sdelta_x $sdelta_y $sdelta_z -rmode Cu -overwrite -prefix scaled_EPI_BOLD.nii -input EPI_BOLD.nii.gz
3dresample -dxyz $sdelta_x $sdelta_y $sdelta_z -rmode Cu -overwrite -prefix scaled_EPI_ASL.nii -input EPI_ASL.nii.gz

# Upsample EPI
delta_x=$(3dinfo -di SPI_reference.nii.gz)
delta_y=$(3dinfo -dj SPI_reference.nii.gz)
delta_z=$(3dinfo -dk SPI_reference.nii.gz)
sdelta_x=$(echo "((sqrt($delta_x * $delta_x) / 5))"|bc -l)
sdelta_y=$(echo "((sqrt($delta_y * $delta_y) / 5))"|bc -l)
sdelta_z=$(echo "((sqrt($delta_z * $delta_z) / 1))"|bc -l) 
# here I only upscale in 2 dimensions. 
#3dresample -dxyz $sdelta_x $sdelta_y $sdelta_z -rmode NN -overwrite -prefix scaled_$1 -input $1 
3dresample -dxyz $sdelta_x $sdelta_y $sdelta_z -rmode Cu -overwrite -prefix scaled_Reference.nii -input SPI_brain_mask.nii.gz
3dresample -dxyz $sdelta_x $sdelta_y $sdelta_z -rmode Cu -overwrite -prefix scaled_SPI_BOLD.nii -input SPI_BOLD.nii.gz
3dresample -dxyz $sdelta_x $sdelta_y $sdelta_z -rmode Cu -overwrite -prefix scaled_SPI_ASL.nii -input SPI_ASL.nii.gz

# draw ROIs by hand where you want to do the layer analysis. From an image that provides good anatomical contrast between CSF/GM/WM
# name the file rim_EPI.nii and rim_SPI.nii

#estimating layers based on rim
LN_GROW_LAYERS -rim rim_EPI.nii -N 11 -vinc 40

LN_GROW_LAYERS -rim rim_SPI.nii -N 11 -vinc 40

# Layer analysis with LN2_Profile
LN2_Profile -input EPI_BOLD.nii.gz -layers rim_EPI_layers.nii -plot -output EPI_BOLD_layer_profile.txt

LN2_Profile -input EPI_ASL.nii.gz -layers rim_EPI_layers.nii -plot -output EPI_ASL_layer_profile.txt

LN2_Profile -input SPI_BOLD.nii.gz -layers rim_SPI_layers.nii -plot -output SPI_BOLD_layer_profile.txt

LN2_Profile -input SPI_ASL.nii.gz -layers rim_SPI_layers.nii -plot -output SPI_ASL_layer_profile.txt

# Plot .txt files with MATLAB

# example .m file 

# EPI layers ASL vs BOLD
/Applications/MATLAB_R2022a.app/bin/matlab -r "run('./Plot_EPI_layer_profiles.m');"

# SPI layers ASL vs BOLD
/Applications/MATLAB_R2022a.app/bin/matlab -r "run('./Plot_SPI_layer_profiles.m');"

# EPI vs SPI ASL layer profiles
/Applications/MATLAB_R2022a.app/bin/matlab -r "run('./Plot_EPIvsSPI_ASL_layer_profiles.m');"