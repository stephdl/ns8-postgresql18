*** Settings ***
Library    SSHLibrary
Resource    api.resource

*** Test Cases ***
Check if postgresql is installed correctly
    ${output}  ${rc} =    Execute Command    add-module ${IMAGE_URL} 1
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    &{output} =    Evaluate    ${output}
    Set Global Variable    ${module_id}    ${output.module_id}

Check if postgresql can be configured
    ${rc} =    Execute Command    api-cli run module/${module_id}/configure-module --data '{"host":"postgresql.domain.org","http2https": true,"lets_encrypt": false}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

Check postgresql path is configured
    ${ocfg} =   Run task    module/${module_id}/get-configuration    {}
    Set Global Variable     ${HOST}    ${ocfg['host']}
    Set Global Variable     ${HTTP2HTTPS}    ${ocfg['http2https']}
    Set Global Variable     ${LE_ENCRYPT}    ${ocfg['lets_encrypt']}
    Should Not Be Empty    ${HOST}
    Should Be True    ${HTTP2HTTPS}
    # Deliberately false: nothing resolves postgresql.domain.org, so the ACME
    # challenge could only fail, and asking Let's Encrypt for a domain this
    # repository does not own is not something CI should do on every push.
    Should Not Be True    ${LE_ENCRYPT}
