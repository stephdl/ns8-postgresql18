*** Settings ***
Library           SSHLibrary

*** Variables ***
${SSH_KEYFILE}    %{HOME}/.ssh/id_ecdsa
# install tests the image on a clean node, update installs the stable
# release from the stephdl forge first then upgrades to it.
${SCENARIO}       install

*** Keywords ***
Connect to the node
    Open Connection   ${NODE_ADDR}
    Login With Public Key    root    ${SSH_KEYFILE}
    ${output} =    Execute Command    systemctl is-system-running  --wait
    Should Be True    '${output}' == 'running' or '${output}' == 'degraded'

*** Settings ***
Suite Setup       Connect to the Node
