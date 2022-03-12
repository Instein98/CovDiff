#! /bin/bash
pwd=$(pwd)

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
        # needProperty=false
        # echo Processing $clientDir/$clientName...
        # for pomFile in `find $clientDir/$clientName -name pom.xml`; do
        #     [ ! -f $pomFile.bak ] && cp $pomFile $pomFile.bak
        #     [ -f $pomFile.bak ] && cp $pomFile.bak $pomFile
        #     result=`python3 appendArgLineToPom.py $pomFile "-javaagent:$pwd/jacocoagent.jar=includes=$pattern"`
        #     if [ "$result" = "No position found" ]; then
        #         # testCmd="mvn test -Dmaven.test.failure.ignore=true -DargLine=\"-javaagent:$pwd/jacocoagent.jar=includes=$pattern\""
        #         needProperty=true
        #     else
        #         cp $result $pomFile
        #     fi
        # done
        
        resultNum=`find . -name "jacoco*" | wc -l`
        # run test using the new pom.xml file
        if [ ! $resultNum = 0 ]; then
            cd $clientDir/$clientName
            # echo Testing $clientDir/$clientName with jacoco...
            # if [ $needProperty = true ]; then
            #     mvn test -Dmaven.test.failure.ignore=true -DargLine="-javaagent:$pwd/jacocoagent.jar=includes=$pattern" -l mvntest.log
            # else
            #     mvn test -Dmaven.test.failure.ignore=true -l mvntest.log
            # fi
            # resultNum=`find . -name "jacoco*" | wc -l`
            # if [ $resultNum -eq 0 ]; then
            #     echo [ERROR] No jacoco.exec is found!!!
            #     continue
            # fi
            version=`python3 $pwd/findVersion.py pom.xml junit:junit`
            tmp=`echo $libId | sed 's,:,/,g' | sed 's,\.,/,'`
            artifactId=${libId#*:}
            cp ~/.m2/repository/$tmp/$version/$artifactId-$version.jar .
            for execFile in `find . -name "jacoco.exec"`; do
                targetPath=`echo $execFile | sed 's,jacoco.exec,jacoco.xml,'`
                echo Generating $targetPath
                java -jar $pwd/jacococli.jar report $execFile --classfiles $artifactId-$version.jar --xml $targetPath
            done
        else 
            continue
        fi

        cd $pwd
        if [ $libId = "junit:junit" ]; then
            [ ! -d $pwd/../libraries/junit4 ] && mkdir -p $pwd/../libraries/junit4
            [ ! -f $pwd/../libraries/junit4/pom.xml ] && git clone git@github.com:junit-team/junit4.git $pwd/../libraries/junit4
            
            cd $pwd/../libraries/junit4
            git checkout tags/r$version
            if [ $? -ne 0 ]; then
                echo junit4 checkout failed
                continue
            fi
            resultNum=`find . -name "jacoco-$version.exec" | wc -l`

            if [ $resultNum = 0 ]; then
                echo Testing $pwd/../libraries/junit4 with jacoco...
                mvn test -Dmaven.test.failure.ignore=true -DargLine="-javaagent:$pwd/jacocoagent.jar=includes=$pattern" -l mvntest-$version.log
            fi
            for execFile in `find . -name "jacoco.exec"`; do
                    tmp=`echo $execFile | sed "s,jacoco.exec,jacoco-$version.exec,"`
                    mv $execFile $tmp
                    targetPath=`echo $execFile | sed "s,jacoco.exec,jacoco-$version.xml,"`
                    echo Generating $targetPath
                    java -jar $pwd/jacococli.jar report $tmp --classfiles target --xml $targetPath
            done
        else 
            continue
        fi

        # clone library source code itself

        # parse the target version of used library

        # checkout to tag

        # modify pom.xml for lib repo

        # run test in lib repo

        # generate cov report for lib repo

        # analyse the coverage difference, output the report

        counter=$((counter + 1))
    else
        # echo [INFO] $clientName does not depend on $libId
        continue
    fi

done < $resultDir/listOfClients

