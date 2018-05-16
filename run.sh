#!/bin/bash

if [ -z ${JAVA_HOME} ]; then
    export JAVA_HOME="/usr/lib/jvm/java-8-openjdk-amd64"
fi

# these options help catch errors.
# 'nounset' throws an error if a parameter being used is undefined.
# 'errexit' causes any error condition to terminate the script, so it doesn't continue running.
set -o nounset
#set -o errexit

# this just makes it easier to change users if the repos are organized the same as below.
HOME="/home/dse"

# this is the location of the danalyzer repo
DANALYZER_REPO="${HOME}/Projects/isstac/danalyzer/"

# this is the location of the danhelper agent repo
DANHELPER_REPO="${HOME}/Projects/isstac/danhelper/"

# this is where to build and run the danalyzer-instrumented files.
TESTPATH="${HOME}/Projects/isstac/DSETests/"


# adds specified jar file to $CLASSPATH
#
# inputs: $1 = jar file (plus full path) to add
#
function add_to_classpath
{
    if [[ -z $1 ]]; then
        return
    fi

    if [[ -z ${CLASSPATH} ]]; then
        CLASSPATH="$1"
    else
        CLASSPATH="${CLASSPATH}:$1"
    fi
    # echo "  added: $1"
}

function check_special_canonicals
{
    # for category 1-10, there are no other options
    NUMBER=${NUMBER:0:2}
    if [[ ${NUMBER} -lt 11 ]]; then
        return
    fi

    # if user did not make A or B selection, ask him for it
    if [[ ${SELECT} != "A" && ${SELECT} != "B" ]]; then
        echo "Canonical ${NUMBER} requires either an A or B selection:"
        read -s -n 1 SELECT
        SELECT=$(echo "${SELECT}" | tr '[:lower:]' '[:upper:]' 2>&1)
        if [[ ${SELECT} != "A" && ${SELECT} != "B" ]]; then
            echo "Invalid selection, case 'A' is chosen by default"
            SELECT="A"
        fi
    fi

    # create the corresponding file name
    case ${NUMBER} in
        11) SUFFIX="_Case_${SELECT}${SUFFIX}"
            ;;
        12) if [[ "${SELECT}" == "A" ]]; then
                SUFFIX="${SUFFIX}_conditional"
            else
                SUFFIX="${SUFFIX}_exception"
            fi
            ;;
        *)
            echo "Invalid category selection: ${NUMBER}"
            exit 1
            ;;
    esac
}

function get_project_info
{
    if [[ ${PROJECT} == "Category"* ]]; then
        NUMBER=${PROJECT:8}
        SELECT=${NUMBER:2}

        if [[ ${NONVULNERABLE} -eq 0 ]]; then
            SUFFIX="_vulnerable"
        else
            SUFFIX="_not_vulnerable"
        fi

        # handle special canonical cases
        check_special_canonicals

        # define the paths and files to use
        PROJDIR="${TESTPATH}Canonical/Category${NUMBER}"
        PROJJAR=${PROJECT}

        if [[ ${NEWREF} -eq 0 ]]; then
            SRCDIR="${TESTPATH}Canonical/Source/src_E1_E4/e1e4"
            MAINCLASS="e1e4/Category${NUMBER}${SUFFIX}"
        else
            SRCDIR="${TESTPATH}Canonical/Source/src"
            MAINCLASS="Category${NUMBER}${SUFFIX}"
        fi
    else
        echo "Invalid test selection: ${PROJECT}"
        exit 1
    fi
}

#------------------------- START FROM HERE ---------------------------
# Usage: run.sh [-t] [-f]
# Where: -t = don't build, just show commands
#        -f = force rebuild of danhelper agent

# save current path
CURDIR=$(pwd 2>&1)
PROJDIR=""

FORCE=0
TESTMODE=0
NEWREF=0
NONVULNERABLE=0
MAINCLASS=""

# read options
COMMAND=()
while [[ $# -gt 0 ]]; do
    key="$1"
    case ${key} in
        -t|--test)
            TESTMODE=1
            shift
            ;;
        -f|--force)
            FORCE=1
            shift
            ;;
        *)
            COMMAND+=("$1")
            shift
            ;;
    esac
done

# the 1st remaining word is the project name and the remainder terms are the optional arguments
#PROJECT="${COMMAND[@]:0:1}"
#ARGLIST="${COMMAND[@]:1}"
# ignore the above - the SymbolicExplorer currently only works for Category7_vulnerable
PROJECT="Category7"
ARGLIST="5"

# check if agent lib has been built
NOAGENT=0
AGENTLIBDIR="${DANHELPER_REPO}src/"
if [ ! -f "${AGENTLIBDIR}libdanhelper.so" ]; then
    if [ -f "${DANHELPER_REPO}libdanhelper.so" ]; then
        AGENTLIBDIR="${DANHELPER_REPO}"
    else
        NOAGENT=1
    fi
fi

# build agent
if [[ ${NOAGENT} -ne 0 || ${FORCE} -ne 0 ]]; then
    # these next commands run from the danhelper (agent) path
    cd ${DANHELPER_REPO}
    if [[ ${TESTMODE} -ne 0 ]]; then
        echo
        echo "  (from: ${DANHELPER_REPO})"
    fi

    echo "- building danhelper agent"
    if [[ ${TESTMODE} -eq 0 ]]; then
        make
        if [ -f "${DANHELPER_REPO}src/libdanhelper.so" ]; then
            mv ${DANHELPER_REPO}src/libdanhelper.so ${DANHELPER_REPO}libdanhelper.so
            AGENTLIBDIR="${DANHELPER_REPO}"
        fi
    else
        echo "make"
    fi
fi

# next, build the specified project and instrument it
cd ${DANHELPER_REPO}
if [[ ${TESTMODE} -eq 0 ]]; then
    ./make.sh ${PROJECT} ${ARGLIST}
else
    ./make.sh -t ${PROJECT} ${ARGLIST}
fi

# return to SymbolicExplorere path to run the rest
cd ${CURDIR}
if [[ ${TESTMODE} -ne 0 ]]; then
    echo
    echo "  (from: ${CURDIR})"
fi

# need to determine the project values: PROJDIR, PROJJAR, MAINCLASS
get_project_info

# now update the SymbolicExplorer that uses both danalyzer and the instrumented project
echo "- building SymbolicExplorer"
CLASSPATH=""
add_to_classpath "${DANALYZER_REPO}lib/commons-io-2.5.jar"
add_to_classpath "${DANALYZER_REPO}lib/asm-all-5.2.jar"
add_to_classpath "${DANALYZER_REPO}lib/com.microsoft.z3.jar"
add_to_classpath "${DANALYZER_REPO}/dist/danalyzer.jar"
add_to_classpath "${PROJDIR}/${PROJJAR}-dan-ed.jar"
if [[ ${TESTMODE} -eq 0 ]]; then
    javac -cp ${CLASSPATH} explorer/Explorer.java
    if [[ $? -ne 0 ]]; then
        echo "ERROR: javac command failure"
        exit 1
    fi
else
    echo "javac -cp ${CLASSPATH} explorer/Explorer.java"
fi
if [[ ${TESTMODE} -eq 0 ]]; then
    jar cvf Explorer.jar explorer/Explorer.class
    if [[ $? -ne 0 ]]; then
        echo "ERROR: jar command failure"
        exit 1
    fi
else
    echo "jar cvf Explorer.jar explorer/Explorer.class"
fi
rm -f explorer/Explorer.class

# make sure classlist was copied to current dir
if [[ ! -f ${PROJDIR}/classlist.txt && ${TESTMODE} -eq 0 ]]; then
    echo "ERROR: classlist.txt not found in: ${PROJDIR}"
    exit 1
fi
echo "- copying classlist.txt to SymbolicExplorer"
cp ${PROJDIR}/classlist.txt .

# add Explorer.jar to the classpath
CLASSPATH="Explorer.jar:${CLASSPATH}"

# make sure we have a danfig file defined with symbolic definitions
if [[ ! -f ${CURDIR}/danfig && ${TESTMODE} -eq 0 ]]; then
    echo "ERROR: danfig not found in: ${CURDIR}"
    exit 1
fi

# run the instrumented code with the agent
OPTIONS="-Xverify:none -Dsun.boot.library.path=$JAVA_HOME/bin:/usr/lib"
BOOTCLASSPATH="-Xbootclasspath/a:${DANALYZER_REPO}dist/danalyzer.jar:${DANALYZER_REPO}lib/com.microsoft.z3.jar"
AGENTPATH="-agentpath:${AGENTLIBDIR}libdanhelper.so"
MAINCLASS="explorer.Explorer"

echo "- running SymbolicExplorer"
if [[ ${TESTMODE} -eq 0 ]]; then
    java ${OPTIONS} ${BOOTCLASSPATH} ${AGENTPATH} -cp ${CLASSPATH} ${MAINCLASS}
else
    echo "java ${OPTIONS} ${BOOTCLASSPATH} ${AGENTPATH} -cp ${CLASSPATH} ${MAINCLASS}"
fi
