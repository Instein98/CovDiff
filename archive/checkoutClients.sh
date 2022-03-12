pwd=`pwd`

if [ $# -ne 1 ]; then
    echo need an argument as library name!
    exit 1
fi

file_contains_string(){
    if grep -q "$2" "$1"; then
        true
    else 
        false
    fi
}

libName=$1  # mybatis
resultDir=searchResults/$libName
clientDir=clients/$libName
[ ! -d $clientDir ] && mkdir -p $clientDir
token="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"

if [ ! -d $resultDir ];then
    echo [ERROR] $resultDir does not exist!
    exit 1
fi

counter=0
while read -r line && [ $counter -lt 10 ]; do
    cd $pwd 
    clientName=${line% *}
    pomNum=`curl "https://api.github.com/repos/$clientName/contents/" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Authorization: Token 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" 2>/dev/null | jq -r '.[].name' | grep pom.xml | wc -l`
    if [ $pomNum -ge 1 ]; then
        echo Cloning $clientName to $clientDir/$clientName...
        [ ! -d $clientDir/$clientName ] && git clone git@github.com:$clientName.git $clientDir/$clientName
        cd $clientDir/$clientName
        echo Testing $clientName...
        [ ! -f mvntest.log ] && mvn test -Dmaven.test.failure.ignore=true -l mvntest.log
        if file_contains_string mvntest.log "[INFO] BUILD FAILURE"; then
            echo [WARNING] $clientName build failed...
            continue
        fi
        counter=$((counter + 1))
    else
        echo [WARNING] $clientName is not a maven project...
        continue
    fi

done < $resultDir/listOfClients

