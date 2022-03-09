#! /bin/bash

file_contains_string(){
    if grep -q "$2" "$1"; then
        true
    else 
        false
    fi
}

# input is a github link of repository, e.g., https://github.com/spring-projects/spring-framework
# Todo: handle the situations when the repository is redirected: jq: error (at <stdin>:5): Cannot index string with string "name"
isMavenProj(){
    id=${1#"https://github.com/"}
    # echo Checking whether $id is a maven project...
    pomNum=$(curl "https://api.github.com/repos/$id/contents/" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Authorization: Token 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" 2>/dev/null | jq -r '.[].name' | grep -c pom.xml)
    if [ $pomNum -ge 1 ]; then
        true
    else
        false
    fi
}

# transform the $url 
fixRepoUrl(){
    if [[ $url == *"gitbox.apache.org"* ]];then
        url=$(echo $url | sed 's,?p=,/,')
    fi
}

getLibRepoUrl(){
    url=$(curl -H "Accept: application/json" -H "Content-Type: application/json" -X GET "https://libraries.io/api/maven/commons-io:commons-io?api_key=80be6c2040e9c5266d6c507bdbbcecdb" 2>/dev/null | jq -r '.repository_url')
    while [ ! $url ]; do
        url=$(curl -H "Accept: application/json" -H "Content-Type: application/json" -X GET "https://libraries.io/api/maven/commons-io:commons-io?api_key=80be6c2040e9c5266d6c507bdbbcecdb" 2>/dev/null | jq -r '.repository_url')
    done
    fixRepoUrl
}

# input is the url after fix, e.g., 'https://gitbox.apache.org/repos/asf/commons-io.git'
getRepoAtNameFromUrl(){
    if [[ $url == *"gitbox.apache.org"* ]];then
        tmp=$(echo $url | sed 's,https://gitbox.apache.org/repos/asf/\(.*\).git,\1,')
        repoAtName=apache@$tmp
    elif [[ $url == *"github.com"* ]]; then
        repoAtName=$(echo "${url##https://github.com/}" | sed 's,/,@,')
    fi
}

log(){
    time=$(date "+%m/%d %T")
    echo "[$time] ""$1" >> $covDiffLog
}

pwd=$(pwd)
per_page=100
page_num=10
searchDir=search
[ ! -d $searchDir ] && mkdir -p $searchDir
repoDir=repo
[ ! -d $repoDir ] && mkdir -p $repoDir

# get a lib id
if [ $# -ne 1 ]; then
    echo need one argument as library id, e.g., junit:junit
    exit 1
else
    libid=$1
    libSearchDir=$searchDir/$libid
    [ ! -d $libSearchDir ] && mkdir -p $libSearchDir
    [ ! -d logs ] && mkdir logs
    covDiffLog=$pwd/logs/$libid.log
    tmp=$(echo "===========$libid===========" | sed 's/./=/g')
    log $tmp
    log "========== $libid =========="
    log $tmp
    log ""
fi

# find clients that using that lib
if [ ! -f $libSearchDir/dependents-all ]; then
    echo Finding the clients using the library...
    echo -n > $libSearchDir/dependents-all
    for ((i=1; i<page_num+1; i++)); do
        if [ -f $libSearchDir/"dependents-p$i" ];then
            cat "$libSearchDir/dependents-p$i" | jq -r '.[] | "\(.name)@\(.repository_url)@\(.latest_release_number)"' >> $libSearchDir/dependents-all
            continue
        fi
        echo "Search for $libid dependents page $i..."
        curl -H "Accept: application/json" -H "Content-Type: application/json" -X GET "https://libraries.io/api/maven/$libid/dependents?api_key=80be6c2040e9c5266d6c507bdbbcecdb&per_page=$per_page&page=$i" > $libSearchDir/"dependents-p$i"  2>/dev/null
        while [[ ! $(cat "$libSearchDir/dependents-p$i" | jq -r '.[] | "\(.name)@\(.repository_url)"') ]]; do
            echo "No results found, retrying..."
            sleep 1
            curl -H "Accept: application/json" -H "Content-Type: application/json" -X GET "https://libraries.io/api/maven/$libid/dependents?api_key=80be6c2040e9c5266d6c507bdbbcecdb&per_page=$per_page&page=$i" > $libSearchDir/"dependents-p$i"   2>/dev/null
        done
        # cat "$libSearchDir/dependents-p$i" | jq -r '.[] | "\(.name)@\(.repository_url)@\(.versions|last|.number)"' >> $libSearchDir/dependents-all
        cat "$libSearchDir/dependents-p$i" | jq -r '.[] | "\(.name)@\(.repository_url)@\(.latest_release_number)"' >> $libSearchDir/dependents-all
    done
fi

# filter the maven projects
if [ ! -f $libSearchDir/dependents-maven ]; then
    echo Finding out the clients using maven...
    echo -n > $libSearchDir/dependents-maven
    while read -r dependents; do
        clientid=${dependents%%@*}
        clientRepo=${dependents#*@}
        clientRepo=${clientRepo%@*}
        if isMavenProj $clientRepo; then
            echo $dependents >> $libSearchDir/dependents-maven
        fi
    done < $libSearchDir/dependents-all
fi

# find out the version clients are using
if [ ! -f $libSearchDir/dependents-version ]; then
    echo Finding out the versions the clients are using...
    echo -n > $libSearchDir/dependents-version
    while read -r dependent; do
        clientid=${dependent%%@*}
        clientRepo=${dependent#*@}
        clientRepo=${clientRepo%@*}
        version=${dependent##*@}
        # echo "curl -H" "\"Accept: application/json\"" "-H" "\"Content-Type: application/json\"" "-X GET" "\"https://libraries.io/api/maven/$clientid/$version/dependencies?api_key=80be6c2040e9c5266d6c507bdbbcecdb\"" "2>/dev/null | jq -r" "\".dependencies[] | select(.name==\\\"$libid\\\")|.requirements\""
        result=$(curl -H "Accept: application/json" -H "Content-Type: application/json" -X GET "https://libraries.io/api/maven/$clientid/$version/dependencies?api_key=80be6c2040e9c5266d6c507bdbbcecdb" 2>/dev/null)
        while [[ $result == *"Retry later"* ]]; do
            # echo "Some issues occur, retrying..."
            result=$(curl -H "Accept: application/json" -H "Content-Type: application/json" -X GET "https://libraries.io/api/maven/$clientid/$version/dependencies?api_key=80be6c2040e9c5266d6c507bdbbcecdb" 2>/dev/null)
        done
        requireVersion=$(echo "$result" | jq -r ".dependencies[] | select(.name==\"$libid\")|.requirements" | grep -v '\$')
        # Retry later
        if [ $requireVersion ]; then
            echo "$clientid $requireVersion $clientRepo" >> $libSearchDir/dependents-version
        fi
    done < $libSearchDir/dependents-maven
    sort $libSearchDir/dependents-version | uniq | sort -k2Vr > /tmp/dependents-version-tmp
    cp /tmp/dependents-version-tmp $libSearchDir/dependents-version
fi

# vote for the mostly used version

if [ ! -f $libSearchDir/dependents-vote ]; then
    echo Voting the library version for coverage comparison
    echo -n > $libSearchDir/dependents-vote
    # sort $libSearchDir/dependents-version | uniq | sort -k2Vr | while read versionUse; do 
    cat $libSearchDir/dependents-version | while read versionUse; do 
        version=$(echo $versionUse | cut -d' ' -f2)
        if ! file_contains_string $libSearchDir/dependents-vote "$version "; then
            echo "$version $(grep -c " $version " $libSearchDir/dependents-version)" >> $libSearchDir/dependents-vote
        fi
    done
    sort -k2rn -o $libSearchDir/dependents-vote $libSearchDir/dependents-vote
fi

# choose version and get client list
targetVersion=$(cat $libSearchDir/dependents-vote | sed -n '1 p' | cut -d' ' -f1)
if [ ! $targetVersion ]; then
    echo [ERROR] No targetVersion found. Have to exit...
    exit 1
fi
grep " $targetVersion " $libSearchDir/dependents-version > $libSearchDir/dependents

######################
## do coverage diff ##
######################

# parameters: $1: client/lib id with @; $2: clone url; $3: target exec name
testWithCov(){
    repoAtId=$1
    url=$2
    execName=$3
    if [ $# -eq 4 ]; then
        checkoutVersion=$4
    fi
    echo "Testing for coverage: $repoAtId:"

    # Clone the project
    echo "  Cloning..."
    [ ! -d $repoDir/$repoAtId ] && git submodule add $url $repoDir/$repoAtId

    cd $repoDir/$repoAtId
    if [ $# -eq 4 ]; then
        # find the tag
        tagName=$(git tag -l | grep "$checkoutVersion$" | head -n 1)
        if [ ! $tagName ]; then 
            echo "  Failed to find a tag of version $checkoutVersion..." 
            false
            return
        fi
        echo "  Checking out to tag $tagName (version $checkoutVersion)"
        git checkout tags/$tagName

        echo "  mvn install for $repoAtId..."
        if [ ! -f "mvninstall-$checkoutVersion.log" ]; then
            timeout -k 10 15m mvn clean install -Dcheckstyle.skip -Drat.skip=true -l "mvninstall-$checkoutVersion.log"
            if [ $? -ne 0 ]; then
                echo "  mvn install failed for $repoAtId"
                false
                return 
            else 
                echo "  mvn install for $repoAtId succeed"
            fi
        else
            echo "  $repoAtId-$checkoutVersion is already installed"
        fi
    fi
    # Test the project or return false if it is determined to be timeout or no coverage 
    if [ -f TestTimeOut ] || [ -f NoCoverage ];then
        echo "  TestTimeOut OR NoCoverage!"
        false
        return
    elif [ -f $execName ]; then
        echo "  $execName file found"
    else
        echo "  Testing...(Timeout is set to 15m)"
        timeout -k 10 15m mvn clean org.jacoco:jacoco-maven-plugin:0.8.7:prepare-agent test -Dcheckstyle.skip -Drat.skip=true -l "mvntest.log"
        
        # If test timeout
        if [ $? = "124" ]; then
            echo "  Test timed out..."
            touch TestTimeOut
            false
            return
        fi

        # Merge exec files if generating multiple
        execNum=$(find . -name "jacoco.exec" | wc -l)
        if [ $execNum = "1" ]; then
            mv $(find . -name "jacoco.exec") $execName
        elif [ $execNum = "0" ]; then
            echo "  No jacoco.exec generated after testing..."
            touch NoCoverage
            false
            return
        else
            java -jar $pwd/jacococli.jar merge $(find . -name "jacoco.exec") --destfile=$execName
        fi
    fi

    cd $pwd
    echo "  Successfully generate coverage information!"
    true
}

# Test library for coverage
getLibRepoUrl  # url <- lib url
getRepoAtNameFromUrl  # repoAtName <- lib name with @
libAtName=$repoAtName
if ! testWithCov "$libAtName" "$url" "$libid-$targetVersion.exec" "$targetVersion"; then
    echo "Test with cov failed for $libAtName, have to exit..."
    exit 1
fi

while read -r record; do
    cd $pwd
    url=${record##* }
    getRepoAtNameFromUrl  # repoAtName <- client name with @
    clientId=$repoAtName
    clientExecName=${clientId//@/:}@$libid.exec

    echo 
    if ! testWithCov "$clientId" "$url" "$clientExecName"; then
        continue
    fi

    if [ -f $repoDir/$clientId/$clientExecName ] && [ -f $repoDir/$libAtName/$libid-$targetVersion.exec ]; then
        echo "Ready for coverage comparison!"
    else
        echo "[ERROR] $repoDir/$clientId/$clientExecName or $repoDir/$libAtName/$libid-$targetVersion.exec not found..."
        continue
    fi

    echo Start Cov Diff...
    [ ! -d $pwd/$repoDir/$libAtName/comparison ] && mkdir $pwd/$repoDir/$libAtName/comparison
    cd $pwd/$repoDir/$libAtName/comparison

    cp -r $pwd/$repoDir/$libAtName/target/classes .
    cp -r $pwd/$repoDir/$libAtName/src/main/java src
    cp $pwd/$repoDir/$libAtName/$libid-$targetVersion.exec lib.exec
    cp $pwd/$repoDir/$clientId/$clientExecName client.exec

    java -jar $pwd/jacococli.jar report lib.exec --classfiles classes  --sourcefiles src --html $pwd/$repoDir/$libAtName/jacoco-$targetVersion --xml $pwd/$repoDir/$libAtName/jacoco-$targetVersion.xml

    java -jar $pwd/jacococli.jar report client.exec --classfiles classes  --sourcefiles src --html $pwd/$repoDir/$clientId/jacoco-$clientId-$libid --xml $pwd/$repoDir/$clientId/jacoco-$clientId-$libid.xml

    cp $pwd/$repoDir/$libAtName/jacoco-$targetVersion.xml lib.xml
    cp $pwd/$repoDir/$clientId/jacoco-$clientId-$libid.xml client.xml
    cp $pwd/report.dtd .
    diffResult=$(java -jar -Djavax.xml.accessExternalDTD=all $pwd/covdiff.jar lib.xml client.xml)
    echo "********** Diff Cov Lib:$libAtName Client:$clientId **********"
    echo "$diffResult"
    log "********** Diff Cov Lib:$libAtName Client:$clientId **********"
    log "$diffResult"
    log ""
    
done < $libSearchDir/dependents