pwd=`pwd`

if [ $# -ne 2 ]; then
    echo need two argument as library id and package pattern, e.g., junit:junit and junit.**:org.junit.**
    exit 1
fi

file_contains_string(){
    if grep -q "$2" "$1"; then
        true
    else 
        false
    fi
}

libId=$1 
pattern=$2
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
        cd $pwd
        # echo Cloning $clientName to $clientDir/$clientName...
        # [ ! -d $clientDir/$clientName ] && git clone git@github.com:$clientName.git $clientDir/$clientName
        [ ! -d $clientDir/$clientName ] && continue
        
        # modify the pom.xml to add jacoco javaagent to argline
        # testCmd="mvn test -Dmaven.test.failure.ignore=true"
        needProperty=false
        echo Processing $clientDir/$clientName...
        for pomFile in `find $clientDir/$clientName -name pom.xml`; do
            [ ! -f $pomFile.bak ] && cp $pomFile $pomFile.bak
            [ -f $pomFile.bak ] && cp $pomFile.bak $pomFile
            result=`python3 appendArgLineToPom.py $pomFile "-javaagent:$pwd/jacocoagent.jar=includes=$pattern"`
            if [ "$result" = "No position found" ]; then
                # testCmd="mvn test -Dmaven.test.failure.ignore=true -DargLine=\"-javaagent:$pwd/jacocoagent.jar=includes=$pattern\""
                needProperty=true
            else
                cp $result $pomFile
            fi
        done
        
        # run test using the new pom.xml file
        if [ ! -f $clientDir/$clientName/jacoco.exec ]; then
            cd $clientDir/$clientName
            echo Testing $clientDir/$clientName with jacoco...
            if [ $needProperty = true ]; then
                mvn test -Dmaven.test.failure.ignore=true -DargLine="-javaagent:$pwd/jacocoagent.jar=includes=$pattern" -l mvntest.log
            else
                mvn test -Dmaven.test.failure.ignore=true -l mvntest.log
            fi
            resultNum=`find . -name "jacoco*" | wc -l`
            if [ resultNum -eq 0 ]; then
                echo [ERROR] No jacoco.exec is found!!!
                continue
            fi
        fi

        # generate xml report for library coverage
        version=`python3 findVersion.py pom.xml junit:junit`
        tmp=`cat $libId`
        cp 


        # clone library source code itself

        # parse the target version of used library

        # checkout to tag

        # modify pom.xml for lib repo

        # run test in lib repo

        # generate cov report for lib repo

        # analyse the coverage difference, output the report

        counter=$((counter + 1))
    else
        echo [INFO] $clientName does not depend on $libId
        continue
    fi

done < $resultDir/listOfClients

