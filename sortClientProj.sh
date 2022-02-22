if [ $# -ne 1 ]; then
    echo need an argument as library name!
    exit 1
fi

libName=$1  # mybatis
resultDir=searchResults/$libName
token="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"

if [ ! -d $resultDir ];then
    echo [ERROR] $resultDir does not exist!
    exit 1
fi

echo -n > $resultDir/listOfClients
echo -n > $resultDir/tmpFile

# gather the client projects in all json file
for file in `ls $resultDir/*.json`;do
    cat $file | jq -r ' .items[].repository.full_name' >> $resultDir/tmpFile
done

cat $resultDir/tmpFile | sort | uniq > $resultDir/tmpFile2

while read -r clientName; do
    starNum=`curl "https://api.github.com/repos/$clientName" -H 'Accept: application/vnd.github.v3+json' -H "Authorization: Token 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" | jq '.stargazers_count'`
    echo $clientName $starNum >> $resultDir/listOfClients
done < "$resultDir/tmpFile2"

sort -rn -k 2 -o  $resultDir/listOfClients $resultDir/listOfClients
rm $resultDir/tmpFile
rm $resultDir/tmpFile2
