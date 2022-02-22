# if [ $# -ne 1 ]; then
#     echo need an argument as library name!
#     exit 1
# fi

libName=javaRepo
resultDir=searchResults/$libName
token="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"

if [ ! -d $resultDir ];then
    echo [ERROR] $resultDir does not exist!
    exit 1
fi

isMavenProj(){
    pomNum=`curl "https://api.github.com/repos/$1/contents/" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Authorization: Token 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" 2>/dev/null | jq -r '.[].name' | grep pom.xml | wc -l`
    if [ $pomNum -ge 1 ]; then
        true
    else
        false
    fi
}

echo -n > $resultDir/listOfClients
echo -n > $resultDir/tmpFile

# gather the client projects in all json file
for file in `ls $resultDir/*.json`;do
    cat $file | jq -r '.items[].full_name' >> $resultDir/tmpFile
done

while read -r clientName; do
    if isMavenProj $clientName; then
        echo $clientName >> $resultDir/listOfClients
    fi
done < "$resultDir/tmpFile"

rm $resultDir/tmpFile
