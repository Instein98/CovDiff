pwd=`pwd`

file_contains_string(){
    if grep -q "$2" "$1"; then
        true
    else 
        false
    fi
}

libName=javaRepo
resultDir=searchResults/$libName
pomDir=$resultDir/pom
[ ! -d $pomDir ] && mkdir -p $pomDir
token="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"

if [ ! -d $resultDir ];then
    echo [ERROR] $resultDir does not exist!
    exit 1
fi

while read -r clientName; do
    cd $pwd 
    id=`echo $clientName | sed 's,/,@,g'`
    [ ! -f $pomDir/$id-pom.xml ] && wget `curl -D header.log "https://api.github.com/repos/$clientName/contents/" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Authorization: Token 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" | jq -r '.[] | select (.name == "pom.xml") | .download_url'` -O $pomDir/$id-pom.xml
done < $resultDir/listOfClients



# jq -r '.[] | select (.name == "pom.xml") | .download_url'