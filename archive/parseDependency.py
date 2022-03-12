import os
from lxml import objectify

targetDir = os.fsencode("searchResults/javaRepo/pom")
for file in os.listdir(targetDir):
    filename = os.fsdecode(file)
    if not filename.endswith("-pom.xml"):
        continue

    fail = 0
    content = ""
    clientName = filename.replace("-pom.xml", "").replace("@", "/")

    with open("searchResults/javaRepo/pom/" + filename, mode='r') as pom:
        content = pom.read()
    tree = objectify.fromstring(bytes(content, encoding='utf8'))

    try:
        arr = tree.dependencies.dependency
        for i in range(len(arr)):
            groupId = str(arr[i].groupId)
            artifactId = str(arr[i].artifactId)
            print("{}:{} {}".format(groupId, artifactId, clientName))
    except:
        fail += 1

    try:
        arr = tree.dependencyManagement.dependencies.dependency
        for i in range(len(arr)):
            groupId = str(arr[i].groupId)
            artifactId = str(arr[i].artifactId)
            print("{}:{} {}".format(groupId, artifactId, clientName))
    except:
        fail += 1

# if fail == 2:
#     print("No dependency Found")
# print()