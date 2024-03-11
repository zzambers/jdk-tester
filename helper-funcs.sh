#!/bin/sh

set -eu

getJdkVer() {
    jdkDir="$1"
    verNumFile1="${jdkDir}/make/conf/version-numbers.conf"
    verNumFile2="${jdkDir}/make/autoconf/version-numbers"
    verNumFile3="${jdkDir}/common/autoconf/version-numbers"
    if [ -f "${verNumFile1}" ] ; then
        verNumFile="${verNumFile1}"
    elif [ -f "${verNumFile2}" ] ; then
        verNumFile="${verNumFile2}"
    elif [ -f "${verNumFile3}" ] ; then
        verNumFile="${verNumFile3}"
    else
        printf '%s\n' "Could not find file with version numbers!" 2>&1
        return 1
    fi
    verPattern1='^DEFAULT_VERSION_FEATURE=([0-9]+).*$'
    verPattern2='^DEFAULT_VERSION_MAJOR=([0-9]+).*$'
    verPattern3='^JDK_MINOR_VERSION=([0-9]+).*$'
    if cat "${verNumFile}" | grep -q -E "${verPattern1}" ; then
        verPattern="${verPattern1}"
    elif cat "${verNumFile}" | grep -q -E "${verPattern2}" ; then
        verPattern="${verPattern2}"
    elif cat "${verNumFile}" | grep -q '^JDK_MAJOR_VERSION=1' \
        && cat "${verNumFile}" | grep -q -E "${verPattern3}" ; then
        verPattern="${verPattern3}"
    else
        printf '%s\n' "Could not find version property!" 2>&1
        return 1
    fi
    cat "${verNumFile}" \
    | grep -E "${verPattern}" \
    | head -n 1 \
    | sed -r "s/${verPattern}/\1/g"
}

getJtregVer() {
    testRootFile="${1}/test/jdk/TEST.ROOT"
    if [ -f "${testRootFile}" ] ; then
        verPattern='^requiredVersion=([0-9]+([.][0-9]+)?).*$'
        cat "${testRootFile}" \
        | grep -E "${verPattern}" \
        | head -n 1 \
        | sed -r "s/${verPattern}/\1/g"
        return 0
    fi
    echo "4.2"
}

getBootJdkVer() {
    if [ "$1" -lt 11 ] ; then
        echo 8
    elif [ "$1" -lt 17 ] ; then
        echo 11
    elif [ "$1" -lt 19 ] ; then
        echo 17
    elif [ "$1" -lt 20 ] ; then
        echo 19
    elif [ "$1" -lt 21 ] ; then
        echo 20
    else
        echo 21
    fi
}

detectVersionsGH() {
    JDK_VER="$( getJdkVer jdk )"
    echo "JDK_VER=${JDK_VER}" >> $GITHUB_ENV
    BOOT_JDK_VER=$( getBootJdkVer "${JDK_VER}" )
    echo "BOOT_JDK_VER=${BOOT_JDK_VER}" >> $GITHUB_ENV
    JTREG_VER="$( getJtregVer jdk )"
    echo "JTREG_VER=${JTREG_VER}" >> $GITHUB_ENV
}

prepareJtreg() {
    case "${JTREG_VER}" in
      4.2)
        jtregName="jtreg4.2-b16"
        ;;
      5|5.0)
        jtregName="jtreg5.0-b01"
        ;;
      5.1)
        jtregName="jtreg5.1-b01"
        ;;
      6)
        jtregName="jtreg-6+1"
        ;;
      6.1)
        jtregName="jtreg-6.1+2"
        ;;
      6.2)
        jtregName="jtreg-6.2+1"
        ;;
      7|7.*)
        jtregName="jtreg-7.3.1+1"
        ;;
      *)
        printf "Unsupported Jtreg version %s!\n" "${JTREG_VER}" 2>&1
        return 1
        ;;
    esac
    curl -L -f -o jtreg.zip "https://builds.shipilev.net/jtreg/${jtregName}.zip"
    unzip jtreg.zip
}


conigureJdk() {
    pushd jdk
    if [ "${JDK_VER}" -ge 11 ] ; then
        bash configure --with-boot-jdk="${JAVA_HOME}" --disable-warnings-as-errors --with-jtreg=../jtreg
    else
        bash configure --with-boot-jdk="${JAVA_HOME}" --with-jtreg=../jtreg
    fi
    popd
}

buildJdk() {
    pushd jdk
    make images
    popd
}

testJdk() {
    pushd jdk
    if [ "${JDK_VER}" -ge 11 ] ; then
        make run-test TEST="${JDK_TEST}" \
        JTREG="JAVA_OPTIONS=-Djdk.test.docker.image.name=ubuntu -Djdk.test.docker.image.version=latest"
    else
        JAVA_ARGS="-Djdk.test.docker.image.name=ubuntu -Djdk.test.docker.image.version=latest" \
        JTREG_TIMEOUT_FACTOR="4" \
        make test TEST="${JDK_TEST}"
    fi
    popd
}

packResults() {
    if [ "${JDK_VER}" -ge 11 ] ; then
        tar -C jdk/build/* -czf "test-results.tar.gz" test-results test-support
    else
        tar -C jdk/build/* -czf "test-results.tar.gz" --exclude=ARCHIVE_BUNDLE.zip testoutput
    fi
}
