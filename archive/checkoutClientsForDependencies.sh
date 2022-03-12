pwd=`pwd`

if [ $# -ne 1 ]; then
    echo need an argument as library id, e.g., junit:junit
    exit 1
fi

file_contains_string(){
    if grep -q "$2" "$1"; then
        true
    else 
        false
    fi
}

libId=$1  # mybatis
resultDir=searchResults/javaRepo
usageData=searchResults/javaRepo/dependencyUsage
clientDir=clients/
[ ! -d $clientDir ] && mkdir -p $clientDir
token="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"

if [ ! -d $resultDir ];then
    echo [ERROR] $resultDir does not exist!
    exit 1
fi

counter=0
while read -r clientName && [ $counter -lt 10 ]; do
    cd $pwd 

    if file_contains_string $usageData "$libId $clientName" ; then
        echo Cloning $clientName to $clientDir/$clientName...
        [ ! -d $clientDir/$clientName ] && git clone git@github.com:$clientName.git $clientDir/$clientName
        cd $clientDir/$clientName
        # echo Testing $clientName...
        # [ ! -f mvntest.log ] && mvn test -Dmaven.test.failure.ignore=true -l mvntest.log
        # if file_contains_string mvntest.log "[INFO] BUILD FAILURE"; then
        #     echo [WARNING] $clientName build failed...
        #     continue
        # fi
        counter=$((counter + 1))
    else
        echo [INFO] $clientName does not depend on $libId
        continue
    fi

done < $resultDir/listOfClients

