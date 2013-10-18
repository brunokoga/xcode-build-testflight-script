#!/bin/sh

########################################################
#                                                      #
# Generic App build and Testflight Submission          #
# Author: Bruno Koga, October 2013                     #
#                                                      #
########################################################


# Arguments:
# -c                    Use CocoaPods
# -p PROJECT_NAME
# -s SCHEME_NAME
# -v VERSION
# -i ICON_PATH
# -n APP_NAME
# -t TESTFLIGHT_TEAM_TOKEN
# -a TESTFLIGHT_API_TOKEN
# -d TESTFLIGHT_DISTRIBUTION_LIST
# -r CERTIFICATE_NAME
# -f CONFIGURATION

USE_COCOA_PODS=NO
PROJECT_NAME=""
SCHEME_NAME=""
ICON_PATH=""
APP_NAME=""
TESTFLIGHT_TEAM_TOKEN=""
TESTFLIGHT_API_TOKEN=""
TESTFLIGHT_DISTRIBUTION_LIST=""
CERTIFICATE_NAME=""
CONFIGURATION=""

function test_args {
	if [[ $OPTARG = -* ]]; then
		echo "Invalid argument for -$opt: $OPTARG"
		exit 1
	fi
}

while getopts ":cp:s:f:i:n:t:a:d:r:" opt; do
	case $opt in
		c)
			USE_COCOA_PODS=YES
			;;
		p)
			test_args
			PROJECT_NAME=$OPTARG
			;;
		s)
			test_args
			SCHEME_NAME=$OPTARG
			;;
		i)
			test_args
			ICON_PATH=$OPTARG
			;;
		n)
			test_args
			APP_NAME=$OPTARG
			;;
		t)
			test_args
			TESTFLIGHT_TEAM_TOKEN=$OPTARG
			;;
		a)
			test_args
			TESTFLIGHT_API_TOKEN=$OPTARG
			;;
		d)
			test_args
			TESTFLIGHT_DISTRIBUTION_LIST=$OPTARG
			;;
		r)
			test_args
			CERTIFICATE_NAME=$OPTARG
			;;
		f)
			test_args
			CONFIGURATION=$OPTARG
			;;

		\?)
			echo "Invalid option: -$OPTARG" >&2
			;;
		:)
			echo "Option -$OPTARG requires an argument"
			;;
	esac
done

WORKSPACE_FILE=""
PROJECT_FILE=""
if [[ $USE_COCOA_PODS = YES ]]; then
	pod install
	WORKSPACE_FILE="${PROJECT_NAME}.xcworkspace"
else
	PROJECT_FILE="${PROJECT_NAME}.xcodeproj"
fi

# Workspace and build configuration
TARGET_SDK="iphoneos"								# Target SDK: iphoneos

BUILD_DIR="../build"                   	# Directory where the build is generated
BUILD_ARCHIVED_DIR="BuildArchived"					# Directory with the history of builds

#Release Notes
TESTFLIGHT_RELEASE_NOTES_FILE="ios_testflight-releasenotes"

# fix for the newest sdk
# Only export the environment variable if the location exists,
# otherwise it breaks the signing process!
if [ -f "/Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/codesign_allocate" ]
then
	  echo Export environment variable for codesign_allocate location
	    export CODESIGN_ALLOCATE=/Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/codesign_allocate
    fi


# Returns to the root directory` of the build
cd ..

PWD=`pwd`
PROJECT_BUILDDIR="${PWD}/build/${CONFIGURATION}-${TARGET_SDK}"

CURRENT_DIR="${PWD}/${TARGET_NAME}"

#changing the build version
INFO_PLIST_PATH="${CURRENT_DIR}/${PROJECT_NAME}/${PROJECT_NAME}-Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${SVN_REVISION}" "$INFO_PLIST_PATH"

# compile project
echo Building Project
xcodebuild \
	-workspace "${WORKSPACE_FILE}" \
	-scheme "${SCHEME_NAME}" \
	-configuration "${CONFIGURATION}" \
	OBJROOT="${PWD}/build" \
	SYMROOT="${PWD}/build" \
	clean build 

# .ipa file generation
echo Generating .ipa file 

echo "${PROJECT_BUILDDIR}"
# change to the project build dir to archive
/usr/bin/xcrun -sdk "${TARGET_SDK}" PackageApplication -v "${PROJECT_BUILDDIR}/${APP_NAME}.app" -o "${PROJECT_BUILDDIR}/${APP_NAME}.ipa" --sign "${CERTIFICATE_NAME}"

#zipping the .dSYM to send to Testflight
echo Generating zip file
/usr/bin/zip -r "${PROJECT_BUILDDIR}/${APP_NAME}.app.dSYM.zip" "${PROJECT_BUILDDIR}/${APP_NAME}.app.dSYM"

# sends the .ipa file to TestFlight

echo Sending to TestFlight
curl http://testflightapp.com/api/builds.json -F file="@${PROJECT_BUILDDIR}/${APP_NAME}.ipa" \
	-F dsym="@${PROJECT_BUILDDIR}/${APP_NAME}.app.dSYM.zip" \
	-F api_token="${TESTFLIGHT_API_TOKEN}" \
	-F team_token="${TESTFLIGHT_TEAM_TOKEN}" \
	-F notes="This build was uploaded via the upload API" \
	-F notify=False \
	-F distribution_lists="${TESTFLIGHT_DISTRIBUTION_LIST}" 
echo Submission ended
