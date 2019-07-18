#libVersion=Release_x64
#libVersion=Debug_x64
#libVersion=Release_Developer_x64
libVersion=Release_x64
#visionVersion=Release
#visionVersion=Release_Developer
visionVersion=Release

rm /X/packages/Compac.CodeMeterLicensing.Native.Protected.6.80.3/lib/native/v140/x64/Release/*
cp -rf /Y/${libVersion}/NativeLicensingProtected.* /X/packages/Compac.CodeMeterLicensing.Native.Protected.6.80.3/lib/native/v140/x64/Release/
echo "copy Compac.CodeMeterLicensing.Native.Protected"
ls /X/packages/Compac.CodeMeterLicensing.Native.Protected.6.80.3/lib/native/v140/x64/Release/

rm /X/packages/Compac.CodeMeterLicensing.Native.Core.6.80.3/lib/native/v140/x64/Release/*
cp -rf /Y/${libVersion}/NativeLicensingCore.* /X/packages/Compac.CodeMeterLicensing.Native.Core.6.80.3/lib/native/v140/x64/Release/
echo "copy Compac.CodeMeterLicensing.Native.Core"
ls /X/packages/Compac.CodeMeterLicensing.Native.Core.6.80.3/lib/native/v140/x64/Release/

rm /Y/${visionVersion}/WupiEngine64.dll
cp -rf /Y/${libVersion}/WupiEngine64.dll /Y/${visionVersion}/
echo "copy WupiEngine64.dll"
ls /Y/${visionVersion}/Wupi*
