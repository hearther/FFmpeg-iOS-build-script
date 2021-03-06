#!/bin/sh

CONFIGURE_FLAGS="--enable-static --with-pic=yes --disable-shared"

ARCHS="arm64 armv7s x86_64 i386 armv7"

# directories
SOURCE="fdk-aac"
FAT="fdk-aac-iOS"

SCRATCH="scratch"
# must be an absolute path
THIN=`pwd`/"thin"

COMPILE="y"
LIPO="y"

DEPLOYMENT_TARGET="6.0"

if [ "$*" ]
then
	if [ "$*" = "lipo" ]
	then
		# skip compile
		COMPILE=
	else
		ARCHS="$*"
		if [ $# -eq 1 ]
		then
			# skip lipo
			LIPO=
		fi
	fi
fi

if [ "$COMPILE" ]
then
	if [ ! -r $SOURCE ]
	then
		echo 'fdk-aac source not found. Trying to clone...'
		git clone https://github.com/mstorsjo/fdk-aac.git \
			|| exit 1
	fi
	CWD=`pwd`
	for ARCH in $ARCHS
	do
		echo "building $ARCH..."
		mkdir -p "$SCRATCH/$ARCH"
		cd "$SCRATCH/$ARCH"

		CFLAGS="-arch $ARCH"

		if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" ]
		then
		    PLATFORM="iPhoneSimulator"
		    CPU=
		    CFLAGS="$CFLAGS -mios-simulator-version-min=$DEPLOYMENT_TARGET"
		    if [ "$ARCH" = "x86_64" ]
		    then
		    	HOST=
		    else		    	
				HOST="--host=i386-apple-darwin"
		    fi
		else
		    PLATFORM="iPhoneOS"
		    CFLAGS="$CFLAGS -mios-version-min=$DEPLOYMENT_TARGET"
		    if [ $ARCH = arm64 ]
		    then
		        #CFLAGS="$CFLAGS -D__arm__ -D__ARM_ARCH_7EM__" # hack!
		        HOST="--host=aarch64-apple-darwin"
                    else
		        HOST="--host=arm-apple-darwin"
	            fi
		    SIMULATOR=
		fi
		echo  "herrrrrrr $CFLAGS"
		
		XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
		CC="xcrun -sdk $XCRUN_SDK clang -Wno-error=unused-command-line-argument"
		echo  "herrrrrrr $CC"
		AS="$CWD/$SOURCE/extras/gas-preprocessor.pl $CC"
		CXXFLAGS="$CFLAGS"
		LDFLAGS="$CFLAGS"

		$CWD/$SOURCE/configure \
		    $CONFIGURE_FLAGS \
		    $HOST \
		    $CPU \
		    CC="$CC" \
		    CXX="$CC" \
		    CPP="$CC -E" \
                    AS="$AS" \
		    CFLAGS="$CFLAGS" \
		    LDFLAGS="$LDFLAGS" \
		    CPPFLAGS="$CFLAGS" \
		    CXXFLAGS="$CFLAGS" \
		    --prefix="$THIN/$ARCH"

		make -j3 install
		cd $CWD
	done
fi

if [ "$LIPO" ]
then
	echo "building fat binaries..."
	echo $THIN
	mkdir -p $FAT/lib
	set - $ARCHS
	CWD=`pwd`
	cd $THIN/$1/lib
	for LIB in *.a
	do
		pwd
		cd $CWD
		lipo -create `find $THIN -name $LIB` -output $FAT/lib/$LIB
	done

	cd $CWD
	cp -rf $THIN/$1/include $FAT
fi
