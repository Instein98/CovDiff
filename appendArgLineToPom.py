import sys


if __name__ == '__main__':
    targetPom = sys.argv[1]
    argline = sys.argv[2]
    newPomContent = ""
    inTarget=False
    changed=False
    with open(targetPom) as pom:
        for line in pom:
            if "<artifactId>maven-surefire-plugin</artifactId>" in line:
                inTarget=True
            if inTarget and "</argLine>" in line:
                line = line.replace("</argLine>", " " + argline + "</argLine>")
                changed=True
            if inTarget and "</plugin>" in line:
                inTarget=False
            newPomContent += line

    if changed:
        dumpPath = "pom-with-argline.xml" if "/" not in targetPom else targetPom[:targetPom.rindex("/")+1] + "pom-with-argline.xml"
        with open(dumpPath, 'w') as out:
            out.write(newPomContent)
        print(dumpPath)
    else:
        print("No position found")