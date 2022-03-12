#! /bin/bash

if [ $# -ne 1 ]; then
    echo need one argument as library id, e.g., junit:junit
    exit 1
fi

getDependencyVersion(){
    version=$(mvn dependency:resolve | grep "$1:" | head -n 1 | sed "s/.*$1:jar:\(.*\):.*/\1/")
    version=${version%-*}
}

getLibRepoName(){
    if [ $1 = "commons-io:commons-io" ];then  # libId
        libRepoName=apache@commons-io
    elif [ $1 = "com.google.guava:guava" ];then
        libRepoName=google@guava
    elif [ $1 = "org.apache.commons:commons-lang3" ];then
        libRepoName=apache@commons-lang
    elif [ $1 = "com.fasterxml.jackson.core:jackson-databind" ];then
        libRepoName=FasterXML@jackson-databind
    elif [ $1 = "com.fasterxml.jackson.core:jackson-core" ];then
        libRepoName=FasterXML@jackson-core
    elif [ $1 = "commons-codec:commons-codec" ];then
        libRepoName=apache@commons-codec
    fi
}

log(){
    time=$(date "+%m/%d %T")
    echo "[$time] ""$1" >> $covDiffLog
}

pwd=$(pwd)
clientDir=clients
libDir=libraries

# while read -r record; do
#     echo 
#     cd $pwd
    # libId=${record% *}  # junit:junit
    libId=$1
    libGroupId=${libId%:*}
    libArtId=${libId#*:}
    libAtId=$libGroupId@$libArtId
    getLibRepoName $libId  # $libRepoName is assigned
    libSlashName=$(echo $libRepoName | sed 's|@|/|')
    [ ! -d $libDir/$libRepoName ] && git submodule add git@github.com:$libSlashName.git $libDir/$libRepoName
    covDiffLog=$pwd/$libDir/$libRepoName/covDiffLog

    # Todo: exclude some library that is not typical
    # Have to manually clone the library repository
    echo Start $libId
    log "========== $libId =========="
    log ""

    cat dependencyUsage | grep "$libId " | while read usage; do
        cd $pwd
        clientSlashName=${usage#* }
        clientId=$(echo $clientSlashName | sed 's|/|@|g')  #junit@junit
        echo
        echo Processing $clientId
        echo Cloning...
        [ ! -d $clientDir/$clientId ] && git submodule add git@github.com:$clientSlashName.git $clientDir/$clientId

        # echo "usage: $usage"
        # echo "clientSlashName: $clientSlashName"
        # echo "clientId: $clientId"
        cd "$clientDir/$clientId"
        echo `pwd`
        if [ -f $clientId-$libGroupId@$libArtId.exec ] || [ -f TestTimeOut ] || [ -f NoCoverage ];then
            # :  # The no-op command in shell
            echo "$clientId-$libGroupId@$libArtId.exec file exists OR TestTimeOut OR NoCoverage!"
        else
            echo "Testing...(Timeout is set to 15m)"
            timeout -k 10 15m mvn clean org.jacoco:jacoco-maven-plugin:prepare-agent test -Dcheckstyle.skip -Drat.skip=true -Dmaven.test.failure.ignore=true -l "mvntest.log"
        fi

        # Move to next client if test timeout
        if [ $? = "124" ]; then
            echo "Test timed out! Move to next client..."
            touch TestTimeOut
            continue
        fi

        execNum=$(find . -name "jacoco.exec" | wc -l)
        echo "Found $execNum exec files"
        if [ $execNum = "1" ]; then
            mv target/jacoco.exec $clientId-$libGroupId@$libArtId.exec
        elif [ $execNum = "0" ]; then
            echo "NoCoverage! Move to next client..."
            touch NoCoverage
            continue
        else
            java -jar $pwd/jacococli.jar merge $(find . -name "jacoco.exec") --destfile=$clientId-$libGroupId@$libArtId.exec
        fi

        [ -f $clientId-$libGroupId@$libArtId.exec ] && echo "$clientId-$libGroupId@$libArtId.exec is generated successfully!!"

        # version=$(python3 $pwd/findVersion.py pom.xml $libId)
        getDependencyVersion $libId  # $version is assgined
        if [ ! $version ]; then
            echo "Dependency version resolving failed. Move to the next client"
            continue  # if version resolve failed, move to the next client
        fi
        echo "$clientId uses $libId version $version"
        cd $pwd/$libDir/$libRepoName

        # find the tag
        tagName=$(git tag -l | grep $version | head -n 1)
        if [ ! $tagName ]; then 
            echo "Tag resolving failed. Move to the next client" 
            continue  # if version resolve failed, move to the next client
        fi
        echo "Version $version corresponds to tag $tagName"
        echo "Checking out to tag $tagName"
        git checkout tags/$tagName
        mvn clean compile > /dev/null 2>&1

        echo Testing...
        if [ ! -f $libAtId-$tagName.exec ]; then
            # timeout -k 10 15m mvn clean org.jacoco:jacoco-maven-plugin:prepare-agent test -Dcheckstyle.skip -Drat.skip=true -Dmaven.test.failure.ignore=true -l "mvntest.log"  # will not skip if timeout
            mvn clean org.jacoco:jacoco-maven-plugin:prepare-agent test -Dcheckstyle.skip -Drat.skip=true -Dmaven.test.failure.ignore=true -l "mvntest.log"  # will not skip if timeout
            execNum=$(find . -name "jacoco.exec" | wc -l)
            if [ $execNum = "1" ]; then
                mv target/jacoco.exec $libAtId-$tagName.exec
            elif [ $execNum = "0" ]; then
                echo "NoCoverage! Move to other clients..."
                touch NoCoverage
                continue
            else
                java -jar $pwd/jacococli.jar merge $(find . -name "jacoco.exec") --destfile=$libAtId-$tagName.exec
            fi
        fi
        

        cd $pwd
        if [ -f $pwd/$libDir/$libRepoName/$libAtId-$tagName.exec ] && [ -f $pwd/$clientDir/$clientId/$clientId-$libGroupId@$libArtId.exec ]; then
            echo Start Cov Diff...
            [ ! -d $pwd/$libDir/$libRepoName/comparison ] && mkdir $pwd/$libDir/$libRepoName/comparison
            cd $pwd/$libDir/$libRepoName/comparison
            
            cp -r $pwd/$libDir/$libRepoName/target/classes .
            cp -r $pwd/$libDir/$libRepoName/src/main/java src
            cp $pwd/$libDir/$libRepoName/$libAtId-$tagName.exec lib.exec
            cp $pwd/$clientDir/$clientId/$clientId-$libGroupId@$libArtId.exec client.exec

            java -jar $pwd/jacococli.jar report lib.exec --classfiles classes  --sourcefiles src --html $pwd/$libDir/$libRepoName/jacoco-$tagName --xml lib.xml
            cp lib.xml $pwd/$libDir/$libRepoName/jacoco-$tagName.xml

            tmp=$(echo $libGroupId | sed 's|\.|/|g')
            libJar="$HOME/.m2/repository/$tmp/$libArtId/$version/$libArtId-$version.jar"
            java -jar $pwd/jacococli.jar report client.exec --classfiles "$libJar"  --sourcefiles src --html $pwd/$clientDir/$clientId/jacoco-$clientId-$libGroupId@$libArtId --xml client.xml
            cp client.xml $pwd/$clientDir/$clientId/jacoco-$clientId-$libGroupId@$libArtId.xml

            cp $pwd/report.dtd .
            diffResult=$(java -jar -Djavax.xml.accessExternalDTD=all $pwd/covdiff.jar lib.xml client.xml)
            echo "********** Diff Cov Lib:$libAtId Client:$clientId **********"
            echo "$diffResult"
            log "********** Diff Cov Lib:$libAtId Client:$clientId **********"
            log "$diffResult"
            log ""
        else
            echo "$libDir/$libRepoName/$libAtId-$tagName.exec or $clientDir/$clientId/$clientId-$libGroupId@$libArtId.exec not exist. Move to next client"
            # continue
        fi
    done
# done < dependencyRank