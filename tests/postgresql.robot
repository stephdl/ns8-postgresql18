*** Settings ***
Library    SSHLibrary
Resource    api.resource

*** Test Cases ***
Check if postgresql is installed correctly
    ${output}  ${rc} =    Execute Command    add-module ${IMAGE_URL} 1
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    &{output} =    Evaluate    ${output}
    Set Suite Variable    ${module_id}    ${output.module_id}

Check if postgresql can be configured
    ${rc} =    Execute Command    api-cli run module/${module_id}/configure-module --data '{"host":"postgresql.domain.org","http2https": true,"lets_encrypt": true}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

Check postgresql path is configured
    ${ocfg} =   Run task    module/${module_id}/get-configuration    {}
    Set Suite Variable     ${HOST}    ${ocfg['host']}
    Set Suite Variable     ${HTTP2HTTPS}    ${ocfg['http2https']}
    Set Suite Variable     ${LE_ENCRYPT}    ${ocfg['lets_encrypt']}
    Should Not Be Empty    ${HOST}
    Should Be True    ${HTTP2HTTPS}
    Should Be True    ${LE_ENCRYPT}

Check if posgresql works as expected
    Wait Until Keyword Succeeds    20 times    3 seconds    Ping postgresql

Check if postgresql is removed correctly
    ${rc} =    Execute Command    remove-module --no-preserve ${module_id}
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

*** Keywords ***
Ping postgresql
    ${out}  ${err}  ${rc} =    Execute Command    curl -k -f -H 'Host: postgresql.domain.org' https://127.0.0.1/login
    ...    return_rc=True  return_stdout=True  return_stderr=True
    Should Be Equal As Integers    ${rc}  0
    Should Contain    ${out}    <title>pgAdmin
