KIFLog2Unit
===========

Converts KIF output log messages to JUnit test results for using KIF in a continuous integration environment.

Tested and working with the Publish JUnit Test Result Report post-build action in Jenkins.

### Usage

1. Save the script somewhere in your Jenkins user's PATH, and make it executable with `chmod +x KIFLog2JUnit.rb`
1. Build your KIF target with the Xcode build plugin/step
1. Run the app in the simulator (we use waxsim to launch it) and save the output to a file:
`waxsim -s 6.1 -f iphone -v ${WORKSPACE}/test-run.mov "${WORKSPACE}/build/KIFTests.app" > KIF-AutomationTests.out 2>&1
`
1. Process the file with the script:
 `KIFLog2JUnit.rb TEST_SUITE_NAME ${WORKSPACE}/KIF-AutomationTests.out`
1. Publish the xml file using the JUnit post-build publisher
