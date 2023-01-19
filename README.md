# This is utility to build and test jdk8 in bigger scope then openjdk github actions (which run only tier1)

fork this repo
enable github actions (in actions tab)
create branch jdk-..some..name (jdk is mandatory)
create top level file CONFIG (literaly)
put three lines into this file
 * JDK_REPO=githubUsername/jorsForkOfJdk8Name
 * JDK_REF=yursBranch
 * JDK_TEST=jdkTestTargets

Where jdk test target is one of the: https://github.com/openjdk/jdk8u-dev/blob/master/jdk/test/TEST.groups

eg:
 https://github.com/zzambers/jdk-tester/commit/483745f968d63e8ffb4f06fb17c6c253a90de2e6
or
 https://github.com/judovana/jdk-tester/blob/jdk-judovana-backport-63eb0b7e/CONFIG

After you commit, you should see your jdk8 built and tested in your actioons (no PR needed)
