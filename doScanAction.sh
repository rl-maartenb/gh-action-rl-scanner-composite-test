#! /usr/bin/env bash

set +e # we are here in control of -e flag and we dont need it now

FILE_TO_SCAN=""
REPORT_DIR=""

usage()
{
    echo "Usage: $0 -f <file-to-scan> -r <report-directory>" 1>&2
    exit 1
}

parameters()
{
    while getopts ":f:r:" o
    do
        case "${o}" in
            f)  # the file to scan
                f=${OPTARG}
                [ ! -f "${f}" ] && {
                    echo "ERROR: the file specified '${f}' cannot be found, the fle to scan must exist already" >&2
                    usage
                }
                ;;

            r) # the report directory, must not already exist
                r=${OPTARG}
                [ -e "${r}" ] && {
                    echo "ERROR: '${r}' already exists, please specify a directory path that does not yet exist" >&2
                    usage
                }
                ;;

            *)
                usage
                ;;
        esac
    done

    shift $((OPTIND-1))

    [ -z "${r}" ] && {
        r="MyReportDir"
        [ -e "${r}" ] && {
            echo "ERROR: '${r}' already exists, please specify a directory path that does not yet exist" >&2
            usage
        }
    }

    [ -z "${f}" ] && {
      usage
    }

    FILE_TO_SCAN="${f}"
    REPORT_DIR="${r}"
}

# ----------------------------
prepare()
{
    xFile=$( basename "${FILE_TO_SCAN}" )
    xDir=$( dirname "${FILE_TO_SCAN}" )
    xDir=$( realpath $xDir )

    # rm -rf "${REPORT_DIR}" && mkdir "${REPORT_DIR}"
    mkdir "${REPORT_DIR}"
    xReport=$( realpath "${REPORT_DIR}" )
}

# ---------------------------
doScan()
{
    docker run --rm \
        -e RLSECURE_ENCODED_LICENSE \
        -e RLSECURE_SITE_KEY \
        -v ${xReport}:/report \
        -v ${xDir}:/packages:ro \
        reversinglabs/rl-scanner \
        rl-scan \
            --package-path=/packages/${xFile} \
            --report-path=/report \
            --report-format=all 2>2 1>1
    RR=$?

    cat 1
    STATUS=$( grep 'Scan result:' 1 )
}

# ---------------------------
statusError()
{
    [ -z "$STATUS" ] && {
        cat 2

        msg="Fatal: cannot find the Scan result in the output"
        echo "::error::$msg"
        echo "$msg" >> $GITHUB_STEP_SUMMARY

        echo "description=$msg" >> $GITHUB_OUTPUT
        echo "status=error" >> $GITHUB_OUTPUT

        exit 101
    }
}

# ---------------------------
statusPassFail()
{
    echo "description=$STATUS" >> $GITHUB_OUTPUT
    echo "$STATUS" >> $GITHUB_STEP_SUMMARY

    echo "$STATUS" | grep -q FAIL
    if [ "$?" == "0" ]
    then
        echo "status=failure" >> $GITHUB_OUTPUT
        echo "::error::$STATUS"
    else
        echo "status=success" >> $GITHUB_OUTPUT
        echo "::notice::$STATUS"
    fi

}

# ---------------------------
main()
{
    parameters $*
    prepare
    doScan
    statusError
    statusPassFail

    exit ${RR}
}

main $*
