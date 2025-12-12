# xahau-examples
This repo contains example scripts, files, binares, and more for interacting with the Xahau Network and xahaud.

Scripts starting with "build_" are used to compile xahaud, the validator tools, or other software. `build_xahaud.sh` and `build_validator_keys_tool.sh` can be used on Debian or RHEL based Linux distros to automatically build either xahaud or the validator keys tool. `build_xahaud_docker.multistage` is a multistage Dockerfile for building xahaud then creating a Docker image file, which can be used to run xahaud.


## Validator Keys Tool
This tool is used to generate validator keys and configure domain verification for validators on the Xahau and XRP Ledger networks. Given the security requirements for generating validation seeds, users are encouraged to compile the tool from scratch. A script is provided that demonstrates/automates this process on both Debian and RHEL based operating systems. However, users who are simply testing the tool may take advantages of the compiled binary, validator-keys-portable, which is tested on Debian and RHEL 9/10 Linux distributions.

## Disclaimers
Some items in this repository may have independent copyright or licensing requirements. Always view the original project for relevant restrictions and requirements.
The files contained in this repository are intended for demonstration purposes only, the author is not responsible for their use or functionality, or any other consequences arising therefrom.
