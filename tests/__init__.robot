*** Settings ***
Library           SSHLibrary

*** Variables ***
${SSH_KEYFILE}    %{HOME}/.ssh/id_ecdsa
# install tests the image on a clean node, update installs ${UPDATE_FROM} first
# and upgrades to it. The CI passes both with -v; the defaults keep the suite
# runnable by hand.
${SCENARIO}       install
${UPDATE_FROM}    ghcr.io/stephdl/v18postgresql:latest

*** Keywords ***
Connect to the node
    Open Connection   ${NODE_ADDR}
    Login With Public Key    root    ${SSH_KEYFILE}
    ${output} =    Execute Command    systemctl is-system-running  --wait
    Should Be True    '${output}' == 'running' or '${output}' == 'degraded'

*** Settings ***
Suite Setup       Connect to the Node
