#! /bin/bash

# input is a github link of repository, e.g., https://github.com/spring-projects/spring-framework
# Todo: handle the situations when the repository is redirected: jq: error (at <stdin>:5): Cannot index string with string "name"
isMavenProj(){
    id=${1#"https://github.com/"}
    # echo Checking whether $id is a maven project...
    pomNum=$(curl "https://api.github.com/repos/$id/contents/" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Authorization: Token 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" 2>/dev/null | jq -r '.[].name' | grep pom.xml | wc -l)
    if [ $pomNum -ge 1 ]; then
        true
    else
        false
    fi
}

per_page=100
page_num=5
searchDir=search
[ ! -d $searchDir ] && mkdir -p $searchDir

# get a lib id
if [ $# -ne 1 ]; then
    echo need one argument as library id, e.g., junit:junit
    exit 1
else
    libid=$1
    libSearchDir=$searchDir/$libid
    [ ! -d $libSearchDir ] && mkdir -p $libSearchDir
fi

# find clients that using that lib
if [ ! -f $libSearchDir/dependents-all ]; then
    echo -n > $libSearchDir/dependents-all
    for ((i=1; i<page_num+1; i++)); do
        [ -f $libSearchDir/"dependents-p$i" ] && continue
        echo "Search for $libid dependents page $i..."
        curl -H "Accept: application/json" -H "Content-Type: application/json" -X GET "https://libraries.io/api/maven/$libid/dependents?api_key=80be6c2040e9c5266d6c507bdbbcecdb&per_page=$per_page&page=$i" > $libSearchDir/"dependents-p$i"
        while [[ ! $(cat "$libSearchDir/dependents-p$i" | jq -r '.[] | "\(.name)@\(.repository_url)"') ]]; do
            echo "No results found, retrying..."
            sleep 1
            curl -H "Accept: application/json" -H "Content-Type: application/json" -X GET "https://libraries.io/api/maven/$libid/dependents?api_key=80be6c2040e9c5266d6c507bdbbcecdb&per_page=$per_page&page=$i" > $libSearchDir/"dependents-p$i"
        done
        # cat "$libSearchDir/dependents-p$i" | jq -r '.[] | "\(.name)@\(.repository_url)@\(.versions|last|.number)"' >> $libSearchDir/dependents-all
        cat "$libSearchDir/dependents-p$i" | jq -r '.[] | "\(.name)@\(.repository_url)@\(.latest_release_number)"' >> $libSearchDir/dependents-all
    done
fi

    # filter the maven projects
if [ ! -f $libSearchDir/dependents-maven ]; then
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

# vote for the version
if [ ! -f $libSearchDir/dependents-version ]; then
    echo -n > $libSearchDir/dependents-version
    while read -r dependent; do
        clientid=${dependent%%@*}
        clientRepo=${dependent#*@}
        clientRepo=${clientRepo%@*}
        version=${dependent##*@}
        # echo "curl -H" "\"Accept: application/json\"" "-H" "\"Content-Type: application/json\"" "-X GET" "\"https://libraries.io/api/maven/$clientid/$version/dependencies?api_key=80be6c2040e9c5266d6c507bdbbcecdb\"" "2>/dev/null | jq -r" "\".dependencies[] | select(.name==\\\"$libid\\\")|.requirements\""
        requireVersion=$(curl -H "Accept: application/json" -H "Content-Type: application/json" -X GET "https://libraries.io/api/maven/$clientid/$version/dependencies?api_key=80be6c2040e9c5266d6c507bdbbcecdb" 2>/dev/null | jq -r ".dependencies[] | select(.name==\"$libid\")|.requirements")
        if [ $requireVersion ]; then
            echo "$clientid@$requireVersion" >> $libSearchDir/dependents-version
        fi
    done < $libSearchDir/dependents-maven
fi


# do coverage diff