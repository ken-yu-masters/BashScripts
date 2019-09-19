#/usr/bin/bash
#replace "VisionLicensing::GetInstance()->GetFeatures()" with "VisionLicensing::GetInstance()"
#xargs -d '\n' deal with spaces in file name
#need use --binary, or line end will be changed to unix format.
#
find . -type f -iname '*.cpp' -o -iname '*.c' -o -iname '*.h' -o -iname '*.hpp' | xargs -d '\n' sed --binary --in-place 's/VisionLicensing::GetInstance()->GetFeatures()/VisionLicensing::GetInstance()/g'